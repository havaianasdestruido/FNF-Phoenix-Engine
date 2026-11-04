# Port of run-update-checker-typecheck.sh - keep in sync with the .sh / .bat versions.
# Typecheck the threaded C++ update path using Lime's onUpdate signature.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "../..")
$haxe = if ($env:HAXE) { $env:HAXE } else { "haxe" }
$testSource = Join-Path ([IO.Path]::GetTempPath()) ("phoenix-update-checker-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $testSource -Force | Out-Null
try {
    New-Item -ItemType Directory -Path "$testSource/backend", "$testSource/lime/app" -Force | Out-Null
    Copy-Item "source/backend/PhoenixVersion.hx" "$testSource/backend/"
    Copy-Item "source/backend/PhoenixReleases.hx" "$testSource/backend/"
    Copy-Item "source/backend/UpdateChecker.hx" "$testSource/backend/"
    Set-Content -LiteralPath "$testSource/backend/ClientPrefs.hx" -Value @'
package backend;
class ClientPrefs { public static var enablePreReleaseUpdates:Bool = false; }
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
