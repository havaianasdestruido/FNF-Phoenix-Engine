#!/usr/bin/env bash
# The mod-icon regression and asset-cache regression both exercise production
# Paths.hx. Share the maintained Flixel/OpenFL test shell rather than keeping a
# second, stale set of Paths dependencies.
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
bash "$root/tests/haxe/run-asset-cache.sh" mod-icon
