# Port of run-project-build-cache.sh; keep the shell variants in sync.
$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot '../..')
$work = Join-Path ([IO.Path]::GetTempPath()) ("phoenix-project-cache-" + [Guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path $work -Force | Out-Null
    Copy-Item 'project.hxp' (Join-Path $work 'Project.hx')
    $haxe = if ($env:HAXE) { $env:HAXE } else { 'haxe' }
    & $haxe -lib lime -lib hxp -cp $work -cp tests/haxe -main ProjectBuildCacheSpec --interp
    if ($LASTEXITCODE -ne 0) { throw "ProjectBuildCacheSpec failed ($LASTEXITCODE)" }
} finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    Pop-Location
}
