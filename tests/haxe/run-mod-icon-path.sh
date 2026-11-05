#!/usr/bin/env bash
# Isolate backend/Paths.hx from source/import.hx's Flixel/OpenFL imports and
# exercise the mods-menu icon path resolution (the `mods/mods/...` double-prefix
# bug that made every mod show the placeholder icon). The real Paths.hx and
# ModPathPolicy.hx are copied next to tiny dependency stubs and run in the Haxe
# interpreter, so no game haxelibs or native toolchain are needed.
#
# See tests/haxe/ModIconPathSpec.hx for the pinned invariants.
set -euo pipefail
cd "$(dirname "$0")/../.."
repo="$PWD"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# Dependency stubs (provide the Flixel/OpenFL/backend types Paths.hx touches).
cp -R "$repo/tests/haxe/stubs/mod-icon-path/." "$work/"

# Production modules under test.
mkdir -p "$work/backend"
cp "$repo/source/backend/Paths.hx" "$work/backend/Paths.hx"
cp "$repo/source/backend/ModPathPolicy.hx" "$work/backend/ModPathPolicy.hx"

# The spec builds a throwaway mods/ tree relative to CWD; run it inside the
# work directory so it never touches the real mods/ folder.
cd "$work"
"${HAXE:-haxe}" -cp "$work" -cp "$repo/tests/haxe" -main ModIconPathSpec --interp -D MODS_ALLOWED
