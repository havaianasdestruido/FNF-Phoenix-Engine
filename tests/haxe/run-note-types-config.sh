#!/usr/bin/env bash
# Exercise backend/NoteTypesConfig.hx in the Haxe interpreter. The parser reads
# through backend.Paths and the sys filesystem, so the spec runs with the
# fixture tree as the working directory. Run with:
#   bash tests/haxe/run-note-types-config.sh
set -euo pipefail
repo_root=$(cd "$(dirname "$0")/../.." && pwd)
cd "$repo_root"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/backend" "$work/objects" "$work/custom_notetypes"
cp source/backend/NoteTypesConfig.hx "$work/backend/NoteTypesConfig.hx"
cp tests/haxe/stubs/note-types/import.hx "$work/import.hx"
cp tests/haxe/stubs/note-types/backend/CoolUtil.hx "$work/backend/CoolUtil.hx"
cp tests/haxe/stubs/note-types/backend/Paths.hx "$work/backend/Paths.hx"
cp tests/haxe/stubs/note-types/objects/Note.hx "$work/objects/Note.hx"
cp tests/haxe/fixtures/note-types/custom_notetypes/*.txt "$work/custom_notetypes/"
cd "$work"
"${HAXE:-haxe}" -cp "$work" -cp "$repo_root/tests/haxe" -main NoteTypesConfigSpec --interp
