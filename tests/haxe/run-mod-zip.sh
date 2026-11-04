#!/usr/bin/env bash
# Isolate the dependency-free pieces of the `.zip` mod importer from
# source/import.hx's Flixel/OpenFL imports; the path policy, the central
# directory parser and the extractor are plain Haxe, so they can run in the
# interpreter without the game haxelibs.
set -euo pipefail
cd "$(dirname "$0")/../.."
repo="$PWD"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/backend" "$work/mobile/files"
cp source/backend/ModPathPolicy.hx "$work/backend/ModPathPolicy.hx"
cp source/mobile/files/ModZipInstaller.hx "$work/mobile/files/ModZipInstaller.hx"

# The spec creates and deletes relative scratch directories, so run it inside
# the throwaway work directory.
cd "$work"
"${HAXE:-haxe}" -cp "$work" -cp "$repo/tests/haxe" -main ModZipImportSpec --interp
