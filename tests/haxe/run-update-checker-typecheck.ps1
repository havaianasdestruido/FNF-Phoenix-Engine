# Port of run-update-checker-typecheck.sh - keep in sync with the .sh / .bat versions.
# Typecheck the threaded C++ update path using Lime's onUpdate signature.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "../..")
$haxe = if ($env:HAXE) { $env:HAXE } else { "haxe" }
$testSource = Join-Path ([IO.Path]::GetTempPath()) ("phoenix-update-checker-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $testSource -Force | Out-Null
try {
    New-Item -ItemType Directory -Path "$testSource/backend", "$testSource/lime/app", "$testSource/openfl" -Force | Out-Null
    Copy-Item "source/backend/PhoenixVersion.hx" "$testSource/backend/"
    Copy-Item "source/backend/PhoenixReleases.hx" "$testSource/backend/"
    Copy-Item "source/backend/UpdateChecker.hx" "$testSource/backend/"
    Copy-Item "source/backend/RuntimeFlags.hx" "$testSource/backend/"
    # RuntimeFlags (used by UpdateChecker since #198) reads flags.ini through Assets.
    Set-Content -LiteralPath "$testSource/openfl/Assets.hx" -Value @'
package openfl;
class Assets {
  public static function exists(id:String, ?type:Dynamic):Bool return false;
  public static function getText(id:String):String return "";
}
'@
    Set-Content -LiteralPath "$testSource/backend/ClientPrefs.hx" -Value @'
package backend;
class ClientPrefs { public static var enablePreReleaseUpdates:Bool = false; }
'@
    # UpdateChecker resolves the releases endpoint through RuntimeFlags; stub
    # the accessor it uses so the typecheck stays hermetic.
    Set-Content -LiteralPath "$testSource/backend/RuntimeFlags.hx" -Value @'
package backend;
class RuntimeFlags {
  public static function url(key:String, fallback:String):String { return fallback; }
}
'@
    Set-Content -LiteralPath "$testSource/lime/app/Application.hx" -Value @'
package lime.app;
// Lime Application.onUpdate is Event<Float->Void>.
class UpdateEvent {
  public function new() {}
  public function add(listener:Float->Void):Void {}
  public function remove(listener:Float->Void):Void {}
}
class Application {
  public static var current:Application;
  public var onUpdate:UpdateEvent;
  public var meta:Map<String, String>;
}
'@
    foreach ($platform in @("windows", "android")) {
        & $haxe -cp $testSource -cp tests/haxe -D lime -D $platform -main UpdateCheckerTypecheck -cpp "$testSource/out" --no-output
        if ($LASTEXITCODE -ne 0) { throw "haxe failed for $platform ($LASTEXITCODE)" }
    }
} finally {
    Remove-Item -LiteralPath $testSource -Recurse -Force -ErrorAction SilentlyContinue
}
