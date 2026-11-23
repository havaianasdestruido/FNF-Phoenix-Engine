#!/usr/bin/env bash
# Exercise psychlua/StateScripts.hx in the Haxe interpreter with the
# MODS_ALLOWED and HSCRIPT_ALLOWED feature defines on. The spec builds its own
# fixture tree under the working directory, which is discarded afterwards.
# Run with: bash tests/haxe/run-state-scripts.sh
set -euo pipefail
repo_root=$(cd "$(dirname "$0")/../.." && pwd)
cd "$repo_root"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/psychlua" "$work/backend" "$work/lime/utils" "$work/openfl/utils"
cp source/psychlua/StateScripts.hx "$work/psychlua/StateScripts.hx"
cp tests/haxe/stubs/state-scripts/import.hx "$work/import.hx"
cp tests/haxe/stubs/state-scripts/backend/Paths.hx "$work/backend/Paths.hx"
cp tests/haxe/stubs/state-scripts/backend/RuntimeFlags.hx "$work/backend/RuntimeFlags.hx"
cp tests/haxe/stubs/state-scripts/backend/Mods.hx "$work/backend/Mods.hx"
cp tests/haxe/stubs/state-scripts/lime/utils/Assets.hx "$work/lime/utils/Assets.hx"
cp tests/haxe/stubs/state-scripts/openfl/utils/Assets.hx "$work/openfl/utils/Assets.hx"
cp tests/haxe/stubs/state-scripts/psychlua/HaxeScript.hx "$work/psychlua/HaxeScript.hx"
mkdir -p "$work/flixel/addons/transition" "$work/states/substates"
cp tests/haxe/stubs/state-scripts/flixel/FlxG.hx "$work/flixel/FlxG.hx"
cp tests/haxe/stubs/state-scripts/flixel/addons/transition/FlxTransitionableState.hx "$work/flixel/addons/transition/FlxTransitionableState.hx"
cp tests/haxe/stubs/state-scripts/states/ModState.hx "$work/states/ModState.hx"
cp tests/haxe/stubs/state-scripts/states/substates/ModSubState.hx "$work/states/substates/ModSubState.hx"
mkdir -p "$work/states"
cp tests/haxe/stubs/state-scripts/fixtures/states/NestedFixture.hx "$work/states/NestedFixture.hx"
cd "$work"
"${HAXE:-haxe}" -cp "$work" -cp "$repo_root/tests/haxe" -D MODS_ALLOWED -D HSCRIPT_ALLOWED -main StateScriptsSpec --interp
