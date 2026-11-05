# Port of test_x64-debug.bat - keep in sync with test_x64-debug.bat / .sh.
Set-Location ..
Write-Host "BUILDING GAME"
haxelib run lime test windows -debug -D "HXCPP_COMPILE_THREADS=$env:NUMBER_OF_PROCESSORS"
Write-Host ""
Write-Host "done."
Read-Host "Press Enter to continue"
