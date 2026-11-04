#!/usr/bin/env bash
# Exercise backend/SettingsBackupCodec.hx in the Haxe interpreter. The codec is
# deliberately Flixel-free (the file dialogs and ClientPrefs live in
# backend/SettingsBackup.hx), so no game haxelibs or stubs are needed.
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/backend"
cp source/backend/SettingsBackupCodec.hx "$test_source/backend/SettingsBackupCodec.hx"
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main SettingsBackupCodecSpec --interp
