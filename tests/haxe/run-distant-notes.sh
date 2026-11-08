#!/usr/bin/env bash
# Typecheck the real shader and exercise its uniforms without the game libraries.
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/shaders"
cp "$root/source/shaders/DistantNoteShader.hx" "$test_source/shaders/"
haxe -cp "$root/tests/haxe/stubs/distant" -cp "$root/tests/haxe" -cp "$test_source" -main DistantNoteShaderSpec --interp
