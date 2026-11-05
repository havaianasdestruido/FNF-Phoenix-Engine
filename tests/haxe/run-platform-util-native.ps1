# Port of run-platform-util-native.sh - keep in sync with the .sh / .bat versions.
# Typecheck the native bridge without the Flixel/Lime dependency tree.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "../..")
$haxe = if ($env:HAXE) { $env:HAXE } else { "haxe" }
$testSource = Join-Path ([IO.Path]::GetTempPath()) ("phoenix-platform-util-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $testSource -Force | Out-Null

function Invoke-Haxe {
    param([string[]]$HaxeArgs)
    & $haxe @HaxeArgs
    if ($LASTEXITCODE -ne 0) { throw "haxe failed ($LASTEXITCODE): $HaxeArgs" }
}

try {
    foreach ($dir in @("utils", "backend", "source/utils")) {
        New-Item -ItemType Directory -Path "$testSource/$dir" -Force | Out-Null
    }
    Copy-Item "source/utils/PlatformUtilNative.hx" "$testSource/utils/"
    Copy-Item "source/utils/build.xml" "$testSource/source/utils/"

    Set-Content -LiteralPath "$testSource/backend/WindowNative.hx" -Value @'
package backend;
class WindowNative {
  public static function messageBox(message:String, title:String, yesNo:Bool, error:Bool):Int return 7;
  public static function updateWallpaper():Dynamic return null;
  public static function detectWine():Bool return false;
  public static function getArch():String return '';
}
'@
    Set-Content -LiteralPath "$testSource/backend/FlxTransWindow.hx" -Value @'
package backend;
class FlxTransWindow {
  public static function getWindowsTransparent(res:Int):Int return res;
  public static function getWindowsbackward(res:Int):Int return res;
}
'@

    foreach ($platform in @("windows", "android", "linux", "mac")) {
        Invoke-Haxe @("-cp", $testSource, "-cp", "tests/haxe", "-D", $platform, "-main", "PlatformUtilNativeSpec", "--interp")
        if ($platform -in @("linux", "mac")) {
            # @:cppFileCode blocks replace rather than supplement one another.
            $output = "$testSource/generated/$platform/linux/obj"
            Invoke-Haxe @("-cp", $testSource, "-cp", "tests/haxe", "-D", $platform, "-D", "no-compilation", "-main", "PlatformUtilNativeSpec", "-cpp", $output)
            $generated = "$output/src/utils/PlatformUtilNative.cpp"
            if (-not (Select-String -LiteralPath $generated -Pattern '#include "phoenix_desktop_dialog.h"' -SimpleMatch -Quiet)) {
                throw "phoenix_desktop_dialog.h include missing for $platform"
            }
            if (-not (Select-String -LiteralPath $generated -Pattern '#include <sys/utsname.h>' -SimpleMatch -Quiet)) {
                throw "sys/utsname.h include missing for $platform"
            }
        } else {
            Invoke-Haxe @("-cp", $testSource, "-cp", "tests/haxe", "-D", $platform, "-main", "PlatformUtilNativeSpec", "-cpp", "$testSource/out-$platform", "--no-output")
        }
    }
} finally {
    Remove-Item -LiteralPath $testSource -Recurse -Force -ErrorAction SilentlyContinue
}
