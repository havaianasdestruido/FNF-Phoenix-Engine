#!/usr/bin/env bash
# Covers the bottom-right commit watermark's two data sources: the "N commits
# behind" rules (CommitFreshnessSpec) and the git commit stamp the watermark
# prints below it (CommitStampSpec, compiled without and with -Dcommit).
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/backend"
cp source/backend/CommitFreshness.hx source/backend/HaxeCommit.hx "$test_source/backend/"
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main CommitFreshnessSpec --interp

# The commit id only exists when the build is stamped, so exercise both sides
# of `#if commit` for real instead of trusting the macro by inspection.
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main CommitStampSpec --interp
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main CommitStampSpec -D commit --interp
