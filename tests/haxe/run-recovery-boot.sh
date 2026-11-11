#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/backend" "$tmp/storage"
cp source/backend/RecoveryBoot.hx "$tmp/backend/RecoveryBoot.hx"
RECOVERY_TEST_DIR="$tmp/storage" "${HAXE:-haxe}" -cp "$tmp" -cp tests/haxe/stubs/recovery -cp tests/haxe -main RecoveryBootSpec --interp
