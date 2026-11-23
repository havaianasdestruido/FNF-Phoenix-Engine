#!/usr/bin/env bash
# Command line launch options (backend.CommandLine, docs/CLI.md): the docopt-ng
# grammar, the legacy spellings, the "a bad argument must never stop the boot"
# rule, and the integration sites that need the whole game.
#
# The parser is isolated from source/import.hx's Flixel/OpenFL imports the way
# run-launch-state.sh isolates the -DFREEPLAY/-DMENU model. docopt-ng is found
# through `haxelib path` (what hmm.json and setup/* install) or through
# DOCOPT_NG_PATH; without it the parser spec still runs in its
# CLI_OPTIONS_ALLOWED-off form, which is exactly what the html5, Flash and AIR
# builds compile.
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/backend"
cp source/backend/CommandLine.hx source/backend/LaunchOptions.hx "$test_source/backend/"

docopt=""
if [ -n "${DOCOPT_NG_PATH:-}" ]; then
  docopt="${DOCOPT_NG_PATH}"
elif command -v haxelib >/dev/null 2>&1; then
  docopt=$(haxelib path docopt-ng 2>/dev/null | head -1 || true)
fi
# haxelib reports the library root; its sources live in src/ (see haxelib.json).
if [ -n "$docopt" ] && [ -d "$docopt/src/docopt" ]; then
  docopt="$docopt/src"
fi

if [ -n "$docopt" ] && [ -d "$docopt/docopt" ]; then
  # Desktop and mobile: docopt-ng parses the vector.
  "${HAXE:-haxe}" -cp "$docopt" -cp "$test_source" -cp tests/haxe -main CommandLineSpec -D CLI_OPTIONS_ALLOWED --interp
else
  echo "SKIP: docopt-ng sources not found (haxelib path docopt-ng, or DOCOPT_NG_PATH)"
fi

# Web, Flash and AIR: the feature flag is off, so the parser must stay inert
# without docopt on the classpath and still deliver a phoenix:// argument.
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main CommandLineSpec --interp

# Integration sites (Main, InitState, ClientPrefs, FrameProfiler, DeepLinks),
# the dependency manifests and the docs: the game cannot run here, so they are
# pinned by reading the sources. CommandLine.USAGE — the option table the docs
# are checked against — needs no docopt to be read.
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main CommandLineWiringSpec --interp
