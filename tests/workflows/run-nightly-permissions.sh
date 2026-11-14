#!/usr/bin/env bash
# Artifact lookup and PR comments must work even when the repository's default
# GITHUB_TOKEN permissions are read-only.
set -euo pipefail
cd "$(dirname "$0")/../.."
workflow=.github/workflows/nightly.yml
permissions=$(awk '/^permissions:$/ { in_permissions=1; next } in_permissions && /^[^ #]/ { exit } in_permissions { print }' "$workflow")
grep -Eq '^  actions: read[[:space:]]*$' <<< "$permissions" || { echo 'nightly comment workflow needs actions: read' >&2; exit 1; }
grep -Eq '^  issues: write[[:space:]]*$' <<< "$permissions" || { echo 'nightly comment workflow needs issues: write' >&2; exit 1; }
echo 'nightly comment permissions passed'
