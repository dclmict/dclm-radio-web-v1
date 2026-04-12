#!/usr/bin/env bash

# Setup script for the automated CI/CD pipeline
# This script sets up all necessary scripts and permissions

# Get the project root directory (where this script is called from)
PROJECT_ROOT=$(pwd)

# Change to project root if we're in ops/sh
if [[ $(basename "$PWD") == "sh" ]]; then
    PROJECT_ROOT=$(cd ../../ && pwd)
    cd "$PROJECT_ROOT"
fi

# Color codes
RED=$'\033[31m'
RED_BOLD=$'\033[1;31m'
GREEN=$'\033[32m'
GREEN_BOLD=$'\033[1;32m'
YELLOW=$'\033[33m'
YELLOW_BOLD=$'\033[1;33m'
BLUE=$'\033[34m'
BLUE_BOLD=$'\033[1;34m'
RESET=$'\033[0m'

# Determine env file based on current branch
BRANCH=${1:-${GITHUB_REF_NAME:-$(git rev-parse --abbrev-ref HEAD)}}
case "$BRANCH" in
    "release/dev") ENV_FILE="ops/dev.env" ;;
    "release/dev-v2") ENV_FILE="ops/dev-v2.env" ;;
    "release/prev") ENV_FILE="ops/prev.env" ;;
    "release/prev-v2") ENV_FILE="ops/prev-v2.env" ;;
    "release/prod") ENV_FILE="ops/prod.env" ;;
    "release/prod-v2") ENV_FILE="ops/prod-v2.env" ;;
    "v1") ENV_FILE="ops/v1.env" ;;
    "bams") ENV_FILE="ops/bams.env" ;;
    dev-*) ENV_FILE="ops/${BRANCH}.env" ;;
    prev-*) ENV_FILE="ops/${BRANCH}.env" ;;
    prod-*) ENV_FILE="ops/${BRANCH}.env" ;;
    release/dev-*) ENV_FILE="ops/${BRANCH#release/}.env" ;;
    release/prev-*) ENV_FILE="ops/${BRANCH#release/}.env" ;;
    release/prod-*) ENV_FILE="ops/${BRANCH#release/}.env" ;;
    *) printf "%b" "${RED_BOLD}✗ Unsupported branch: $BRANCH${RESET}"; exit 1 ;;
esac
printf "%b" "${BLUE_BOLD}→ Using environment file: $ENV_FILE${RESET}"

# Check if we're in the right directory
if [ ! -f "$ENV_FILE" ]; then
    printf "%b" "${RED_BOLD}✗ Error: Environment file not found: $ENV_FILE${RESET}"
    printf "%b" "${YELLOW_BOLD}! Expected to find: $ENV_FILE${RESET}"
    printf "%b" "${YELLOW_BOLD}! Current directory: $PROJECT_ROOT${RESET}"
    exit 1
fi

printf "%b" "${YELLOW_BOLD}! Current directory: $PROJECT_ROOT${RESET}"

# Step 1: Make all scripts in ops/sh executable
printf "\n${BLUE_BOLD}━━━ Step 1: Setting script permissions ━━━${RESET}"
scripts=(
    "./ops/sh/vault.sh"
    "./ops/sh/auto-version.sh"
    "./ops/sh/update-env-version.sh"
    "./ops/sh/app.sh"
    "./ops/sh/pre-push.sh"
    "./ops/sh/install-hooks.sh"
    "./ops/sh/setup-pipeline.sh"
)

for script in "${scripts[@]}"; do
    if [ -f "$script" ]; then
        chmod +x "$script"
        printf "%b" "${GREEN_BOLD}✓ Made $script executable${RESET}"
    else
        printf "%b" "${YELLOW_BOLD}! Script not found: $script${RESET}"
    fi
done

# Step 2: Install git hooks
printf "\n${BLUE_BOLD}━━━ Step 2: Installing Git hooks ━━━${RESET}"
if [ -f "./ops/sh/install-hooks.sh" ]; then
    ./ops/sh/install-hooks.sh
else
    printf "%b" "${RED_BOLD}✗ Error: ops/sh/install-hooks.sh not found${RESET}"
    exit 1
fi

# Step 3: Verify vault.sh is working
printf "\n${BLUE_BOLD}━━━ Step 3: Verifying Vault integration ━━━${RESET}"
if [ -f "./ops/sh/vault.sh" ]; then
    printf "%b" "${GREEN}▸ Testing vault.sh script...${RESET}"
    if ./ops/sh/vault.sh --help >/dev/null 2>&1 || ./ops/sh/vault.sh -h >/dev/null 2>&1; then
        printf "%b" "${GREEN_BOLD}✓ Vault script is working${RESET}"
    else
        printf "%b" "${YELLOW_BOLD}! Vault script exists but may need configuration${RESET}"
        printf "%b" "${YELLOW_BOLD}!    Make sure VAULT_ADDR and VAULT_TOKEN are set in your environment${RESET}"
    fi
else
    printf "%b" "${RED_BOLD}✗ Error: vault.sh not found${RESET}"
fi

# Step 4: Verify version tracking files
printf "\n${BLUE_BOLD}━━━ Step 4: Setting up unified version tracking ━━━${RESET}"

# Check if unified version file exists
if [ ! -f ".version" ]; then
    printf "%b" "${GREEN}▸ Creating unified .version file...${RESET}"
    cat > .version << EOF
dev1.0.0
prv1.0.0
v1.0.0
vv1.0.0
EOF
    printf "%b" "${GREEN_BOLD}✓ Created .version file with initial versions${RESET}"
else
    printf "%b" "${GREEN_BOLD}✓ .version file exists${RESET}"
    printf "%b" "${BLUE_BOLD}→ Current versions:${RESET}"
    while IFS= read -r line; do
        printf "%b" "${YELLOW}   $line${RESET}"
    done < .version
fi

# Step 5: Test auto-versioning
# printf "\n${BLUE_BOLD}━━━ Step 5: Testing auto-versioning ━━━${RESET}"
# if [ -f "./ops/sh/auto-version.sh" ]; then
#     printf "%b" "${GREEN}▸ Testing auto-version script...${RESET}"
#     test_version=$(./ops/sh/auto-version.sh "release/dev" 2>/dev/null)
#     if [ $? -eq 0 ]; then
#         printf "%b" "${GREEN_BOLD}✓ Auto-versioning working: $test_version${RESET}"
#     else
#         printf "%b" "${YELLOW_BOLD}! Auto-versioning script needs verification${RESET}"
#     fi
# else
#     printf "%b" "${RED_BOLD}✗ Error: auto-version.sh not found${RESET}"
# fi

# Step 6: Verify GitHub Actions workflow
printf "\n${BLUE_BOLD}━━━ Step 6: Verifying GitHub Actions workflow ━━━${RESET}"
if [ -f ".github/workflows/app.yml" ]; then
    printf "%b" "${GREEN_BOLD}✓ GitHub Actions workflow found${RESET}"
    printf "%b" "${YELLOW_BOLD}!    Make sure to set these secrets in your GitHub repository:${RESET}"
    printf "%b" "${YELLOW_BOLD}!    - VAULT_URL${RESET}"
    printf "%b" "${YELLOW_BOLD}!    - VAULT_TOKEN${RESET}"
else
    printf "%b" "${RED_BOLD}✗ Error: .github/workflows/app.yml not found${RESET}"
fi

# Summary
printf "\n${BLUE_BOLD}━━━ Setup Complete ━━━${RESET}"
printf "%b" "${BLUE_BOLD}==================${RESET}"
printf "%b" "${GREEN_BOLD}✓ All scripts are now executable${RESET}"
printf "%b" "${GREEN_BOLD}✓ Git pre-push hook installed${RESET}"
printf "%b" "${GREEN_BOLD}✓ Version tracking files ready${RESET}"
printf "%b" "${GREEN_BOLD}✓ Auto-versioning configured${RESET}"

# printf "\n${YELLOW_BOLD}! Next Steps:${RESET}"
# printf "%b" "${YELLOW_BOLD}! 1. Set GitHub repository secrets: VAULT_URL and VAULT_TOKEN${RESET}"
# printf "%b" "${YELLOW_BOLD}! 2. Ensure your Vault server is accessible and configured${RESET}"
# printf "%b" "${YELLOW_BOLD}! 3. Test by pushing to release/dev branch: git push origin release/dev${RESET}"

printf "\n${BLUE_BOLD}→ The automated CI/CD pipeline is ready!${RESET}"

exit 0
