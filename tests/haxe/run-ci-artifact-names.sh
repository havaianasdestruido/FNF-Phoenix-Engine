#!/usr/bin/env bash
# Guard CI artifact naming and full-modding defaults across all workflows.
# Keep the .sh / .bat / .ps1 launchers in sync.
set -euo pipefail
cd "$(dirname "$0")/../.."
"${HAXE:-haxe}" -cp tests/haxe -main CIArtifactNamesSpec --interp
