#!/usr/bin/env bash
# Clones the App Platform `values` repo into ./.values (git-ignored), or
# pulls if it is already there.
#
# By default the clone URL comes from the built-in Git server, via the
# gitCloneCmd field of the apl-secrets/apl-git-config secret. After the BYO
# Git switch, set VALUES_REPO_URL to the external repo instead.
#
# Environment variables (optional):
#   VALUES_DIR       - clone target (default ./.values)
#   VALUES_REPO_URL  - clone this URL instead of the built-in Git server

set -euo pipefail

VALUES_DIR="${VALUES_DIR:-./.values}"

if [ -d "${VALUES_DIR}/.git" ]; then
  echo "${VALUES_DIR} already exists; pulling."
  git -C "${VALUES_DIR}" pull --ff-only
  exit 0
fi

if [ -e "${VALUES_DIR}" ]; then
  echo "Error: ${VALUES_DIR} exists but is not a git checkout. Remove it first." >&2
  exit 1
fi

url="${VALUES_REPO_URL:-}"
if [ -z "${url}" ]; then
  if ! command -v kubectl > /dev/null 2>&1; then
    echo "Error: 'kubectl' not found on PATH (needed unless VALUES_REPO_URL is set)." >&2
    exit 1
  fi
  clone_cmd=$(kubectl get secret -n apl-secrets apl-git-config \
    -o jsonpath='{.data.gitCloneCmd}' | base64 --decode)
  if [ -z "${clone_cmd}" ]; then
    echo "Error: apl-secrets/apl-git-config has no gitCloneCmd. Is App Platform installed?" >&2
    exit 1
  fi
  # Extract the URL rather than eval'ing a command string from the cluster.
  url=$(printf '%s\n' "${clone_cmd}" | grep -oE 'https?://[^[:space:]]+' | head -n 1 || true)
  if [ -z "${url}" ]; then
    echo "Error: could not find an http(s) URL in gitCloneCmd. Run it by hand:" >&2
    echo "  kubectl get secret -n apl-secrets apl-git-config -ojsonpath='{.data.gitCloneCmd}' | base64 --decode" >&2
    exit 1
  fi
fi

# The built-in server URL embeds credentials; avoid echoing them.
echo "Cloning values repo (host: $(printf '%s' "${url}" | sed -E 's|^https?://([^@/]*@)?([^/]+).*|\2|')) into ${VALUES_DIR}"
git clone "${url}" "${VALUES_DIR}"
