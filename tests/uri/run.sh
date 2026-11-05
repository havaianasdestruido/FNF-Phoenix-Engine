#!/usr/bin/env bash
# Run the dependency-free URI parser spec without the engine-wide source/import.hx.
set -euo pipefail
cd "$(dirname "$0")/../.."
root="$PWD"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/backend/deeplink"
# Copy the dependency-free parser types (v2 added ParsedURI / URIKind).
for f in PhoenixURI ParsedURI URIKind; do
  cp "source/backend/deeplink/$f.hx" "$work/backend/deeplink/"
done
"${HAXE:-haxe}" -cp "$work" -cp "$root/tests/uri" --run TestPhoenixURI
