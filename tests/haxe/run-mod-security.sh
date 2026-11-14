#!/usr/bin/env bash
# ModSecurity policy and the per-mod switch that Mod Info in the Mods menu
# drives: the source scanner contract, the player's choice against pack.json,
# the modSecurity.txt store and the panel's confirmation and text rules.
#
# backend/ModSecurity.hx, backend/ScriptSecurityScanner.hx and
# states/helpers/ModInfoFlow.hx have no Flixel/OpenFL dependencies, so every
# spec runs in the Haxe interpreter without game haxelibs.
set -euo pipefail
cd "$(dirname "$0")/../.."
repo="$PWD"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/backend" "$work/states/helpers"
cp source/backend/ModSecurity.hx "$work/backend/ModSecurity.hx"
cp source/backend/ScriptSecurityScanner.hx "$work/backend/ScriptSecurityScanner.hx"
cp source/states/helpers/ModInfoFlow.hx "$work/states/helpers/ModInfoFlow.hx"

# 1. Dependency-free contract. Without MODS_ALLOWED nothing is read from or
#    written to disk, which is also how run-layout and run-lua-discovery use it.
"${HAXE:-haxe}" -cp "$work" -cp tests/haxe -main ModSecuritySpec --interp

# 2. Logic of the Mod Info panel: switching ModSecurity off needs an explicit
#    "Yes" and can never happen by pressing the same button twice, and a mod
#    cannot write into the panel through its name or its pack.json.
"${HAXE:-haxe}" -cp "$work" -cp tests/haxe -main ModInfoFlowSpec --interp

# 3. The MODS_ALLOWED build reads pack.json through backend.Mods (stubbed) and
#    keeps the player's choices in modSecurity.txt, relative to the working
#    directory: run inside the throwaway folder so the repo is never touched.
cd "$work"
"${HAXE:-haxe}" -cp "$work" -cp "$repo/tests/haxe/stubs/mod-security" -cp "$repo/tests/haxe" \
  -main ModSecurityPlayerSpec -D MODS_ALLOWED --interp
