#!/usr/bin/env bash
# §16 accessibility helpers (colorblind palettes, luminance contrast, ASCII lane
# glyphs, high-contrast floor, visual beat indicator) + §21.4/§22.7 Option rows.
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/backend"
cp source/backend/Accessibility.hx "$test_source/backend/Accessibility.hx"
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main AccessibilitySpec --interp
