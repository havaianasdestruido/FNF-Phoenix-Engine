#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd "$(dirname "$0")/../.." && pwd)
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/backend" "$test_source/work"
cp "$repo_root/source/backend/LogUtils.hx" "$test_source/backend/"
cd "$test_source/work"
"${HAXE:-haxe}" -cp "$test_source" -cp "$repo_root/tests/haxe" -main LogUtilsSpec --interp
