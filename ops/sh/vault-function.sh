#!/usr/bin/env bash

# VAULT UPLOAD FUNCTIONALITY - FUNCTION ONLY
# This contains only the function definition for easy integration with existing hooks

# Function to handle vault upload functionality
vault_upload_secrets() {
    # Get the current branch
    local current_branch=$(git rev-parse --abbrev-ref HEAD)

    # Color codes for output
    local RED=$'\033[0;31m'
    local GREEN=$'\033[0;32m'
    local YELLOW=$'\033[1;33m'
    local BLUE=$'\033[0;34m'
    local RESET=$'\033[0m'

    printf "%b" "${BLUE}🔗 Pre-push hook: Checking branch and uploading secrets...${RESET}\n"
    printf "%b" "${YELLOW}Current branch: $current_branch${RESET}\n"

    # Define environment file mapping
    local env_file=""
    case "$current_branch" in
        "release/dev")
            env_file="./ops/dev.env"
            printf "%b" "${GREEN}📁 Using dev.env for release/dev branch${RESET}\n"
            ;;
        "release/dev-v2")
            env_file="./ops/dev-v2.env"
            printf "%b" "${GREEN}📁 Using dev-v2.env for release/dev-v2 branch${RESET}\n"
            ;;
        "release/prev")
            env_file="./ops/prev.env"
            printf "%b" "${GREEN}📁 Using prev.env for release/prev branch${RESET}\n"
            ;;
        "release/prev-v2")
            env_file="./ops/prev-v2.env"
            printf "%b" "${GREEN}📁 Using prev-v2.env for release/prev-v2 branch${RESET}\n"
            ;;
        "release/prod")
            env_file="./ops/prod.env"
            printf "%b" "${GREEN}📁 Using prod.env for release/prod branch${RESET}\n"
            ;;
        "release/prod-v2")
            env_file="./ops/prod-v2.env"
            printf "%b" "${GREEN}📁 Using prod-v2.env for release/prod-v2 branch${RESET}\n"
            ;;
        "v1")
            env_file="./ops/v1.env"
            printf "%b" "${GREEN}📁 Using v1.env for v1 branch${RESET}\n"
            ;;
        dev-*)
            env_file="./ops/${current_branch}.env"
            printf "%b" "${GREEN}📁 Using ${current_branch}.env for $current_branch branch${RESET}\n"
            ;;
        release/dev-*)
            env_file="./ops/${current_branch#release/}.env"
            printf "%b" "${GREEN}📁 Using ${current_branch#release/}.env for $current_branch branch${RESET}\n"
            ;;
        prev-*)
            env_file="./ops/${current_branch}.env"
            printf "%b" "${GREEN}📁 Using ${current_branch}.env for $current_branch branch${RESET}\n"
            ;;
        release/prev-*)
            env_file="./ops/${current_branch#release/}.env"
            printf "%b" "${GREEN}📁 Using ${current_branch#release/}.env for $current_branch branch${RESET}\n"
            ;;
        prod-*)
            env_file="./ops/${current_branch}.env"
            printf "%b" "${GREEN}📁 Using ${current_branch}.env for $current_branch branch${RESET}\n"
            ;;
        release/prod-*)
            env_file="./ops/${current_branch#release/}.env"
            printf "%b" "${GREEN}📁 Using ${current_branch#release/}.env for $current_branch branch${RESET}\n"
            ;;
        *)
            printf "%b" "${YELLOW}⚠️  Branch $current_branch doesn't require secret upload${RESET}\n"
            return 0
            ;;
    esac

    # Check if environment file exists
    if [ ! -f "$env_file" ]; then
        printf "%b" "${RED}❌ Error: Environment file $env_file not found${RESET}\n"
        return 1
    fi

    # Make vault.sh executable if it exists
    if [ -f "./ops/sh/vault.sh" ]; then
        chmod +x ./ops/sh/vault.sh
        printf "%b" "${GREEN}🔧 Made vault.sh executable${RESET}\n"

        # Upload secrets to Vault
        printf "%b" "${BLUE}🚀 Uploading secrets to Vault...${RESET}\n"
        if ./ops/sh/vault.sh "$env_file"; then
            printf "%b" "${GREEN}✅ Secrets successfully uploaded to Vault${RESET}\n"
            return 0
        else
            printf "%b" "${RED}❌ Failed to upload secrets to Vault${RESET}\n"
            printf "%b" "${RED}🛑 Push aborted due to secret upload failure${RESET}\n"
            return 1
        fi
    else
        printf "%b" "${RED}❌ Error: vault.sh script not found at ./ops/sh/vault.sh${RESET}\n"
        return 1
    fi
}
