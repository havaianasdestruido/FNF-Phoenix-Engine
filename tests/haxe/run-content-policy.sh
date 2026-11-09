#!/usr/bin/env bash
# Guard release calls and the CI compact/full build selection.
set -euo pipefail
cd "$(dirname "$0")/../.."
workflow=.github/workflows/main.yml
fail() { echo "FAIL: $*" >&2; exit 1; }
for release in release.yml release-assets.yml mobile-release.yml; do
  grep -q 'uses: ./.github/workflows/main.yml' ".github/workflows/$release" || fail "$release must use the shared build"
  grep -q '^      fullAssets: true$' ".github/workflows/$release" || fail "$release must request full assets"
done
# The compact mode must only filter build output, never delete source assets.
while IFS= read -r path; do
  [ -f "$path" ] || fail "missing built-in asset: $path"
done < tests/assets/builtin-assets.txt
[ "$(grep -c 'inputs.fullAssets }}.*true' "$workflow")" -eq 2 ] || fail 'both platforms must select compact/full mode'
[ "$(grep -c 'DNO_BUILTIN_CONTENT' "$workflow")" -eq 2 ] || fail 'both platforms must opt in to compact mode'
[ "$(cat setup/ci-weekList.txt)" = "$(printf 'tutorial\nweek1')" ] || fail 'compact week list must contain tutorial and week1 only'
echo 'content build policy passed'
