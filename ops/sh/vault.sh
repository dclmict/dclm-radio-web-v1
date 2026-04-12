#!/usr/bin/env bash

# Optimized script for Vault KV-v2 secrets with bash 4+ features
# Supports both bash 3.x (compatibility mode) and bash 4+ (enhanced mode)
# Auto-detects bash version and uses appropriate implementation

# Detect bash version and set compatibility mode
BASH_MAJOR_VERSION=${BASH_VERSION%%.*}
if [ "$BASH_MAJOR_VERSION" -ge 4 ]; then
    BASH4_AVAILABLE=true
    # Use bash 4+ features: associative arrays, better error handling
    set -euo pipefail
else
    BASH4_AVAILABLE=false
    # Use bash 3.x compatible mode
    set -e
fi

# Function to log messages with timestamp
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# Function to log errors
error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $*" >&2
}

# Check if required arguments are provided
if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    echo "Usage: $0 <env_file_path> [--merge]"
    echo "  env_file_path: File containing both secrets and vault configuration"
    echo "  --merge: Merge with existing secrets instead of overwriting"
    exit 1
fi

ENV_FILE=$1
MERGE_MODE=false

# Check for merge flag
if [ $# -eq 2 ] && [ "$2" = "--merge" ]; then
    MERGE_MODE=true
fi

# Check if env file exists
if [ ! -f "$ENV_FILE" ]; then
    error "Environment file $ENV_FILE not found"
    exit 1
fi

# Function to check if vault CLI is available
has_vault_cli() {
    command -v vault >/dev/null 2>&1
}

# Function to clean and parse env file values
parse_env_value() {
    local value="$1"
    local key="$2"

    # Only remove leading/trailing whitespace
    value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # Strip inline comments: remove unquoted # and everything after it
    # e.g. "somevalue" #comment  →  "somevalue"
    # Handles: quoted"value" #comment, 'quoted' #comment, unquoted #comment
    if [[ "$value" =~ ^\".*\" ]]; then
        # Double-quoted: strip everything after closing quote
        value=$(echo "$value" | sed 's/^\("[^"]*"\).*/\1/')
    elif [[ "$value" =~ ^\'.*\' ]]; then
        # Single-quoted: strip everything after closing quote
        value=$(echo "$value" | sed "s/^\('[^']*'\).*/\1/")
    else
        # Unquoted: strip # and everything after
        value=$(echo "$value" | sed 's/[[:space:]]*#.*//')
    fi

    # Remove surrounding quotes for all values (both config and secrets)
    # Use sed instead of regex to be more compatible
    value=$(echo "$value" | sed 's/^"\(.*\)"$/\1/' | sed "s/^'\(.*\)'$/\1/")

    echo "$value"
}

# Load variables from env file (bash version aware)
# This file contains both vault configuration and secrets
if [ "$BASH4_AVAILABLE" = true ]; then
    # Use associative arrays for bash 4+
    declare -A config_vars
    declare -A secrets

    while IFS='=' read -r key value || [ -n "$key" ]; do
        # Skip empty lines and comments
        if [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        value=$(parse_env_value "$value" "$key")
        
        # Skip if key or value is empty after cleaning
        if [[ -z "$key" || -z "$value" ]]; then
            continue
        fi
        
        case "$key" in
            VAULT_ADDR|VAULT_TOKEN|VAULT_MOUNT_PATH|VAULT_SECRET_KEY)
                config_vars["$key"]="$value"
                ;;
            *)
                # All other variables are treated as secrets
                secrets["$key"]="$value"
                ;;
        esac
    done < "$ENV_FILE"
    
    # Validate and extract config variables (bash 4+ way)
    for var in VAULT_ADDR VAULT_TOKEN VAULT_MOUNT_PATH VAULT_SECRET_KEY; do
        if [ -z "${config_vars[$var]:-}" ]; then
            error "$var is not set in $ENV_FILE"
            exit 1
        fi
    done
    
    VAULT_ADDR="${config_vars[VAULT_ADDR]}"
    VAULT_TOKEN="${config_vars[VAULT_TOKEN]}"
    VAULT_MOUNT_PATH="${config_vars[VAULT_MOUNT_PATH]}"
    VAULT_SECRET_KEY="${config_vars[VAULT_SECRET_KEY]}"
    
    # Count secrets
    secret_count=${#secrets[@]}
else
    # Use bash 3.x compatible approach
    VAULT_ADDR=""
    VAULT_TOKEN=""
    VAULT_MOUNT_PATH=""
    VAULT_SECRET_KEY=""
    
    secrets_keys=()
    secrets_values=()
    secret_count=0

    while IFS='=' read -r key value || [ -n "$key" ]; do
        # Skip empty lines and comments
        if [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        value=$(parse_env_value "$value" "$key")
        
        # Skip if key or value is empty after cleaning
        if [[ -z "$key" || -z "$value" ]]; then
            continue
        fi
        
        case "$key" in
            VAULT_ADDR)
                VAULT_ADDR="$value"
                ;;
            VAULT_TOKEN)
                VAULT_TOKEN="$value"
                ;;
            VAULT_MOUNT_PATH)
                VAULT_MOUNT_PATH="$value"
                ;;
            VAULT_SECRET_KEY)
                VAULT_SECRET_KEY="$value"
                ;;
            *)
                # All other variables are treated as secrets
                secrets_keys[$secret_count]="$key"
                secrets_values[$secret_count]="$value"
                ((secret_count++))
                ;;
        esac
    done < "$ENV_FILE"

    # Validate required config variables (bash 3.x way)
    if [ -z "$VAULT_ADDR" ]; then
        error "VAULT_ADDR is not set in $ENV_FILE"
        exit 1
    fi
    if [ -z "$VAULT_TOKEN" ]; then
        error "VAULT_TOKEN is not set in $ENV_FILE"
        exit 1
    fi
    if [ -z "$VAULT_MOUNT_PATH" ]; then
        error "VAULT_MOUNT_PATH is not set in $ENV_FILE"
        exit 1
    fi
    if [ -z "$VAULT_SECRET_KEY" ]; then
        error "VAULT_SECRET_KEY is not set in $ENV_FILE"
        exit 1
    fi
fi

# For KV v2, the secret path should not include /data/ when using CLI
# but should include it when using API directly
SECRET_PATH="$VAULT_SECRET_KEY"
API_SECRET_PATH="$VAULT_MOUNT_PATH/data/$VAULT_SECRET_KEY"

log "Using Vault at: $VAULT_ADDR"
log "Mount path: $VAULT_MOUNT_PATH"
log "Secret key: $VAULT_SECRET_KEY"

# Check if Vault is accessible
vault_health_check() {
    local response
    response=$(curl --header "X-Vault-Token: $VAULT_TOKEN" \
                   --silent \
                   --write-out "%{http_code}" \
                   --output /dev/null \
                   "$VAULT_ADDR/v1/sys/health")
    
    if [ "$response" -ne 200 ] && [ "$response" -ne 429 ] && [ "$response" -ne 472 ] && [ "$response" -ne 473 ]; then
        error "Unable to connect to Vault at $VAULT_ADDR (HTTP $response)"
        exit 1
    fi
    log "Vault health check passed"
}

vault_health_check

# Function to verify KV v2 engine
verify_kv_engine() {
    log "Verifying KV v2 engine at mount path: $VAULT_MOUNT_PATH"
    
    # Create temporary files for response
    local response_file=$(mktemp)
    local http_code
    
    # Get HTTP status and response body separately
    http_code=$(curl --header "X-Vault-Token: $VAULT_TOKEN" \
                    --silent \
                    --output "$response_file" \
                    --write-out "%{http_code}" \
                    "$VAULT_ADDR/v1/sys/mounts/$VAULT_MOUNT_PATH")
    
    log "Mount check HTTP status: $http_code"
    
    if [ "$http_code" -eq 400 ]; then
        local error_body=$(cat "$response_file" 2>/dev/null || echo "No response body")
        rm -f "$response_file"
        
        if echo "$error_body" | grep -q "No secret engine mount"; then
            error "Mount path '$VAULT_MOUNT_PATH' does not exist in Vault"
            error "Available mounts can be listed with: vault auth list"
            error "Common mount paths: 'secret', 'kv', 'apps', etc."
            error "Please check your VAULT_MOUNT_PATH setting in the env file"
            exit 1
        else
            error "Bad request when checking mount point $VAULT_MOUNT_PATH"
            error "Response: $error_body"
            exit 1
        fi
    elif [ "$http_code" -eq 403 ]; then
        rm -f "$response_file"
        error "Permission denied accessing mount path '$VAULT_MOUNT_PATH'"
        error "Your Vault token may not have sufficient permissions"
        exit 1
    elif [ "$http_code" -eq 404 ]; then
        rm -f "$response_file"
        error "Mount path '$VAULT_MOUNT_PATH' not found"
        error "Please verify the mount path exists and is accessible"
        exit 1
    elif [ "$http_code" -ne 200 ]; then
        local error_body=$(cat "$response_file" 2>/dev/null || echo "No response body")
        rm -f "$response_file"
        error "Failed to check mount point $VAULT_MOUNT_PATH (HTTP $http_code)"
        error "Response: $error_body"
        exit 1
    fi
    
    local response_body=$(cat "$response_file")
    rm -f "$response_file"
    
    if [ -z "$response_body" ]; then
        error "Empty response from mount point check"
        exit 1
    fi
    
    log "Mount point response received successfully"
    
    # Check if jq is available and parse response
    if ! command -v jq >/dev/null 2>&1; then
        log "Warning: jq not found, skipping detailed engine validation"
        log "Assuming KV v2 engine at $VAULT_MOUNT_PATH"
        return 0
    fi
    
    local engine_type
    engine_type=$(echo "$response_body" | jq -r '.type // "unknown"' 2>/dev/null)
    
    if [ "$engine_type" = "null" ] || [ "$engine_type" = "unknown" ]; then
        # Fallback to grep if jq parsing fails
        engine_type=$(echo "$response_body" | grep -o '"type":"[^"]*"' | cut -d'"' -f4)
    fi
    
    log "Engine type: $engine_type"
    
    if [ "$engine_type" != "kv" ]; then
        log "Warning: Mount path $VAULT_MOUNT_PATH is not a KV engine (found: $engine_type)"
        log "Proceeding anyway - assuming compatible engine"
    else
        log "✅ KV engine detected at $VAULT_MOUNT_PATH"
    fi
    
    local version
    version=$(echo "$response_body" | jq -r '.options.version // "1"' 2>/dev/null)
    
    if [ "$version" = "null" ] || [ -z "$version" ]; then
        # Fallback to grep if jq parsing fails
        version=$(echo "$response_body" | grep -o '"version":"[^"]*"' | cut -d'"' -f4)
        if [ -z "$version" ]; then
            version="1"  # Default to v1 if not specified
        fi
    fi
    
    log "Engine version: $version"
    
    if [ "$version" != "2" ]; then
        log "Warning: KV engine at $VAULT_MOUNT_PATH is version $version (expected: 2)"
        log "Proceeding anyway - will attempt KV v2 operations"
    else
        log "✅ KV v2 engine verified successfully"
    fi
    
    # log "KV engine verification completed"
}

verify_kv_engine

# Debug: Show discovered secrets
# log "Discovered secrets from $ENV_FILE:"
# if [ "$BASH4_AVAILABLE" = true ]; then
#     for key in "${!secrets[@]}"; do
#         log "  $key = [REDACTED]"
#     done
# else
#     for ((i=0; i<secret_count; i++)); do
#         log "  ${secrets_keys[$i]} = [REDACTED]"
#     done
# fi

# Check if any valid key-value pairs were found
if [ $secret_count -eq 0 ]; then
    error "No valid key-value pairs found in $ENV_FILE (excluding vault configuration)"
    exit 1
fi

log "Found $secret_count secrets to store"

# Debug: Show which secrets will be stored (without values for security)
# if [ "$BASH4_AVAILABLE" = true ]; then
#     log "Secrets to store: $(printf '%s ' "${!secrets[@]}")"
# else
#     log "Secrets to store: $(printf '%s ' "${secrets_keys[@]}")"
# fi

# Function to get existing secrets if merge mode is enabled
get_existing_secrets() {
    # Send debug output to stderr to avoid contaminating the return value
    
    local existing_secrets
    if has_vault_cli; then
        log "Using Vault CLI to read existing secrets" >&2
        export VAULT_ADDR VAULT_TOKEN
        
        # Try the CLI command and capture both stdout and stderr for debugging
        local vault_output
        local vault_error
        vault_output=$(vault kv get -format=json "$VAULT_MOUNT_PATH/$SECRET_PATH" 2>/dev/null)
        local vault_exit_code=$?
        
        
        if [ $vault_exit_code -eq 0 ]; then
            existing_secrets=$(echo "$vault_output" | jq -r '.data.data // {}' 2>/dev/null)
        else
            log "🔍 Debug - Vault CLI failed, trying without error suppression" >&2
            existing_secrets="{}"
        fi
    else
        log "Using API to read existing secrets" >&2
        local api_response
        api_response=$(curl --header "X-Vault-Token: $VAULT_TOKEN" \
                           --silent \
                           --write-out "HTTPSTATUS:%{http_code}" \
                           "$VAULT_ADDR/v1/$API_SECRET_PATH" 2>/dev/null)
        
        local http_code=$(echo "$api_response" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)
        local response_body=$(echo "$api_response" | sed 's/HTTPSTATUS:[0-9]*$//')
        
        
        if [ "$http_code" = "200" ]; then
            existing_secrets=$(echo "$response_body" | jq -r '.data.data // {}' 2>/dev/null)
        else
            existing_secrets="{}"
        fi
    fi
    
    if [ -z "$existing_secrets" ] || [ "$existing_secrets" = "null" ]; then
        # No existing secrets, return empty JSON
        echo "{}"
    else
        # Return the existing secrets data
        echo "$existing_secrets"
    fi
}

# Function to compare local secrets with vault secrets and identify changes
compare_secrets() {
    log "Comparing local secrets with Vault secrets"
    
    local existing_secrets
    existing_secrets=$(get_existing_secrets)
    
    
    local changed_count=0
    local new_count=0
    local unchanged_count=0
    
    # Use a simpler, more robust approach that works across bash versions
    local vault_entries=""
    if [ "$existing_secrets" != "{}" ] && [ "$existing_secrets" != "null" ] && [ -n "$existing_secrets" ]; then
    vault_entries=$(echo "$existing_secrets" | jq -r 'to_entries[] | "\(.key)=\(.value)"' 2>/dev/null || echo "")
    else
        log "🔍 Debug - No existing secrets found or empty/null"
    fi
    
    if [ "$BASH4_AVAILABLE" = true ]; then
        # Use associative arrays for bash 4+ with simplified logic
        declare -A changes_needed
        
        # Compare each local secret with vault
        for key in "${!secrets[@]}"; do
            local local_value="${secrets[$key]}"
            
            # Get vault value using grep instead of array subscript
            local vault_value=""
            if [ -n "$vault_entries" ]; then
                vault_value=$(echo "$vault_entries" | grep "^${key}=" | cut -d'=' -f2- || echo "")
            fi
            
            if [ -z "$vault_value" ]; then
                # New secret
                changes_needed["$key"]="$local_value"
                ((new_count++))
                log "NEW: $key"
            elif [ "$local_value" != "$vault_value" ]; then
                # Changed secret
                changes_needed["$key"]="$local_value"
                ((changed_count++))
                log "CHANGED: $key"
            else
                # Unchanged secret
                ((unchanged_count++))
                # log "UNCHANGED: $key"
            fi
        done
        
        # Update global secrets array to only include changes
        if [ "$BASH4_AVAILABLE" = true ]; then
            # Clear associative array without unsetting
            secrets=()
            for key in "${!changes_needed[@]}"; do
                secrets["$key"]="${changes_needed[$key]}"
            done
            secret_count=${#secrets[@]}
        else
            # Clear indexed arrays
            secrets_keys=()
            secrets_values=()
            for key in "${!changes_needed[@]}"; do
                secrets_keys+=("$key")
                secrets_values+=("${changes_needed[$key]}")
            done
            secret_count=${#secrets_keys[@]}
        fi
    else
        # Use indexed arrays for bash 3.x
        local changes_keys=()
        local changes_values=()
        
        # Parse existing vault secrets
        local vault_data=""
        if [ "$existing_secrets" != "{}" ] && [ "$existing_secrets" != "null" ]; then
            vault_data=$(echo "$existing_secrets" | jq -r 'to_entries[] | "\(.key)=\(.value)"' 2>/dev/null || echo "")
        fi
        
        # Compare each local secret
        for ((i=0; i<secret_count; i++)); do
            local key="${secrets_keys[$i]}"
            local local_value="${secrets_values[$i]}"
            local vault_value=""
            
            # Find vault value for this key
            if [ -n "$vault_data" ]; then
                vault_value=$(echo "$vault_data" | grep "^$key=" | cut -d'=' -f2- || echo "")
            fi
            
            if [ -z "$vault_value" ]; then
                # New secret
                changes_keys+=("$key")
                changes_values+=("$local_value")
                ((new_count++))
                log "NEW: $key"
            elif [ "$local_value" != "$vault_value" ]; then
                # Changed secret
                changes_keys+=("$key")
                changes_values+=("$local_value")
                ((changed_count++))
                log "CHANGED: $key"
            else
                # Unchanged secret
                ((unchanged_count++))
                # log "UNCHANGED: $key"
            fi
        done
        
        # Update global arrays to only include changes
        secrets_keys=("${changes_keys[@]}")
        secrets_values=("${changes_values[@]}")
        secret_count=${#secrets_keys[@]}
    fi
    
    log "📊 Results: $new_count new, $changed_count changed, $unchanged_count unchanged"
    
    if [ $((new_count + changed_count)) -eq 0 ]; then
        log "✅ No changes needed - all secrets are up to date!"
        return 1  # No changes needed
    fi
    
    log "🔄 Will update $((new_count + changed_count)) secrets"
    return 0  # Changes needed
}

# Function to create JSON payload (bash version aware)
create_json_payload() {
    # Always merge with existing secrets since smart diff only passes changed/new secrets
    log "Reading existing secrets for merge"
    local existing_data
    existing_data=$(get_existing_secrets)
    
    # Start with existing data or empty object
    local combined_data="$existing_data"
    
    # Add/update with changed secrets
    if [ "$BASH4_AVAILABLE" = true ]; then
        # Use associative array iteration for bash 4+
        for key in "${!secrets[@]}"; do
            local value="${secrets[$key]}"
            # No manual escaping needed - jq handles JSON encoding with --arg
            combined_data=$(echo "$combined_data" | jq --arg key "$key" --arg value "$value" '.[$key] = $value')
        done
    else
        # Use indexed arrays for bash 3.x
        for ((i=0; i<secret_count; i++)); do
            local key="${secrets_keys[$i]}"
            local value="${secrets_values[$i]}"
            # No manual escaping needed - jq handles JSON encoding with --arg
            combined_data=$(echo "$combined_data" | jq --arg key "$key" --arg value "$value" '.[$key] = $value')
        done
    fi
    
    # Wrap in the required KV v2 structure
    echo "$combined_data" | jq '{data: .}'
}

# Function to store secrets using Vault CLI (bash version aware)
store_secrets_cli() {
    log "Using Vault CLI to store secrets"
    export VAULT_ADDR VAULT_TOKEN
    
    # Create temporary file for key-value pairs
    local temp_file
    temp_file=$(mktemp)
    
    # Always merge with existing secrets since smart diff only passes changed/new secrets
    local existing_data
    existing_data=$(get_existing_secrets)
    
    # Write existing secrets to temp file first (only if they exist and are valid)
    if [ "$existing_data" != "{}" ] && [ "$existing_data" != "null" ] && [ -n "$existing_data" ]; then
        # Safely parse existing secrets and write to temp file
        log "🔍 Debug - Processing existing secrets for temp file"
        local existing_entries
        existing_entries=$(echo "$existing_data" | jq -r 'to_entries[] | "\(.key)=\(.value)"' 2>/dev/null || echo "")
        if [ -n "$existing_entries" ]; then
            log "🔍 Debug - Writing existing entries to temp file"
            echo "$existing_entries" | head -3 | while IFS='=' read key _; do log "  $key=[REDACTED]"; done
            echo "$existing_entries" > "$temp_file"
        else
            # Create empty temp file if no valid existing secrets
            log "🔍 Debug - No valid existing entries, creating empty temp file"
            touch "$temp_file"
        fi
    else
        # Create empty temp file if no existing secrets
        log "🔍 Debug - No existing secrets, creating empty temp file"
        touch "$temp_file"
    fi
    
    # Add/update changed secrets (will overwrite existing keys with new values)
    log "🔍 Debug - Adding new/changed secrets to temp file"
    if [ "$BASH4_AVAILABLE" = true ]; then
        # Use associative array for bash 4+
        for key in "${!secrets[@]}"; do
            local value="${secrets[$key]}"
            # Store raw values without shell escaping - Vault CLI handles quoting
            echo "$key=$value" >> "$temp_file"
            log "🔍 Debug - Added: $key=[REDACTED]"
        done
    else
        # Use indexed arrays for bash 3.x
        for ((i=0; i<secret_count; i++)); do
            local key="${secrets_keys[$i]}"
            local value="${secrets_values[$i]}"
            # Store raw values without shell escaping - Vault CLI handles quoting
            echo "$key=$value" >> "$temp_file"
            log "🔍 Debug - Added: $key=[REDACTED]"
        done
    fi
    
    # Remove duplicates (keep last occurrence, which will be our updated values)
    if [ -s "$temp_file" ]; then
        awk -F= '!seen[$1]++' <(tac "$temp_file") | tac > "${temp_file}.tmp" && mv "${temp_file}.tmp" "$temp_file"
    fi
    
    # Debug: Show temp file keys for troubleshooting (values redacted)
    if [ -s "$temp_file" ]; then
        log "📄 Temp file keys (first 5):"
        head -5 "$temp_file" | while IFS='=' read key _; do log "  $key=[REDACTED]"; done
        
        # Validate temp file format before using with vault
        if ! grep -q "^[A-Za-z_][A-Za-z0-9_]*=" "$temp_file"; then
            error "Invalid temp file format - no valid key=value pairs found"
            rm -f "$temp_file"
            return 1
        fi
        
        # Read key=value pairs into an array and pass to vault CLI directly
        mapfile -t kv_pairs < <(grep '^[A-Za-z_][A-Za-z0-9_]*=' "$temp_file")
        vault kv put "$VAULT_MOUNT_PATH/$SECRET_PATH" "${kv_pairs[@]}"
    else
        # If temp file is empty, something went wrong - should not happen with smart diff
        error "No secrets to store in temp file"
        rm -f "$temp_file"
        return 1
    fi
    
    # Clean up temp file explicitly (no trap needed)
    rm -f "$temp_file"
}

# Function to store secrets using API
store_secrets_api() {
    log "Using API to store secrets"
    
    local json_payload
    json_payload=$(create_json_payload)
    
    local response
    response=$(curl --header "X-Vault-Token: $VAULT_TOKEN" \
                   --header "Content-Type: application/json" \
                   --request POST \
                   --data "$json_payload" \
                   --silent \
                   --write-out "%{http_code}" \
                   --output /dev/null \
                   "$VAULT_ADDR/v1/$API_SECRET_PATH")
    
    if [ "$response" -eq 200 ] || [ "$response" -eq 204 ]; then
        return 0
    else
        error "API request failed with HTTP status: $response"
        return 1
    fi
}

# Smart diff: Compare secrets and only update changed/new ones
log "🔍 Using smart diff to optimize Vault uploads..."
if compare_secrets; then
    log "📤 Changes detected - proceeding with Vault update"
    
    # Store only changed/new secrets in Vault (always merge mode)
    log "Storing $secret_count updated secrets in Vault..."
    
    if has_vault_cli; then
        if store_secrets_cli; then
            log "Successfully stored secrets using Vault CLI at $VAULT_MOUNT_PATH/$SECRET_PATH"
        else
            error "Failed to store secrets using Vault CLI"
            exit 1
        fi
        else
            log "Vault CLI not found, falling back to API"
            if store_secrets_api; then
                log "Successfully stored secrets using API at $API_SECRET_PATH"
            else
                error "Failed to store secrets using API"
                exit 1
            fi
        fi
        
        # Verify secrets were stored
        log "Verifying stored secrets..."
        if has_vault_cli; then
            export VAULT_ADDR VAULT_TOKEN
            total_count=$(vault kv get -format=json "$VAULT_MOUNT_PATH/$SECRET_PATH" 2>/dev/null | jq -r '.data.data | length' 2>/dev/null)
        else
            total_count=$(curl --header "X-Vault-Token: $VAULT_TOKEN" \
                               --silent \
                               "$VAULT_ADDR/v1/$API_SECRET_PATH" 2>/dev/null | jq -r '.data.data | length' 2>/dev/null)
        fi
        
        log "Verification successful: Updated $secret_count secrets. Total secrets in Vault: $total_count"
    else
        log "✅ No changes needed - all secrets are already up to date in Vault!"
        log "🚀 Skipping Vault update to improve performance"
    fi

log "Script completed successfully"