#!/usr/bin/env bash

# Script to add Kubernetes config to Vault for CI/CD pipeline
# This script helps you store your kubeconfig in Vault securely

set -e

# Color codes for output
RED=$'\033[31m'
RED_BOLD=$'\033[1;31m'
GREEN=$'\033[32m'
GREEN_BOLD=$'\033[1;32m'
YELLOW=$'\033[33m'
YELLOW_BOLD=$'\033[1;33m'
BLUE=$'\033[34m'
BLUE_BOLD=$'\033[1;34m'
RESET=$'\033[0m'

printf "%b" "${BLUE_BOLD}━━━ Adding Kubernetes Configuration to Vault ━━━${RESET}\n"

# Auto-detect source directory (./code or ./src)
if [ -d "./code" ]; then
    APP_SRC_DIR="code"
elif [ -d "./src" ]; then
    APP_SRC_DIR="src"
else
    APP_SRC_DIR="src"
fi

# Check if .env file exists (already copied by Makefile based on branch)
if [ ! -f "${APP_SRC_DIR}/.env" ]; then
    printf "%b" "${RED_BOLD}✗ Error: ${APP_SRC_DIR}/.env file not found${RESET}\n"
    echo "Please ensure you're in the project root and Makefile has copied the appropriate env file"
    echo "Run 'make mk' first to set up the environment"
    exit 1
fi

# Source environment variables from the copied .env file
printf "%b" "${BLUE_BOLD}→ Loading environment from ${APP_SRC_DIR}/.env${RESET}\n"
source ${APP_SRC_DIR}/.env

# Check required variables
if [ -z "$VAULT_ADDR" ] || [ -z "$VAULT_TOKEN" ]; then
    printf "%b" "${RED_BOLD}✗ Error: VAULT_ADDR and VAULT_TOKEN must be set in ${APP_SRC_DIR}/.env${RESET}\n"
    echo "Current VAULT_ADDR: ${VAULT_ADDR:-'(not set)'}"
    echo "Please check your environment configuration"
    exit 1
fi

# Export Vault variables so they're available to the vault CLI
export VAULT_ADDR
export VAULT_TOKEN

# Show current configuration
printf "%b" "${YELLOW_BOLD}! Using Vault: $VAULT_ADDR${RESET}\n"
printf "%b" "${YELLOW_BOLD}! Branch-based environment loaded${RESET}\n"

# Verify vault connectivity
printf "%b" "${BLUE_BOLD}→ Testing Vault connectivity...${RESET}\n"
if ! vault status >/dev/null 2>&1; then
    printf "%b" "${RED_BOLD}✗ Error: Cannot connect to Vault at $VAULT_ADDR${RESET}\n"
    echo "Please check:"
    echo "1. Vault server is running and accessible"
    echo "2. VAULT_ADDR is correct in your environment file"
    echo "3. Network connectivity to Vault server"
    exit 1
fi
printf "%b" "${GREEN_BOLD}✓ Vault connection successful${RESET}\n"

# Set vault path for Kubernetes config
VAULT_K8S_PATH="kv/dclm/k8s"

printf "%b" "${BLUE_BOLD}→ Kubeconfig Options:${RESET}\n"
echo "1. Use current kubectl context (~/dev/k8s/k8s_config)"
echo "2. Specify custom kubeconfig file path"
echo "3. Enter kubeconfig content manually"

read -p "Choose option (1-3): " choice

case $choice in
    1)
        if [ ! -f ~/dev/🚀/k8s/k8s_config ]; then
            printf "%b" "${RED_BOLD}✗ Error: ~/dev/k8s/k8s_config not found${RESET}\n"
            exit 1
        fi
        KUBECONFIG_FILE="$HOME/.kube/config"
        printf "%b" "${GREEN_BOLD}✓ Using ~/dev/k8s/k8s_config${RESET}\n"
        ;;
    2)
        read -p "Enter path to kubeconfig file: " KUBECONFIG_FILE
        if [ ! -f "$KUBECONFIG_FILE" ]; then
            printf "%b" "${RED_BOLD}✗ Error: File $KUBECONFIG_FILE not found${RESET}\n"
            exit 1
        fi
        printf "%b" "${GREEN_BOLD}✓ Using $KUBECONFIG_FILE${RESET}\n"
        ;;
    3)
        printf "%b" "${YELLOW_BOLD}! Enter kubeconfig content (press Ctrl+D when done):${RESET}\n"
        KUBECONFIG_CONTENT=$(cat)
        ;;
    *)
        printf "%b" "${RED_BOLD}✗ Invalid option${RESET}\n"
        exit 1
        ;;
esac

# Read kubeconfig content if file was specified
if [ -n "$KUBECONFIG_FILE" ]; then
    KUBECONFIG_CONTENT=$(cat "$KUBECONFIG_FILE")
fi

# Validate kubeconfig content
if [ -z "$KUBECONFIG_CONTENT" ]; then
    printf "%b" "${RED_BOLD}✗ Error: No kubeconfig content provided${RESET}\n"
    exit 1
fi

# Check if it looks like a valid kubeconfig
if ! echo "$KUBECONFIG_CONTENT" | grep -q "apiVersion:\|clusters:\|users:"; then
    printf "%b" "${YELLOW_BOLD}! Warning: Content doesn't look like a valid kubeconfig${RESET}\n"
    read -p "Continue anyway? (y/N): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "Aborted"
        exit 1
    fi
fi

printf "%b" "${BLUE_BOLD}→ Adding kubeconfig to Vault...${RESET}\n"

# Check if the Vault path exists first
echo "Checking if $VAULT_K8S_PATH exists..."
if vault kv get "$VAULT_K8S_PATH" >/dev/null 2>&1; then
    echo "Path exists, fetching existing secrets..."
    EXISTING_SECRETS=$(vault kv get -format=json "$VAULT_K8S_PATH" | jq -r '.data.data // {}')
else
    echo "Path doesn't exist, will create new entry..."
    EXISTING_SECRETS='{}'
fi

# Add kubeconfig to existing secrets (base64 encode for safe storage)
KUBECONFIG_B64=$(echo "$KUBECONFIG_CONTENT" | base64 | tr -d '\n')

# Create the updated secrets object
UPDATED_SECRETS=$(echo "$EXISTING_SECRETS" | jq --arg kubeconfig "$KUBECONFIG_B64" --arg cluster_name "dclm-cluster" --arg added_date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '. + {kubeconfig: $kubeconfig, cluster_name: $cluster_name, added_date: $added_date}')

# Write to vault using individual key-value pairs (more reliable for KV v2)
echo "Writing kubeconfig to Vault..."
vault kv put "$VAULT_K8S_PATH" \
    kubeconfig="$KUBECONFIG_B64" \
    cluster_name="dclm-cluster" \
    added_date="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

printf "%b" "${GREEN_BOLD}✓ Successfully added kubeconfig to Vault at $VAULT_K8S_PATH${RESET}\n"
printf "%b" "${BLUE_BOLD}→ Next steps:${RESET}\n"
echo "1. The kubeconfig is now available as 'kubeconfig' (base64 encoded) in your GitHub Actions"
echo "2. Your CI/CD pipeline will automatically set up kubectl access"
echo "3. Test the deployment with: git push origin release/dev"
echo "4. Import in GitHub Actions with: kv/dclm/k8s kubeconfig"

printf "%b" "${YELLOW_BOLD}! Security Note:${RESET}\n"
echo "The kubeconfig contains sensitive credentials. Ensure:"
echo "- Your Vault is properly secured"
echo "- Vault token has appropriate permissions"
echo "- Consider using service account tokens for production"
