# Port of install-haxe-linux.sh - keep in sync with the .sh / .bat versions.
# Install the Haxe version used by Phoenix Engine CI without sudo or apt.
# This installs the *Linux x86_64* binaries, so it only works on Linux;
# under PowerShell 7 on Linux it does exactly what the .sh version does.
$ErrorActionPreference = "Stop"

$Version = "4.3.7"
$Revision = "95475451f930551a8cdd65c77fcae07513952903"
$SourceUrl = "https://github.com/ceramic-engine/haxe-binary.git"
$HaxeSha256 = "187a9bab4ffbd795d68c980fe7c1d96023fcf9c56862fccafd6c72b832cc1d98"
$HaxelibSha256 = "c4da75b350656b066fe3d8233a192aa5ee4f268e922fa31d3ccd88bcf16715a7"

# Platform guard: $IsLinux only exists in PowerShell 6+; Windows PowerShell
# 5.1 has no such variable and is never Linux.
$isLinuxHost = (Get-Variable -Name IsLinux -ValueOnly -ErrorAction SilentlyContinue) -eq $true
if (-not $isLinuxHost) {
    Write-Host "This installer was tested on Linux x86_64 only (it installs Linux binaries)." -ForegroundColor Red
    Write-Host "On Windows install Haxe from https://haxe.org/download instead." -ForegroundColor Red
    exit 1
}
if ((& uname -m) -ne "x86_64") {
    Write-Host "This installer was tested on Linux x86_64 only." -ForegroundColor Red
    exit 1
}
foreach ($tool in @("git", "mktemp", "install", "sha256sum")) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        Write-Host "Required command not found: $tool" -ForegroundColor Red
        exit 1
    }
}

$Root = Join-Path $HOME ".local/opt/phoenix-haxe/$Version"
$BinDir = Join-Path $HOME ".local/bin"
$LibDir = if ($env:HAXELIB_PATH) { $env:HAXELIB_PATH } else { Join-Path $HOME "haxelib" }
New-Item -ItemType Directory -Path (Split-Path -Parent $Root), $BinDir, $LibDir -Force | Out-Null
$LibDir = (Resolve-Path -LiteralPath $LibDir).Path

# Do not replace an unrelated haxe/haxelib command in the user's bin directory.
foreach ($tool in @("haxe", "haxelib")) {
    $target = Join-Path $BinDir $tool
    if ((Test-Path -LiteralPath $target) -and -not (Select-String -LiteralPath $target -Pattern '^# Phoenix Haxe launcher' -Quiet)) {
        Write-Host "Refusing to overwrite $target. Move that existing launcher aside first." -ForegroundColor Red
        exit 1
    }
}

if (-not (Test-Path -LiteralPath $Root)) {
    $work = (& mktemp -d (Join-Path (Split-Path -Parent $Root) ".install.XXXXXX")).Trim()
    try {
        $sourceDir = Join-Path $work "source"
        git init --quiet $sourceDir
        git -C $sourceDir remote add origin $SourceUrl
        git -C $sourceDir fetch --quiet --depth=1 --filter=blob:none origin $Revision
        if ((git -C $sourceDir rev-parse FETCH_HEAD) -ne $Revision) { throw "Unexpected FETCH_HEAD" }
        git -C $sourceDir sparse-checkout set linux-x86_64
        git -C $sourceDir checkout --quiet --detach $Revision
        "$HaxeSha256  $(Join-Path $sourceDir 'linux-x86_64/haxe/haxe-bin')", "$HaxelibSha256  $(Join-Path $sourceDir 'linux-x86_64/haxe/haxelib-bin')" |
            & sha256sum --check --status
        if ($LASTEXITCODE -ne 0) { throw "SHA-256 verification failed" }
        Move-Item -LiteralPath (Join-Path $sourceDir "linux-x86_64") -Destination $Root
    } finally {
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    }
}

"$HaxeSha256  $(Join-Path $Root 'haxe/haxe-bin')", "$HaxelibSha256  $(Join-Path $Root 'haxe/haxelib-bin')" | & sha256sum --check --status
if ($LASTEXITCODE -ne 0) { throw "SHA-256 verification failed" }

foreach ($tool in @("haxe", "haxelib")) {
    # Single-quoted here-string: the launcher is bash, so nothing in it may be
    # expanded by PowerShell. Only the tool name is substituted afterwards.
    $launcherTemplate = @'
#!/usr/bin/env bash
# Phoenix Haxe launcher (4.3.7)
set -euo pipefail
export HAXEPATH="$HOME/.local/opt/phoenix-haxe/4.3.7/haxe"
export HAXE_STD_PATH="$HAXEPATH/std"
export NEKOPATH="$HOME/.local/opt/phoenix-haxe/4.3.7/neko"
export PATH="$HOME/.local/bin:$NEKOPATH:$PATH"
export LD_LIBRARY_PATH="$NEKOPATH${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec "$HAXEPATH/__TOOL__-bin" "$@"
'@
    $launcher = $launcherTemplate.Replace("__TOOL__", $tool)
    $tempLauncher = Join-Path $BinDir ".$tool.tmp"
    Set-Content -LiteralPath $tempLauncher -Value $launcher -NoNewline
    & install -m 755 $tempLauncher (Join-Path $BinDir $tool)
    Remove-Item -LiteralPath $tempLauncher -Force
}

if ((& (Join-Path $BinDir "haxe") --version) -ne $Version) { throw "Installed haxe reports an unexpected version" }
& (Join-Path $BinDir "haxelib") setup $LibDir
Write-Host "Haxe $(& (Join-Path $BinDir 'haxe') --version); haxelib $(& (Join-Path $BinDir 'haxelib') version)"
Write-Host "Compiler: $(Join-Path $BinDir 'haxe')"
Write-Host "Library directory: $LibDir"
if (":$env:PATH:" -notlike "*:$BinDir`:*") {
    Write-Host "Run in each new shell: export PATH=`"$BinDir`:`$PATH`""
}
