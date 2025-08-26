#!/usr/bin/env bash
set -euo pipefail

APP_ID="${APP_ID:?APP_ID required}"
INSTALLATION_ID="${INSTALLATION_ID:?INSTALLATION_ID required}"
PRIVATE_KEY_FILE="${PRIVATE_KEY_FILE:-/secrets/private-key.pem}"
GITHUB_API_URL="${GITHUB_API_URL:-https://api.github.com}"

base64url() {
  # read stdin -> base64url w/out padding
  openssl base64 -e | tr -d '\n' | tr '+/' '-_' | tr -d '='
}

header='{"alg":"RS256","typ":"JWT"}'
iat=$(date +%s)
iat=$((iat - 60))
exp=$((iat + 600))
payload=$(printf '{"iat":%s,"exp":%s,"iss":%s}' "$iat" "$exp" "$APP_ID")

h64=$(printf '%s' "$header" | base64url)
p64=$(printf '%s' "$payload" | base64url)

unsigned="${h64}.${p64}"

# sign: binary signature -> base64 -> base64url
sig=$(printf '%s' "$unsigned" | \
  openssl dgst -sha256 -sign "$PRIVATE_KEY_FILE" | \
  openssl base64 -e | tr -d '\n' | tr '+/' '-_' | tr -d '=')

jwt="${unsigned}.${sig}"

# request installation token
resp=$(curl -s -X POST \
  -H "Authorization: Bearer ${jwt}" \
  -H "Accept: application/vnd.github+json" \
  "${GITHUB_API_URL%/}/app/installations/${INSTALLATION_ID}/access_tokens")

token=$(printf '%s' "$resp" | jq -r .token)

if [ -z "$token" ] || [ "$token" = "null" ]; then
  echo "Failed to obtain token from GitHub: $resp" >&2
  exit 1
fi

export RENOVATE_TOKEN="$token"
echo "Obtained installation token."

# exec renovate with passed args
exec /usr/local/sbin/renovate-entrypoint.sh "$@"
