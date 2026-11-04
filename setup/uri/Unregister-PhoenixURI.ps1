param([string]$Executable = (Join-Path $PSScriptRoot '..\FNF-Phoenix-Engine.exe'))
$ErrorActionPreference = 'Stop'
$exe = [IO.Path]::GetFullPath($Executable)
$key = 'HKCU:\Software\Classes\phoenix'
if (Test-Path "$key\shell\open\command") {
    $expected = '"' + $exe + '" "%1"'
    if ((Get-Item "$key\shell\open\command").GetValue('') -ne $expected) {
        throw 'Another installation owns phoenix://; refusing to remove its registration.'
    }
    Remove-Item -Path $key -Recurse -Force
    Write-Host 'Removed Phoenix URI registration.'
}
