#!/usr/bin/env bash
# Prints the initial App Platform admin username and password from the
# Keycloak secret. Nothing is written to disk.

set -euo pipefail

if ! command -v kubectl > /dev/null 2>&1; then
  echo "Error: 'kubectl' not found on PATH." >&2
  exit 1
fi

SECRET="platform-admin-initial-credentials"
NS="keycloak"

if ! kubectl get secret "${SECRET}" -n "${NS}" > /dev/null 2>&1; then
  echo "Error: secret ${NS}/${SECRET} not found. Run apl-wait.sh first." >&2
  exit 1
fi

username=$(kubectl get secret "${SECRET}" -n "${NS}" -o jsonpath='{.data.username}' | base64 -d)
password=$(kubectl get secret "${SECRET}" -n "${NS}" -o jsonpath='{.data.password}' | base64 -d)

console_url=$(kubectl get configmap welcome -n apl-operator \
  -o jsonpath='{.data.consoleUrl}' 2> /dev/null || true)

echo "Portal:   ${console_url:-<run apl-wait.sh>}"
echo "Username: ${username}"
echo "Password: ${password}"
echo
echo "Notes:"
echo "  * The first login forces a password change. This secret keeps the"
echo "    initial password only."
echo "  * The Object Storage wizard opens on first login. Have a Linode personal"
echo "    access token with Object Storage read/write ready; App Platform uses it"
echo "    once to create buckets and does not store it."
