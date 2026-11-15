#!/usr/bin/env bash
# Clang PCH files record system-header mtimes. GitHub Android runners can have
# different NDK header mtimes even with the same NDK version, so a restored PCH
# may be rejected while the content-addressed object cache remains valid.
set -euo pipefail
cache="${HXCPP_COMPILE_CACHE:?HXCPP_COMPILE_CACHE must name the hxcpp cache}"
[ -d "$cache" ] || exit 0
# Only remove PCH files inside hxcpp's pch<hash> directories; keep all objects.
find "$cache" -type f -path '*/pch*/*' \( -name '*.pch' -o -name '*.gch' \) -delete
