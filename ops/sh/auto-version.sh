#!/usr/bin/env bash

# Auto-versioning script for Docker images
# This script automatically increments version tags based on branch and existing tags

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

# Get branch from environment or parameter
BRANCH=${1:-${GITHUB_REF_NAME:-$(git rev-parse --abbrev-ref HEAD)}}

printf "%b" "${BLUE_BOLD}→ Auto-versioning for branch: $BRANCH${RESET}\n"

# Determine version prefix based on branch
case "$BRANCH" in
    release/dev*|dev-*)
        VERSION_PREFIX="dev"
        ;;
    release/prev*|prev-*)
        VERSION_PREFIX="prv"
        ;;
    release/prod*|prod-*|v1)
        VERSION_PREFIX="v"
        ;;
    *)
        printf "%b" "${RED_BOLD}✗ Unsupported branch: $BRANCH${RESET}\n"
        exit 1
        ;;
esac

# Parse the current environment to get registry details
# Determine env file based on branch
case "$BRANCH" in
    "release/dev") ENV_FILE="./ops/dev.env" ;;
    "release/dev-v2") ENV_FILE="./ops/dev-v2.env" ;;
    "release/prev") ENV_FILE="./ops/prev.env" ;;
    "release/prev-v2") ENV_FILE="./ops/prev-v2.env" ;;
    "release/prod") ENV_FILE="./ops/prod.env" ;;
    "release/prod-v2") ENV_FILE="./ops/prod-v2.env" ;;
    "v1") ENV_FILE="./ops/v1.env" ;;
    dev-*|prev-*|prod-*) ENV_FILE="./ops/${BRANCH}.env" ;;
    release/dev-*|release/prev-*|release/prod-*) ENV_FILE="./ops/${BRANCH#release/}.env" ;;
esac
if [ -f "$ENV_FILE" ]; then
    # Parse env file instead of sourcing to avoid execution issues
    while IFS='=' read -r key value || [ -n "$key" ]; do
        # Skip empty lines and comments
        if [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]]; then
            continue
        fi

        key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        # Remove surrounding single or double quotes (bash-safe)
        # Only trim when the value length is >= 2
        if [ ${#value} -ge 2 ]; then
            # Check for matching surrounding double quotes
            if [ "${value:0:1}" = '"' ] && [ "${value: -1}" = '"' ]; then
                value="${value:1:$(( ${#value} - 2 ))}"
            # Check for matching surrounding single quotes
            elif [ "${value:0:1}" = "'" ] && [ "${value: -1}" = "'" ]; then
                value="${value:1:$(( ${#value} - 2 ))}"
            fi
        fi

        # Export only the variables we need
        case "$key" in
            VAULT_ADDR|VAULT_TOKEN|VAULT_MOUNT_PATH|VAULT_SECRET_KEY)
                # normalize mount path and secret key (remove leading/trailing slashes)
                if [ "$key" = "VAULT_MOUNT_PATH" ]; then
                    # remove any leading/trailing slashes
                    value=$(echo "$value" | sed 's:^/*::; s:/*$::')
                fi
                if [ "$key" = "VAULT_SECRET_KEY" ]; then
                    value=$(echo "$value" | sed 's:^/*::; s:/*$::')
                fi
                export "$key"="$value"
                ;;
        esac
    done < "$ENV_FILE"
else
    printf "%b" "${RED_BOLD}✗ Environment file not found: $ENV_FILE${RESET}\n"
    exit 1
fi

## Operation: fetch latest version from unified version file
fetch_latest_version_from_file() {
    local prefix=$1
    local version_file="./.version"

    printf "%b" "${YELLOW_BOLD}! Checking latest version for prefix: $prefix${RESET}\n" >&2

    if [ -f "$version_file" ]; then
        local last_version
        last_version=$(grep "^${prefix}" "$version_file" | tail -1 | sed 's/\x1b\[[0-9;]*m//g' | tr -d '[:space:]') || true
        if [[ "$last_version" =~ ^${prefix}[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            printf "%b" "${GREEN_BOLD}✓ Found previous version: $last_version${RESET}\n" >&2
            echo "$last_version"
            return 0
        fi
        printf "%b" "${YELLOW_BOLD}! No valid version found for prefix $prefix in $version_file${RESET}\n" >&2
    else
        printf "%b" "${YELLOW_BOLD}! No version file found, starting with initial version${RESET}\n" >&2
    fi

    echo "${prefix}1.0.0"
}

# Function to increment version
## Operation: increment version tag (major.minor.patch with patch rollover at 40)
increment_version_tag() {
    local current_version=$1
    local prefix=$2

    local version_only=${current_version#$prefix}
    IFS='.' read -r major minor patch <<< "$version_only"
    patch=$((patch + 1))
    if [ $patch -gt 40 ]; then
        patch=0
        minor=$((minor + 1))
    fi
    echo "${prefix}${major}.${minor}.${patch}"
}

# Get current version: use Vault as source of truth if available
# --- Vault helpers
vault_fetch_secret() {
    # Returns: HTTPSTATUS:<code>\n<body>
    curl -s -H "X-Vault-Token: $VAULT_TOKEN" \
        -w "\nHTTPSTATUS:%{http_code}" \
        --max-time 30 --connect-timeout 10 \
        "$VAULT_ADDR/v1/$VAULT_MOUNT_PATH/data/$VAULT_SECRET_KEY"
}

vault_write_secret_payload() {
    # $1 = payload JSON
    local payload="$1"
    # Return response body and HTTP status marker
    curl -s -w "\nHTTPSTATUS:%{http_code}" -X POST -H "X-Vault-Token: $VAULT_TOKEN" -H "Content-Type: application/json" \
        -d "$payload" "$VAULT_ADDR/v1/$VAULT_MOUNT_PATH/data/$VAULT_SECRET_KEY"
}

# Determine current version using Vault (preferred) or file (fallback)
CURRENT_VERSION=""
if [ -n "${VAULT_ADDR:-}" ] && [ -n "${VAULT_TOKEN:-}" ]; then
    resp=$(vault_fetch_secret) || true
    http_status=$(echo "$resp" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2 || echo "")
    body=$(echo "$resp" | sed 's/HTTPSTATUS:[0-9]*$//' )

    if [ "$http_status" = "200" ]; then
        vault_version=$(echo "$body" | jq -r '.data.data.VERSION // empty' 2>/dev/null || echo "")
        if [ -n "$vault_version" ] && [[ "$vault_version" == "${VERSION_PREFIX}"* ]]; then
            printf "Found version in Vault: $vault_version\n" >&2
            CURRENT_VERSION="$vault_version"
        elif [ -n "$vault_version" ]; then
            # Wrong prefix — extract numeric part and re-apply correct prefix
            numeric_part=$(echo "$vault_version" | sed 's/^[^0-9]*//')
            if [[ "$numeric_part" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                CURRENT_VERSION="${VERSION_PREFIX}${numeric_part}"
                printf "Vault version '$vault_version' has wrong prefix, corrected to '$CURRENT_VERSION'\n" >&2
            else
                printf "Vault version '$vault_version' has unrecognised format, ignoring\n" >&2
            fi
        else
            # VERSION absent but mount exists
            printf "Vault mount exists but VERSION key absent, will create VERSION on update\n" >&2
        fi
    elif [ "$http_status" = "404" ]; then
        # mount path missing - will fallback to file
        printf "Vault mount path not found (HTTP 404) - falling back to version file\n" >&2
    else
        printf "Vault read failed (HTTP ${http_status:-unknown}) - falling back to version file\n" >&2
    fi
fi

if [ -z "$CURRENT_VERSION" ]; then
    CURRENT_VERSION=$(fetch_latest_version_from_file "$VERSION_PREFIX")
fi

# Generate new version
NEW_VERSION=$(increment_version_tag "$CURRENT_VERSION" "$VERSION_PREFIX")

# Function to update the unified version file
## Operation: save version to file
save_version_to_file() {
    local prefix=$1
    local new_version=$2
    local version_file="./.version"

    if [ ! -f "$version_file" ]; then
        touch "$version_file"
        printf "%b" "${BLUE_BOLD}→ Created new unified version file${RESET}\n" >&2
    fi

    grep -v "^${prefix}" "$version_file" > "${version_file}.tmp" 2>/dev/null || true
    echo "$new_version" >> "${version_file}.tmp"
    sort "${version_file}.tmp" > "$version_file"
    rm -f "${version_file}.tmp"
    printf "%b" "${GREEN_BOLD}✓ Updated $version_file with $new_version${RESET}\n" >&2
}

## Operation: save version to Vault (merge with existing data if present)
save_version_to_vault() {
    local new_version=$1
    # Fetch existing data (if any)
    resp=$(vault_fetch_secret) || true
    http_status=$(echo "$resp" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2 || echo "")
    body=$(echo "$resp" | sed 's/HTTPSTATUS:[0-9]*$//')

    if [ "$http_status" = "200" ]; then
        # Build merged JSON using jq directly from the fetched body
        merged=$(echo "$body" | jq --arg v "$new_version" '.data.data // {} | . + {VERSION: $v}')
        payload=$(echo "$merged" | jq -c '{data: .}')
    elif [ "$http_status" = "404" ]; then
        # Mount path does not exist - cannot write to Vault here; caller should fallback to file
        printf "%b" "${YELLOW_BOLD}! Vault mount path not found (HTTP 404). Will not attempt write; falling back to version file.${RESET}\n" >&2
        return 2
    else
        printf "%b" "${RED_BOLD}✗ Vault read failed (HTTP ${http_status:-unknown}) - skipping Vault write${RESET}\n" >&2
        return 1
    fi

    # Perform the write and capture response body + status
    write_resp=$(vault_write_secret_payload "$payload" || true)
    write_status=$(echo "$write_resp" | tr -d '\r' | sed -n 's/.*HTTPSTATUS:\([0-9]*\)$/\1/p')
    write_body=$(echo "$write_resp" | sed 's/\nHTTPSTATUS:[0-9]*$//')

    if [ -n "$write_status" ] && [ "$write_status" -ge 200 ] && [ "$write_status" -lt 300 ]; then
        printf "%b" "${GREEN_BOLD}✓ Vault update successful (HTTP $write_status)${RESET}\n" >&2
        return 0
    else
        printf "%b" "${RED_BOLD}✗ Vault update failed (HTTP ${write_status:-unknown})${RESET}\n" >&2
        printf "%b" "${YELLOW_BOLD}! Debug: payload -> ${RESET}\n" >&2
        echo "$payload" | sed -n '1,200p' >&2
        printf "%b" "${YELLOW_BOLD}! Debug: vault response -> ${RESET}\n" >&2
        echo "$write_body" | sed -n '1,200p' >&2
        return 1
    fi
}

printf "%b" "${GREEN_BOLD}✓ Version bump: $CURRENT_VERSION → $NEW_VERSION${RESET}\n" >&2

if [ -n "${VAULT_ADDR:-}" ] && [ -n "${VAULT_TOKEN:-}" ]; then
    # Vault available - attempt to save to Vault (and file on success)
    if save_version_to_vault "$NEW_VERSION"; then
        # On successful Vault write, also update local version file
        save_version_to_file "$VERSION_PREFIX" "$NEW_VERSION"
    else
        # Vault write failed - fallback to file-only update
        printf "%b" "${YELLOW_BOLD}! Vault write failed - updating version file only${RESET}\n" >&2
        save_version_to_file "$VERSION_PREFIX" "$NEW_VERSION"
    fi
else
    # No Vault configured - only update file
    save_version_to_file "$VERSION_PREFIX" "$NEW_VERSION"
fi

# Export the new version for use in GitHub Actions
# echo "NEW_VERSION=$NEW_VERSION" >> $GITHUB_ENV || true
# echo "DL_APP_TAG=$NEW_VERSION" >> $GITHUB_ENV || true

# Also output for local use (to stderr to avoid contaminating stdout)
printf "%b" "${BLUE_BOLD}→ New version tag: $NEW_VERSION${RESET}\n" >&2

# Output the clean version to stdout for capture
echo "$NEW_VERSION"

exit 0
