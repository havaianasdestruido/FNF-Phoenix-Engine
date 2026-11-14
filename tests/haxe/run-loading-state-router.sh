#!/usr/bin/env bash
# State routing/reset semantics, with and without NO_PRELOAD_ALL. No haxelibs needed.
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cp -R "$root/tests/haxe/stubs/loading-router/." "$work/"
cp "$root/source/states/LoadingStateRouter.hx" "$work/states/"
for mode in normal no-preload; do
  flags=()
  if [ "$mode" = no-preload ]; then flags+=(-D NO_PRELOAD_ALL); fi
  "${HAXE:-haxe}" -cp "$work" -cp "$root/tests/haxe" "${flags[@]}" -main LoadingStateRouterSpec --interp
  "${HAXE:-haxe}" -cp "$work" -cp "$root/tests/haxe" "${flags[@]}" -main LoadingStateRouterSpec -js "$work/router.js"
  node "$work/router.js"
done
