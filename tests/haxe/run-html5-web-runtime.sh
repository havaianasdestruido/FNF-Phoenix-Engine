#!/usr/bin/env bash
# Regression checks for the HTML5 / WebGL runtime (timer loop, shared-library
# text/splash lookup, WebGL sampler parameters, and XHR headers).
set -euo pipefail
cd "$(dirname "$0")/../.."

bash tests/haxe/run-cool-util.sh
"${HAXE:-haxe}" -cp tests/haxe -main Html5WebRuntimeSpec --interp
