#!/usr/bin/env bash
# Waits for Akamai App Platform for LKE to finish installing, then prints the
# portal URL and how to fetch the initial admin credentials.
#
# Uses the current kubectl context (merged by `tofu apply`) or $KUBECONFIG.
#
# Environment variables (optional):
#   APL_WAIT_TIMEOUT   - total seconds to wait (default 1500, i.e. 25 min)
#   APL_WAIT_INTERVAL  - seconds between polls (default 30)

set -euo pipefail

TIMEOUT="${APL_WAIT_TIMEOUT:-1500}"
INTERVAL="${APL_WAIT_INTERVAL:-30}"
OPERATOR_NS="apl-operator"
KNOWN_ISSUES_URL="https://techdocs.akamai.com/app-platform/docs/known-issues"

if ! command -v kubectl > /dev/null 2>&1; then
  echo "Error: 'kubectl' not found on PATH." >&2
  exit 1
fi

echo "Context: $(kubectl config current-context 2> /dev/null || echo unknown)"
echo "Waiting up to $((TIMEOUT / 60)) min for App Platform (polling every ${INTERVAL}s)..."

start=$(date +%s)
while :; do
  elapsed=$(($(date +%s) - start))

  # Any apl-* namespace means the operator has started; the welcome ConfigMap
  # and the Keycloak credentials secret mean the install has finished.
  apl_namespaces=$(kubectl get namespaces -o name 2> /dev/null | sed -n 's|^namespace/\(apl-.*\)|\1|p' | tr '\n' ' ')
  console_url=$(kubectl get configmap welcome -n "${OPERATOR_NS}" \
    -o jsonpath='{.data.consoleUrl}' 2> /dev/null || true)
  creds_ready=false
  if kubectl get secret platform-admin-initial-credentials -n keycloak > /dev/null 2>&1; then
    creds_ready=true
  fi

  if [ -n "${console_url}" ] && [ "${creds_ready}" = true ]; then
    echo
    echo "App Platform is installed (after ~$((elapsed / 60)) min)."
    echo
    echo "  Portal URL:  ${console_url}"
    echo
    echo "Next: print the initial admin credentials with"
    echo "  $(dirname "$0")/apl-credentials.sh"
    exit 0
  fi

  if [ "${elapsed}" -ge "${TIMEOUT}" ]; then
    break
  fi

  printf '  [%3ds] apl namespaces: %s| welcome ConfigMap: %s | keycloak secret: %s\n' \
    "${elapsed}" "${apl_namespaces:-none }" \
    "$([ -n "${console_url}" ] && echo yes || echo no)" "${creds_ready}"
  sleep "${INTERVAL}"
done

echo >&2
echo "Timed out after $((TIMEOUT / 60)) min waiting for App Platform." >&2
if [ -z "${apl_namespaces}" ]; then
  echo "No apl-* namespace exists. Was the cluster created with apl_enabled = true?" >&2
  echo "  tofu output apl_enabled" >&2
fi
echo "Pods that are not Running:" >&2
kubectl get pods -A --no-headers 2> /dev/null | grep -v -E 'Running|Completed' >&2 || echo "  (none)" >&2
echo >&2
echo "Pending pods with unbound PVCs usually mean the account Volume limit was hit." >&2
echo "See ${KNOWN_ISSUES_URL}" >&2
exit 1
