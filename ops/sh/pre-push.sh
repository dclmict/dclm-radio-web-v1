#!/usr/bin/env bash

# VAULT UPLOAD FUNCTIONALITY FOR PRE-PUSH HOOK
# Pre-push hook to upload secrets to Vault based on branch
# This script runs before git push and uploads the appropriate env file to Vault

# Function to handle vault upload functionality
vault_upload_secrets() {
    # Get the current branch
    local current_branch=$(git rev-parse --abbrev-ref HEAD)

    # Color codes for output
    local RED=$'\033[31m'
    local RED_BOLD=$'\033[1;31m'
    local GREEN=$'\033[32m'
    local GREEN_BOLD=$'\033[1;32m'
    local YELLOW=$'\033[33m'
    local YELLOW_BOLD=$'\033[1;33m'
    local BLUE=$'\033[34m'
    local BLUE_BOLD=$'\033[1;34m'
    local RESET=$'\033[0m'

    printf "%b" "${BLUE_BOLD}→ Pre-push hook: Checking branch and uploading secrets...${RESET}\n"
    printf "%b" "${YELLOW_BOLD}! Current branch: $current_branch${RESET}\n"

    # Define environment file mapping
    local env_file=""
    case "$current_branch" in
        "release/dev")
            env_file="./ops/dev.env"
            printf "%b" "${GREEN}▸ Using dev.env for release/dev branch${RESET}\n"
            ;;
        "release/dev-v2")
            env_file="./ops/dev-v2.env"
            printf "%b" "${GREEN}▸ Using dev-v2.env for release/dev-v2 branch${RESET}\n"
            ;;
        "release/prev")
            env_file="./ops/prev.env"
            printf "%b" "${GREEN}▸ Using prev.env for release/prev branch${RESET}\n"
            ;;
        "release/prev-v2")
            env_file="./ops/prev-v2.env"
            printf "%b" "${GREEN}▸ Using prev-v2.env for release/prev-v2 branch${RESET}\n"
            ;;
        "release/prod")
            env_file="./ops/prod.env"
            printf "%b" "${GREEN}▸ Using prod.env for release/prod branch${RESET}\n"
            ;;
        "release/prod-v2")
            env_file="./ops/prod-v2.env"
            printf "%b" "${GREEN}▸ Using prod-v2.env for release/prod-v2 branch${RESET}\n"
            ;;
        "v1")
            env_file="./ops/v1.env"
            printf "%b" "${GREEN}▸ Using v1.env for v1 branch${RESET}\n"
            ;;
        dev-*)
            env_file="./ops/${current_branch}.env"
            printf "%b" "${GREEN}▸ Using ${current_branch}.env for $current_branch branch${RESET}\n"
            ;;
        release/dev-*)
            env_file="./ops/${current_branch#release/}.env"
            printf "%b" "${GREEN}▸ Using ${current_branch#release/}.env for $current_branch branch${RESET}\n"
            ;;
        prev-*)
            env_file="./ops/${current_branch}.env"
            printf "%b" "${GREEN}▸ Using ${current_branch}.env for $current_branch branch${RESET}\n"
            ;;
        release/prev-*)
            env_file="./ops/${current_branch#release/}.env"
            printf "%b" "${GREEN}▸ Using ${current_branch#release/}.env for $current_branch branch${RESET}\n"
            ;;
        prod-*)
            env_file="./ops/${current_branch}.env"
            printf "%b" "${GREEN}▸ Using ${current_branch}.env for $current_branch branch${RESET}\n"
            ;;
        release/prod-*)
            env_file="./ops/${current_branch#release/}.env"
            printf "%b" "${GREEN}▸ Using ${current_branch#release/}.env for $current_branch branch${RESET}\n"
            ;;
        *)
            printf "%b" "${YELLOW_BOLD}! Branch $current_branch doesn't require secret upload${RESET}\n"
            return 0
            ;;
    esac

    # Check if environment file exists
    if [ ! -f "$env_file" ]; then
        printf "%b" "${RED_BOLD}✗ Error: Environment file $env_file not found${RESET}\n"
        return 1
    fi

    # Make vault.sh executable if it exists
    if [ -f "./ops/sh/vault.sh" ]; then
        chmod +x ./ops/sh/vault.sh
        printf "%b" "${GREEN_BOLD}✓ Made vault.sh executable${RESET}\n"

        # Upload secrets to Vault
        printf "%b" "${BLUE_BOLD}→ Uploading secrets to Vault...${RESET}\n"
        local vault_output
        vault_output=$(./ops/sh/vault.sh "$env_file" 2>&1)
        local vault_exit=$?
        echo "$vault_output"

        if [ $vault_exit -ne 0 ]; then
            printf "%b" "${RED_BOLD}✗ Failed to upload secrets to Vault${RESET}\n"
            printf "%b" "${RED_BOLD}✗ Push aborted due to secret upload failure${RESET}\n"
            return 1
        fi

        printf "%b" "${GREEN_BOLD}✓ Secrets successfully uploaded to Vault${RESET}\n"

        # Force ESO re-sync if Vault secrets were changed
        if echo "$vault_output" | grep -q "Changes detected\|Will update\|new,"; then
            # Determine K8s context and app name from env file
            local k8s_context=""
            local k8s_namespace=""
            local app_name=""

            # Source env file so variable references (e.g. ${DL_APP1}-${DL_APP2}) are resolved
            set +u 2>/dev/null || true
            source "$env_file" 2>/dev/null || true
            set -u 2>/dev/null || true
            k8s_context="${K8S_CONTEXT:-}"
            k8s_namespace="${K8S_NAMESPACE:-}"
            app_name="${DL_APP_NAME:-}"

            # Fallback: derive context from branch if not in env
            if [ -z "$k8s_context" ]; then
                case "$current_branch" in
                    release/dev*|v1) k8s_context="dev" ;;
                    release/prev*) k8s_context="dev" ;;
                    release/prod*) k8s_context="prod" ;;
                esac
            fi

            if [ -n "$app_name" ] && [ -n "$k8s_namespace" ] && [ -n "$k8s_context" ]; then
                printf "%b" "${BLUE_BOLD}→ Forcing ESO re-sync for $app_name in $k8s_namespace (context: $k8s_context)...${RESET}\n"
                if kubectl --context "$k8s_context" annotate externalsecret "$app_name" \
                    -n "$k8s_namespace" \
                    force-sync="$(date +%s)" \
                    --overwrite 2>/dev/null; then
                    printf "%b" "${GREEN_BOLD}✓ ESO re-sync triggered for $app_name${RESET}\n"
                else
                    printf "%b" "${YELLOW_BOLD}! ESO re-sync skipped (ExternalSecret may not exist yet)${RESET}\n"
                fi
            fi
        fi

        return 0
    else
        printf "%b" "${RED_BOLD}✗ Error: vault.sh script not found at ./ops/sh/vault.sh${RESET}\n"
        return 1
    fi
}

# Execute vault upload functionality only if script is run directly
# Check if this script is being run standalone or sourced/appended
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script is being run directly (standalone)
    vault_upload_secrets
    vault_result=$?

    if [ $vault_result -eq 0 ]; then
        printf "%b" "\033[1;32m✓ Vault upload pre-push hook completed successfully\033[0m\n"
    else
        printf "%b" "\033[1;31m✗ Vault upload pre-push hook failed\033[0m\n"
        exit 1
    fi
else
    # Script is being sourced or appended - just define the function
    # The parent script will decide when/how to call vault_upload_secrets
    printf "%b" "\033[1;34m→ Vault upload functionality loaded\033[0m\n" >&2
fi
