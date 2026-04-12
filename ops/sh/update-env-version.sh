#!/usr/bin/env bash

# Script to update environment file with new version tag
# Usage: ./update-env-version.sh <env_file> <new_version>

ENV_FILE=$1
NEW_VERSION=$2

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

if [ -z "$ENV_FILE" ] || [ -z "$NEW_VERSION" ]; then
    printf "%b" "${RED_BOLD}✗ Usage: $0 <env_file> <new_version>${RESET}\n"
    printf "%b" "${YELLOW}Example: $0 ./ops/dev.env dev1.0.1${RESET}\n"
    exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
    printf "%b" "${RED_BOLD}✗ Environment file not found: $ENV_FILE${RESET}\n"
    exit 1
fi

printf "%b" "${BLUE_BOLD}→ Updating $ENV_FILE with version $NEW_VERSION${RESET}\n"

# Create backup
cp "$ENV_FILE" "${ENV_FILE}.backup"
printf "%b" "${GREEN}▸ Created backup: ${ENV_FILE}.backup${RESET}\n"

# Update DL_APP_TAG in the environment file
if grep -q "^DL_APP_TAG=" "$ENV_FILE"; then
    # Update existing DL_APP_TAG
    sed -i.tmp "s/^DL_APP_TAG=.*/DL_APP_TAG=\"$NEW_VERSION\"/" "$ENV_FILE"
    rm -f "${ENV_FILE}.tmp"
    printf "%b" "${GREEN_BOLD}✓ Updated DL_APP_TAG to $NEW_VERSION${RESET}\n"
else
    printf "%b" "${RED_BOLD}✗ DL_APP_TAG not found in $ENV_FILE${RESET}\n"
    exit 1
fi

# Verify the update
if grep -q "DL_APP_TAG=\"$NEW_VERSION\"" "$ENV_FILE"; then
    printf "%b" "${GREEN_BOLD}✓ Version update successful${RESET}\n"

    # Show the updated line
    printf "%b" "${BLUE_BOLD}→ Updated line:${RESET}\n"
    grep "DL_APP_TAG=" "$ENV_FILE"
else
    printf "%b" "${RED_BOLD}✗ Version update failed${RESET}\n"
    # Restore backup
    mv "${ENV_FILE}.backup" "$ENV_FILE"
    exit 1
fi

exit 0
