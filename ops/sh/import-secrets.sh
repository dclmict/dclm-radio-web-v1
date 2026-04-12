#!/usr/bin/env bash
# Helper: import secrets from Vault HTTP API and write a safe env file
set -u

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

# Usage: import-secrets.sh [ENV_FILE]
ENV_FILE=${1:-${ENV_FILE:-./ops/dev.env}}

VAULT_ADDR=${VAULT_ADDR:-}
VAULT_TOKEN=${VAULT_TOKEN:-}
VAULT_SECRET_BASE_PATH=${VAULT_SECRET_BASE_PATH:-}
VAULT_MOUNT_PATH=${VAULT_MOUNT_PATH:-kv}

if [ -z "$VAULT_ADDR" ] || [ -z "$VAULT_TOKEN" ] || [ -z "$VAULT_SECRET_BASE_PATH" ]; then
  printf "%b" "${RED_BOLD}✗ Missing required VAULT_* variables. Ensure VAULT_ADDR, VAULT_TOKEN, and VAULT_SECRET_BASE_PATH are set.${RESET}\n" >&2
  exit 2
fi

tmpfile=$(mktemp)
trap 'rm -f "$tmpfile"' EXIT

printf "%b" "${BLUE_BOLD}→ Importing secrets from $VAULT_ADDR/v1/$VAULT_MOUNT_PATH/data/$VAULT_SECRET_BASE_PATH${RESET}\n" >&2

# Fetch secrets (timeout and fail gracefully)
resp=$(curl -s -S -f -H "X-Vault-Token: $VAULT_TOKEN" --max-time 30 --connect-timeout 10 \
  "$VAULT_ADDR/v1/$VAULT_MOUNT_PATH/data/$VAULT_SECRET_BASE_PATH") || {
  printf "%b" "${RED_BOLD}✗ Failed to fetch secrets from Vault${RESET}\n" >&2
  exit 3
}

# jq emits key	base64(value)
echo "$resp" | jq -r '.data.data | to_entries[] | "\(.key)\t\(.value|@base64)"' | \
while IFS=$'\t' read -r key b64; do
  # decode value safely
  val=$(printf '%s' "$b64" | base64 --decode 2>/dev/null || true)
  if [ -z "$val" ]; then
    printf '%s=""\n' "$key" >> "$tmpfile"
    continue
  fi

  # Conditional quoting based on content
  if [[ "$val" == *"$"* && "$val" != *'${'* ]]; then
    # Value contains $ but not ${} - use single quotes to preserve literal $
    # Check if value contains single quotes - if so, fall back to double quotes with escaping
    if [[ "$val" == *"'"* ]]; then
      esc=$(printf '%s' "$val" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\$/\\$/g')
      printf '%s="%s"\n' "$key" "$esc" >> "$tmpfile"
    else
      printf "%s='%s'\n" "$key" "$val" >> "$tmpfile"
    fi
  else
    # Value contains ${} or other characters - use double quotes with escaping
    esc=$(printf '%s' "$val" | sed 's/\\/\\\\/g; s/"/\\"/g')
    printf '%s="%s"\n' "$key" "$esc" >> "$tmpfile"
  fi
done

# Move temp into place atomically
mv "$tmpfile" "$ENV_FILE"
printf "%b" "${GREEN_BOLD}✓ Wrote env file: $ENV_FILE${RESET}\n" >&2
exit 0
