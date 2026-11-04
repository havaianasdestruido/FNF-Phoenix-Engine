#!/usr/bin/env bash
# Run the dependency-free URI parser spec without the engine-wide source/import.hx.
set -euo pipefail
cd "$(dirname "$0")/../.."
root="$PWD"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/backend/deeplink"
cp source/backend/deeplink/PhoenixURI.hx "$work/backend/deeplink/"
"${HAXE:-haxe}" -cp "$work" -cp "$root/tests/uri" --run TestPhoenixURI
