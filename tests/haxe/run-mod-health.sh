#!/usr/bin/env bash
# The per-mod "why did it break?" report (§19).
#
# 1. `backend/ModHealth.hx` itself: what is recorded per mod, the severity order,
#    the menu summary and the Mod Info block, all Flixel-free.
# 2. The `Mods.getPack()` half: a manifest that cannot be parsed is reported, not
#    only traced. It runs against small stubs (`tests/haxe/stubs/mod-pack`, incl.
#    a minimal `tjson`) inside a throwaway working directory, because the spec
#    creates and deletes a relative `mods/` tree.
set -euo pipefail
cd "$(dirname "$0")/../.."
repo="$PWD"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/backend" "$work/states/helpers"
cp source/backend/ModHealth.hx "$work/backend/ModHealth.hx"
cp source/backend/ModPathPolicy.hx "$work/backend/ModPathPolicy.hx"
cp source/states/helpers/ModInfoFlow.hx "$work/states/helpers/ModInfoFlow.hx"

"${HAXE:-haxe}" -cp "$work" -cp "$repo/tests/haxe" -main ModHealthSpec --interp

# The manifest half reads the real backend/Mods.hx. Its stubs live in a folder of
# their own so they cannot shadow the real modules of the run above.
mkdir -p "$work/pack/backend"
cp source/backend/Mods.hx source/backend/ModsList.hx "$work/pack/backend/"
# The real ModHealth: the spec reads the reason it recorded, it is not stubbed.
cp source/backend/ModHealth.hx "$work/pack/backend/ModHealth.hx"
# Mods.ignoreModFolders mirrors the importer's reserved list.
cp source/backend/ModPathPolicy.hx "$work/pack/backend/ModPathPolicy.hx"

# backend/Mods.hx leans on the game's global import.hx for `using StringTools` and
# the sys file API; the isolation above has to provide the same three lines.
cat > "$work/pack/import.hx" <<'HAXE'
#if !macro
import sys.FileSystem;
import sys.io.File;
using StringTools;
#end
HAXE

cd "$work/pack"
"${HAXE:-haxe}" -cp "$work/pack" -cp "$repo/tests/haxe/stubs/mod-pack" -cp "$repo/tests/haxe" \
  -main ModPackHealthSpec -D MODS_ALLOWED --interp
