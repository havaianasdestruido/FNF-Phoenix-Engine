# Port of test_x64.bat - keep in sync with test_x64.bat / test_x64.sh.
Set-Location ..
Write-Host "BUILDING GAME"
haxelib run lime test windows -D "HXCPP_COMPILE_THREADS=$env:NUMBER_OF_PROCESSORS"
Write-Host ""
Write-Host "done."
Read-Host "Press Enter to continue"
