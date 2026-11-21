#!/usr/bin/env bash
# Exercise the XML definition parsers (characters, stages, weeks, dialogue)
# without renderer dependencies.
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
"${HAXE:-haxe}" -cp "$root/source" -cp "$root/tests/haxe" -main XmlDefinitionsSpec --interp
