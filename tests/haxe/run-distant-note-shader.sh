#!/usr/bin/env bash
# Typecheck the real shader/wrapper against pinned Flixel/OpenFL/Lime sources.
# Skips when only the compiler is installed; no generated files enter the repo.
set -euo pipefail
cd "$(dirname "$0")/../.."
find_lib() {
  local name="$1" override="$2" pkg="$3" dir=""
  if [ -n "${!override:-}" ]; then
    dir="${!override}"
    if [ -d "$dir/src/$pkg" ]; then printf '%s' "$dir/src"; return 0; fi
    if [ -d "$dir/$pkg" ]; then printf '%s' "$dir"; return 0; fi
    return 1
  fi
  command -v haxelib >/dev/null 2>&1 || return 1
  while IFS= read -r dir; do
    [ -z "$dir" ] && continue
    case "$dir" in -*) continue ;; esac
    if [ -d "$dir/src/$pkg" ]; then printf '%s' "$dir/src"; return 0; fi
    if [ -d "$dir/$pkg" ]; then printf '%s' "$dir"; return 0; fi
  done < <(haxelib path "$name" 2>/dev/null || true)
  return 1
}
flixel=$(find_lib flixel FLIXEL_PATH flixel || true)
openfl=$(find_lib openfl OPENFL_PATH openfl || true)
lime=$(find_lib lime LIME_PATH lime || true)
if [ -z "$flixel" ] || [ -z "$openfl" ] || [ -z "$lime" ]; then
  echo 'SKIP: flixel/openfl/lime sources not found'
  exit 0
fi
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/shaders" "$test_source/backend"
cp source/shaders/DistantNoteShader.hx "$test_source/shaders/"
cp source/backend/{FlxFixedShader,RuntimeFlags,PhoenixVersion}.hx "$test_source/backend/"
cat > "$test_source/TypecheckMain.hx" <<'HAXE'
class TypecheckMain {
  static function main():Void {
    final effect = new shaders.DistantNoteShader();
    effect.downscroll = true;
    if (!effect.shader.uDownscroll.value[0]) throw 'uniform was not set';
  }
}
HAXE
common="-cp $test_source -cp $flixel -cp $openfl -cp $lime -D lime=8.1.2 -D openfl=9.3.0 -D SHADERS_ALLOWED"
# shellcheck disable=SC2086
"${HAXE:-haxe}" $common -D html5 -D lime_html5 -D lime_webgl -D openfl_html5 -D webgl -D canvas -D dom \
  -main TypecheckMain -js "$test_source/shader.js" --no-output
# shellcheck disable=SC2086
"${HAXE:-haxe}" $common -D linux -D desktop -D native -D lime_native -D lime_opengl \
  -main TypecheckMain -cpp "$test_source/cpp" --no-output
echo 'DistantNoteShader html5/native typecheck: PASS'
