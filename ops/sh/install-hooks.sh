#!/usr/bin/env bash

# Script to install the pre-push git hook for automatic secret upload
# Detects husky and installs accordingly; falls back to .git/hooks/ if no husky

# Function to show help
show_help() {
    echo "Git Pre-Push Hook Installer"
    echo "=========================="
    echo "This script installs vault upload functionality into your git pre-push hook."
    echo ""
    echo "Behavior:"
    echo "  - Detects husky: installs as .husky/pre-push (preferred)"
    echo "  - No husky: installs to .git/hooks/pre-push (fallback)"
    echo "  - Preserves existing hooks by appending vault upload functionality"
    echo "  - Creates backup of existing hooks before modification"
    echo ""
    echo "Usage:"
    echo "  ./install-hooks.sh [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help    Show this help message"
    echo ""
}

# Check for help flag
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi

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

printf "%b" "${BLUE_BOLD}━━━ Installing Git Pre-Push Hook for Automatic Secret Upload ━━━${RESET}\n"

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    printf "%b" "${RED_BOLD}✗ Error: Not in a git repository${RESET}\n"
    printf "%b" "${YELLOW_BOLD}! Current directory: $PROJECT_ROOT${RESET}\n"
    exit 1
fi

# ============================================
# Detect hook system: husky or .git/hooks
# ============================================
HOOK_SYSTEM="git"  # default
HOOK_DIR=".git/hooks"

# Check if husky is configured (core.hooksPath points to .husky/_)
HOOKS_PATH=$(git config core.hooksPath 2>/dev/null || echo "")

if [ -d ".husky" ] && [[ "$HOOKS_PATH" == .husky* ]]; then
    HOOK_SYSTEM="husky"
    HOOK_DIR=".husky"
    printf "%b" "${GREEN_BOLD}✓ Detected husky (hooksPath: $HOOKS_PATH)${RESET}\n"
elif [ -d ".husky" ]; then
    # .husky dir exists but hooksPath not set — check if husky is in package.json
    if grep -q '"husky"' code/package.json 2>/dev/null || grep -q '"husky"' package.json 2>/dev/null; then
        HOOK_SYSTEM="husky"
        HOOK_DIR=".husky"
        printf "%b" "${YELLOW_BOLD}! Husky directory found but not initialized${RESET}\n"

        # Ensure prepare script uses cd .. for monorepo layout (code/ subdirectory)
        if [ -f "code/package.json" ]; then
            # Check if prepare script already has cd ..
            if ! grep -q '"prepare".*cd \.\.' code/package.json 2>/dev/null; then
                printf "%b" "${GREEN}▸ Updating prepare script in code/package.json${RESET}\n"
                if command -v sed &>/dev/null; then
                    sed -i 's/"prepare":.*"husky"/"prepare": "cd .. \&\& husky || true"/' code/package.json 2>/dev/null || true
                fi
            fi

            # Initialize husky
            printf "%b" "${GREEN}▸ Initializing husky...${RESET}\n"
            (cd code && pnpm run prepare 2>/dev/null) || (cd .. 2>/dev/null && npx --prefix code husky 2>/dev/null) || true

            # Verify initialization
            HOOKS_PATH=$(git config core.hooksPath 2>/dev/null || echo "")
            if [[ "$HOOKS_PATH" == .husky* ]]; then
                printf "%b" "${GREEN_BOLD}✓ Husky initialized (hooksPath: $HOOKS_PATH)${RESET}\n"
            else
                printf "%b" "${YELLOW_BOLD}! Husky init may have failed — installing hook to .husky/ anyway${RESET}\n"
            fi
        fi
    fi
fi

if [ "$HOOK_SYSTEM" = "git" ]; then
    printf "%b" "${YELLOW_BOLD}! No husky detected, using .git/hooks/${RESET}\n"
    mkdir -p .git/hooks
fi

# ============================================
# Install pre-push hook
# ============================================

HOOK_FILE="$HOOK_DIR/pre-push"
MARKER="VAULT UPLOAD FUNCTIONALITY"

install_husky_hook() {
    # Husky hooks are simple shell scripts that call other scripts
    # They don't need the vault function inlined — just call pre-push.sh

    if [ -f "$HOOK_FILE" ]; then
        # Check if vault upload is already present
        if grep -q "$MARKER" "$HOOK_FILE" || grep -q "pre-push.sh" "$HOOK_FILE"; then
            printf "%b" "${GREEN_BOLD}✓ Vault upload already present in $HOOK_FILE${RESET}\n"
            return 0
        fi

        # Append to existing hook
        printf "%b" "${GREEN}▸ Appending vault upload to existing $HOOK_FILE${RESET}\n"
        cp "$HOOK_FILE" "${HOOK_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

        cat >> "$HOOK_FILE" << 'HOOK_EOF'

# ===== VAULT UPLOAD FUNCTIONALITY =====
./ops/sh/pre-push.sh
# ===== END VAULT UPLOAD FUNCTIONALITY =====
HOOK_EOF
    else
        # Create new husky pre-push hook
        printf "%b" "${GREEN}▸ Creating $HOOK_FILE${RESET}\n"
        cat > "$HOOK_FILE" << 'HOOK_EOF'
#!/bin/sh

# Block pushing the 'bams' branch directly
current_branch=$(git rev-parse --abbrev-ref HEAD)
if [ "$current_branch" = "bams" ]; then
  echo "You are not allowed to push the 'bams' branch."
  exit 1
fi

# ===== VAULT UPLOAD FUNCTIONALITY =====
./ops/sh/pre-push.sh
# ===== END VAULT UPLOAD FUNCTIONALITY =====
HOOK_EOF
    fi

    chmod +x "$HOOK_FILE"
    printf "%b" "${GREEN_BOLD}✓ Husky pre-push hook installed at $HOOK_FILE${RESET}\n"
}

install_git_hook() {
    # Legacy .git/hooks approach — inline the vault function for self-contained hook

    if [ -f "$HOOK_FILE" ]; then
        # Check if our vault upload functionality is already present
        if grep -q "$MARKER" "$HOOK_FILE"; then
            printf "%b" "${GREEN_BOLD}✓ Vault upload functionality already present in $HOOK_FILE${RESET}\n"
            return 0
        fi

        printf "%b" "${GREEN}▸ Adding vault upload functionality to existing $HOOK_FILE${RESET}\n"

        # Create backup of existing hook
        cp "$HOOK_FILE" "${HOOK_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        printf "%b" "${GREEN_BOLD}✓ Created backup of existing hook${RESET}\n"

        # Add our vault upload functionality at the end of the existing hook
        if [ -f "ops/sh/vault-function.sh" ]; then
            {
                echo ""
                echo "# ===== $MARKER ADDED BY PIPELINE SETUP ====="
                echo "# Added on $(date)"
                echo ""
                sed -n '/^# Function to handle vault upload functionality/,$p' "ops/sh/vault-function.sh"
                echo ""
                echo "# Execute vault upload and check result"
                echo "vault_upload_secrets"
                echo 'vault_result=$?'
                echo ""
                echo 'if [ $vault_result -ne 0 ]; then'
                echo '    printf "%b" "\033[1;31m✗ Vault upload failed, aborting push\033[0m\n"'
                echo '    exit 1'
                echo "fi"
                echo ""
                echo 'printf "%b" "\033[1;32m✓ Vault upload completed, continuing with original hook...\033[0m\n"'
                echo ""
                echo "# ===== END $MARKER ====="
            } >> "$HOOK_FILE"

            printf "%b" "${GREEN_BOLD}✓ Added vault upload functionality to existing $HOOK_FILE${RESET}\n"
        else
            printf "%b" "${RED_BOLD}✗ Error: ops/sh/vault-function.sh not found${RESET}\n"
            exit 1
        fi
    else
        # No existing hook, install our hook directly
        if [ -f "ops/sh/pre-push.sh" ]; then
            cp "ops/sh/pre-push.sh" "$HOOK_FILE"
            chmod +x "$HOOK_FILE"
            printf "%b" "${GREEN_BOLD}✓ Pre-push hook installed at $HOOK_FILE${RESET}\n"
        else
            printf "%b" "${RED_BOLD}✗ Error: ops/sh/pre-push.sh not found${RESET}\n"
            exit 1
        fi
    fi

    chmod +x "$HOOK_FILE"
}

# Install based on detected hook system
if [ "$HOOK_SYSTEM" = "husky" ]; then
    install_husky_hook
else
    install_git_hook
fi

# ============================================
# Make other scripts executable
# ============================================
printf "%b" "${GREEN}▸ Making scripts executable...${RESET}\n"

scripts=(
    "./ops/sh/vault.sh"
    "./ops/sh/auto-version.sh"
    "./ops/sh/update-env-version.sh"
    "./ops/sh/app.sh"
    "./ops/sh/pre-push.sh"
    "./ops/sh/vault-function.sh"
)

for script in "${scripts[@]}"; do
    if [ -f "$script" ]; then
        chmod +x "$script"
        printf "%b" "${GREEN_BOLD}✓ Made $script executable${RESET}\n"
    else
        printf "%b" "${YELLOW_BOLD}! Script not found: $script${RESET}\n"
    fi
done

printf "%b" "${GREEN_BOLD}✓ Git hook installation complete!${RESET}\n"
echo ""
printf "%b" "${BLUE_BOLD}→ How it works:${RESET}\n"
printf "%b" "${YELLOW}Hook system: $HOOK_SYSTEM ($HOOK_DIR)${RESET}\n"
printf "%b" "${YELLOW}1. When you run 'git push' on release/* or v1 branches${RESET}\n"
printf "%b" "${YELLOW}2. The pre-push hook will automatically upload the corresponding env file to Vault${RESET}\n"
printf "%b" "${YELLOW}3. GitHub Actions will trigger and deploy with auto-versioned images${RESET}\n"
echo ""
printf "%b" "${BLUE_BOLD}→ Ready to use! Try pushing to a release branch.${RESET}\n"

exit 0
