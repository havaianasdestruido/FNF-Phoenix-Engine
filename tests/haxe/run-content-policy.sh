#!/usr/bin/env bash
# Guard release calls and the CI compact/full build selection, and the script
# modding level every CI/release build ships with.
set -euo pipefail
cd "$(dirname "$0")/../.."
workflow=.github/workflows/main.yml
project=project.hxp
fail() { echo "FAIL: $*" >&2; exit 1; }
for release in release.yml release-assets.yml mobile-release.yml; do
  grep -q 'uses: ./.github/workflows/main.yml' ".github/workflows/$release" || fail "$release must use the shared build"
  grep -q '^      fullAssets: true$' ".github/workflows/$release" || fail "$release must request full assets"
  # Releases must ask for Lua + Python explicitly instead of relying on a
  # default in project.hxp that a refactor can quietly change.
  grep -q '^      moddingLevel: "2"$' ".github/workflows/$release" || fail "$release must ship modding level 2"
done
# The compact mode must only filter build output, never delete source assets.
while IFS= read -r path; do
  [ -f "$path" ] || fail "missing built-in asset: $path"
done < tests/assets/builtin-assets.txt
[ "$(grep -c 'inputs.fullAssets }}.*true' "$workflow")" -eq 2 ] || fail 'both platforms must select compact/full mode'
[ "$(grep -c 'DNO_BUILTIN_CONTENT' "$workflow")" -eq 2 ] || fail 'both platforms must opt in to compact mode'

# ---------------------------------------------------------------------------
# Script modding (Lua + Python) is on by default for every native target.
# ---------------------------------------------------------------------------
# `lime build windows|linux|mac|android|ios` never sets Lime's optional `cpp`
# target flag, so gating the default on isCPP() silently produced builds with
# no Lua at all (docs/LUA_SCRIPT_DEBUGGING.md, step 0). The gate must stay
# target-type based, and the Lua bindings must use the same condition.
grep -q 'supportsScriptModding()' "$project" || fail 'project.hxp must keep the supportsScriptModding() gate'
[ "$(grep -c 'LUA_ALLOWED.apply(this, supportsScriptModding())' "$project")" -eq 1 ] \
  || fail 'LUA_ALLOWED must default to on for every native target'
[ "$(grep -c 'PYTHON_ALLOWED.apply(this, supportsScriptModding())' "$project")" -eq 1 ] \
  || fail 'PYTHON_ALLOWED must default to on for every native target'
grep -q 'if (supportsScriptModding() && LUA_ALLOWED.isEnabled(this))' "$project" \
  || fail 'hxluajit must be added whenever LUA_ALLOWED is (mobile included)'

# Both compile steps pass the level explicitly and both are verified.
[ "$(grep -c 'MODDING_LEVEL: \${{ inputs.moddingLevel' "$workflow")" -eq 3 ] \
  || fail 'both compile steps and the verification step must receive inputs.moddingLevel'
grep -qxF '      - name: Verify script modding (Lua + Python)' "$workflow" \
  || fail 'main.yml must verify the build actually contains Lua and Python'

# The default build scripts pass no flags at all, so they inherit the default.
for script in build/build-windows.bat build/build-linux.sh build/build-mac.sh \
              build/build-android.sh build/build-ios.sh; do
  [ -f "$script" ] || fail "missing default build script: $script"
  # Comments may mention the flag (they explain how to override it); only a
  # real command line counts.
  if grep -vE '^[[:space:]]*(rem |#|//|::)' "$script" | grep -q -- '-DMODDING_LEVEL'; then
    fail "$script must rely on the default level 2, not pass -DMODDING_LEVEL"
  fi
done

[ "$(cat setup/ci-weekList.txt)" = "$(printf 'tutorial\nweek1')" ] || fail 'compact week list must contain tutorial and week1 only'
echo 'content build policy passed'
