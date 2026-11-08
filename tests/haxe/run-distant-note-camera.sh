#!/usr/bin/env bash
# Test the note-camera helper against small Flixel/shader stubs. The real GLSL
# wrapper is additionally typechecked by run-distant-note-typecheck.sh.
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
cp -r tests/haxe/stubs/distant-notes/. "$test_source/"
mkdir -p "$test_source/play/helpers"
cp source/play/helpers/PlayStateDistantNotes.hx "$test_source/play/helpers/"
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -D SHADERS_ALLOWED -main DistantNotesSpec --interp
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main DistantNotesFallbackSpec --interp
