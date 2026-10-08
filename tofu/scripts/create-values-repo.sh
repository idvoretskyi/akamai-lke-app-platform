#!/usr/bin/env bash
# Creates the empty, private GitHub repo used as the BYO Git target for the
# App Platform values repo. Does NOT create or store any token.
#
# Environment variables (optional):
#   VALUES_REPO_OWNER - GitHub owner (default idvoretskyi)
#   VALUES_REPO_NAME  - repo name (default: `tofu output -raw values_repo_name`)

set -euo pipefail

OWNER="${VALUES_REPO_OWNER:-idvoretskyi}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if ! command -v gh > /dev/null 2>&1; then
  echo "Error: 'gh' not found on PATH." >&2
  exit 1
fi

NAME="${VALUES_REPO_NAME:-}"
if [ -z "${NAME}" ]; then
  NAME=$(tofu -chdir="${SCRIPT_DIR}/.." output -raw values_repo_name 2> /dev/null || true)
fi
NAME="${NAME:-akamai-lke-app-platform-values}"
REPO="${OWNER}/${NAME}"

if gh repo view "${REPO}" > /dev/null 2>&1; then
  # An empty repo has no commits; the API answers 409 and gh exits non-zero.
  if gh api "repos/${REPO}/commits?per_page=1" > /dev/null 2>&1; then
    echo "Error: ${REPO} already exists and is not empty." >&2
    echo "The BYO Git wizard needs an EMPTY repo. Pick another VALUES_REPO_NAME." >&2
    exit 1
  fi
  echo "${REPO} already exists and is empty; reusing it."
else
  gh repo create "${REPO}" --private \
    --description "APL values repo for akamai-lke-app-platform"
fi

cat << NEXT

Next steps (manual, not scriptable):

  1. Create a fine-grained personal access token scoped to ONLY ${REPO}
     with "Contents: Read and write":
       https://github.com/settings/personal-access-tokens/new
  2. In the App Platform portal: Platform view > Settings > Git.
     Repository URL: https://github.com/${REPO}.git
     Username: ${OWNER}, Password: the token from step 1.
     The wizard pushes the existing values history to the new repo.
  3. Then clone the new repo instead of the built-in one:
       VALUES_REPO_URL=https://github.com/${REPO}.git ${SCRIPT_DIR}/apl-values-clone.sh

Keep the token out of this repo, tfvars and shell history.
NEXT
