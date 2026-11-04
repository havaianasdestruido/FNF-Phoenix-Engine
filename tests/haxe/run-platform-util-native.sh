#!/usr/bin/env bash
# Typecheck the native bridge without the Flixel/Lime dependency tree.
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/utils" "$test_source/backend" "$test_source/source/utils"
cp source/utils/PlatformUtilNative.hx "$test_source/utils/"
cp source/utils/build.xml "$test_source/source/utils/"
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
  if [[ "$platform" == linux || "$platform" == mac ]]; then
    # @:cppFileCode blocks replace rather than supplement one another. Generate
    # the translation unit to ensure the dialog and uname declarations coexist.
    output="$test_source/generated/$platform/linux/obj"
    "${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -D "$platform" -D no-compilation -main PlatformUtilNativeSpec -cpp "$output"
    grep -Fq '#include "phoenix_desktop_dialog.h"' "$output/src/utils/PlatformUtilNative.cpp"
    grep -Fq '#include <sys/utsname.h>' "$output/src/utils/PlatformUtilNative.cpp"
  else
    "${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -D "$platform" -main PlatformUtilNativeSpec -cpp "$test_source/out-$platform" --no-output
  fi
done
