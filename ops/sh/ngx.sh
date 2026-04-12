#!/usr/bin/env bash

set -euo pipefail

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

# Simple helper for logs
info()  { printf "%b" "${BLUE_BOLD}→ %s${RESET}\n" "$*"; }
ok()    { printf "%b" "${GREEN_BOLD}✓ %s${RESET}\n" "$*"; }
err()   { printf "%b" "${RED_BOLD}✗ %s${RESET}\n" "$*" >&2; }
fatal() { err "$*"; exit 1; }

# ---- Load env ----
if [ -f .env ]; then
  # shellcheck disable=SC1091
  source .env
else
  fatal ".env file not found!"
fi

# Fallback: first argument → SITE_NAME → SERVER_NAME
SITE_NAME="${1:-${SITE_NAME:-${SERVER_NAME:-}}}"

if [ -z "${SITE_NAME:-}" ]; then
  fatal "No site name supplied (argument or SITE_NAME / SERVER_NAME in .env)."
fi

# Ensure basic tools exist
for cmd in jq curl; do
  command -v "$cmd" >/dev/null 2>&1 || fatal "Required command not found: $cmd"
done

# Derived/default endpoints
BASE_API_URL="${BASE_API_URL:-http://localhost:9000/api}"
API_URL="${API_URL:-$BASE_API_URL/sites/$SITE_NAME}"

LOGIN_CANDIDATES=(
  "${LOGIN_URL:-}"
  "$BASE_API_URL/auth/login"
  "$BASE_API_URL/login"
  "$BASE_API_URL/user/login"
)

NODE_SECRET="${NODE_SECRET:-${NODESECRET:-}}"
USERNAME="${USERNAME:-}"
PASSWORD="${PASSWORD:-}"

# Build default nginx config
NGINX_CONFIG=$(cat <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $SITE_NAME;
    return 301 https://\$host\$request_uri;
}
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name $SITE_NAME;
    ssl_certificate ${SSL_CERTIFICATE:-/etc/ssl/certs/example.crt};
    ssl_certificate_key ${SSL_CERTIFICATE_KEY:-/etc/ssl/private/example.key};
    location / {
        proxy_pass ${PROXY_PASS:-http://127.0.0.1:8080};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
)

JSON_PAYLOAD=$(jq -nc --arg name "$SITE_NAME" --arg content "$NGINX_CONFIG" '{name:$name, content:$content}')

AUTH_HEADER_NAME=""
AUTH_HEADER_VALUE=""

# --- Auth helpers ---
use_node_secret() {
  if [ -n "$NODE_SECRET" ]; then
    AUTH_HEADER_NAME="X-Node-Secret"
    AUTH_HEADER_VALUE="$NODE_SECRET"
    return 0
  fi
  return 1
}

login() {
  if use_node_secret; then
    return 0
  fi
  if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
    fatal "Missing credentials: either NODE_SECRET or USERNAME/PASSWORD required."
  fi
  for try_url in "${LOGIN_CANDIDATES[@]}"; do
    [ -z "$try_url" ] && continue
    resp=$(curl -s -w "\n%{http_code}" -X POST "$try_url" \
      -H "Content-Type: application/json" \
      --data "{\"name\":\"$USERNAME\",\"password\":\"$PASSWORD\"}" || true)
    code=$(echo "$resp" | tail -n1)
    body=$(echo "$resp" | sed '$d')
    if [[ "$code" =~ ^2 ]]; then
      token=$(echo "$body" | jq -r '.token // .data.token // .access_token // empty')
      if [ -n "$token" ] && [ "$token" != "null" ]; then
        AUTH_HEADER_NAME="Authorization"
        AUTH_HEADER_VALUE="Bearer $token"
        return 0
      fi
    fi
  done
  fatal "Login failed."
}

auth_curl() {
  local method="$1"; shift
  local url="$1"; shift
  local data="${1:-}"
  if [ -n "$AUTH_HEADER_NAME" ]; then
    curl -s -w "\n%{http_code}" -X "$method" "$url" \
      -H "$AUTH_HEADER_NAME: $AUTH_HEADER_VALUE" \
      -H "Content-Type: application/json" \
      ${data:+-d "$data"}
  else
    curl -s -w "\n%{http_code}" -X "$method" "$url" \
      -H "Content-Type: application/json" \
      ${data:+-d "$data"}
  fi
}

# --- Site helpers ---
site_exists() {
  login
  resp=$(auth_curl GET "$API_URL")
  code=$(echo "$resp" | tail -n1)
  [ "$code" = "200" ]
}

add_site() {
  login
  if site_exists; then
    info "Site '$SITE_NAME' already exists. Skipping creation."
    return 0
  fi
  info "Adding site: $SITE_NAME ..."
  resp=$(auth_curl POST "$BASE_API_URL/sites" "$JSON_PAYLOAD")
  code=$(echo "$resp" | tail -n1)
  if [[ "$code" =~ ^20 ]]; then
    ok "Site added."
    enable_site
  else
    err "Failed to add site. HTTP $code"
    echo "$resp" | sed '$d' | jq .
    exit 1
  fi
}

enable_site() {
  login
  info "Enabling site: $SITE_NAME ..."
  resp=$(auth_curl POST "$API_URL/enable" "{}")
  code=$(echo "$resp" | tail -n1)
  [[ "$code" =~ ^20 ]] && ok "Site enabled." || err "Enable failed (HTTP $code)"
}

delete_site() {
  login
  if ! site_exists; then
    info "Site '$SITE_NAME' does not exist. Skipping deletion."
    return 0
  fi
  info "Deleting site: $SITE_NAME ..."
  auth_curl DELETE "$API_URL" >/dev/null
  ok "Site deleted."
}

list_sites() {
  login
  info "Listing sites..."
  resp=$(auth_curl GET "$BASE_API_URL/sites")
  code=$(echo "$resp" | tail -n1)
  if [[ "$code" =~ ^2 ]]; then
    echo "$resp" | sed '$d' | jq .
  else
    err "Failed to list sites (HTTP $code)"
  fi
}

# --- Menu ---
cat <<EOF
Choose an action:
1) Add/Enable Site
2) Enable site
3) Check site
4) List Sites
5) Delete site
EOF
read -rp "Enter option (1,2,3,4,5): " OPTION

case "$OPTION" in
  1) add_site ;;
  2) enable_site ;;
  3) site_exists ;;
  4) list_sites ;;
  5) delete_site ;;
  *) err "Invalid option" ;;
esac
