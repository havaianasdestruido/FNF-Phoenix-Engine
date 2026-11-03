#!/usr/bin/env bash
# Typecheck the native bridge without the Flixel/Lime dependency tree.
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/utils" "$test_source/backend"
cp source/utils/PlatformUtilNative.hx "$test_source/utils/"
cat > "$test_source/backend/WindowNative.hx" <<'HAXE'
package backend;
class WindowNative {
  public static function messageBox(message:String, title:String, yesNo:Bool, error:Bool):Int return 7;
  public static function updateWallpaper():Dynamic return null;
  public static function detectWine():Bool return false;
  public static function getArch():String return '';
}
HAXE
cat > "$test_source/backend/FlxTransWindow.hx" <<'HAXE'
package backend;
class FlxTransWindow {
  public static function getWindowsTransparent(res:Int):Int return res;
  public static function getWindowsbackward(res:Int):Int return res;
}
HAXE
for platform in windows android linux mac; do
  "${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -D "$platform" -main PlatformUtilNativeSpec --interp
  # Exercise the #if cpp metadata too, without invoking hxcpp or producing binaries.
  "${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -D "$platform" -main PlatformUtilNativeSpec -cpp "$test_source/out" --no-output
done
