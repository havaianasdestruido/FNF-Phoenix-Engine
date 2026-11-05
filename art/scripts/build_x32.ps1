# Port of build_x32.bat - keep in sync with build_x32.bat / build_x32.sh.
# Original batch assumed it is launched from art\scripts and does `cd ..`.
Set-Location ..
Write-Host "BUILDING GAME"
haxelib run lime build windows -32 -release -D 32bits -D HXCPP_M32 -D "HXCPP_COMPILE_THREADS=$env:NUMBER_OF_PROCESSORS"
Write-Host ""
Write-Host "done."
Read-Host "Press Enter to continue"
Get-Location
if (Get-Command explorer.exe -ErrorAction SilentlyContinue) {
    explorer.exe export\32bit\windows\bin
}
