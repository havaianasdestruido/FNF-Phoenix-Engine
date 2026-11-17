# Port of run-freeplay-filter.sh - keep in sync with the .sh / .bat versions.
# The Freeplay filter (sort by name/mod/accuracy/unplayed, show one mod, stars,
# random song) in the Haxe interpreter, without any game haxelibs: only
# backend/FreeplayFilter.hx is needed, it imports nothing but the standard
# library.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "../..")
$haxe = if ($env:HAXE) { $env:HAXE } else { "haxe" }
$testSource = Join-Path ([IO.Path]::GetTempPath()) ("phoenix-freeplay-filter-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path "$testSource/logic/backend" -Force | Out-Null
try {
    Copy-Item "source/backend/FreeplayFilter.hx" "$testSource/logic/backend/FreeplayFilter.hx"
    & $haxe -cp "$testSource/logic" -cp tests/haxe -main FreeplayFilterSpec --interp
    if ($LASTEXITCODE -ne 0) { throw "FreeplayFilterSpec failed ($LASTEXITCODE)" }
    # The same module typechecked for C++, a static target (nothing is generated).
    & $haxe -cp "$testSource/logic" -cp tests/haxe -main FreeplayFilterSpec -cpp "$testSource/cpp" --no-output
    if ($LASTEXITCODE -ne 0) { throw "FreeplayFilterSpec does not typecheck for C++ ($LASTEXITCODE)" }
}
finally {
    Remove-Item $testSource -Recurse -Force -ErrorAction SilentlyContinue
}
