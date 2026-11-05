#!/usr/bin/env bash
# Exercise backend/CrashBundleWriter.hx in the Haxe interpreter. The writer is
# deliberately Flixel-free (the crash-text/mod/prefs/screenshot collection lives
# in backend/CrashBundle.hx), so no game haxelibs or stubs are needed — only the
# shared ModPathPolicy it reuses for entry-name safety.
set -euo pipefail
cd "$(dirname "$0")/../.."
repo="$PWD"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/backend"
cp source/backend/CrashBundleWriter.hx "$work/backend/CrashBundleWriter.hx"
cp source/backend/ModPathPolicy.hx "$work/backend/ModPathPolicy.hx"

# The spec creates and deletes relative scratch directories, so run it inside
# the throwaway work directory.
cd "$work"
"${HAXE:-haxe}" -cp "$work" -cp "$repo/tests/haxe" -main CrashBundleSpec --interp
