# Port of build_x64-debug.bat - keep in sync with build_x64-debug.bat / .sh.
Set-Location ..
Write-Host "BUILDING GAME"
haxelib run lime build windows -debug -D "HXCPP_COMPILE_THREADS=$env:NUMBER_OF_PROCESSORS"
Write-Host ""
Write-Host "done."
Read-Host "Press Enter to continue"
Get-Location
if (Get-Command explorer.exe -ErrorAction SilentlyContinue) {
    explorer.exe export\debug\windows\bin
}
