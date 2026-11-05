# Port of debugThingyMajiggy.bat - keep in sync with the .bat / .sh versions.
# The batch file's `cd ...` is the old cmd idiom for "up two levels"; the
# PowerShell equivalent is explicit.
Set-Location ../..
Write-Host "Are you sure you want to Debug by terminal?"
Write-Host ""
Write-Host "Press any key if you want to continue. If not, close this."
Start-Sleep -Seconds 10
Write-Host ""
Write-Host "Opening Debug Terminal..."
Write-Host "------------------------------"
if (Test-Path -LiteralPath ".\FNF-Phoenix-Engine.exe") {
    & .\FNF-Phoenix-Engine.exe
} elseif (Test-Path -LiteralPath ".\FNF-Phoenix-Engine") {
    & ./FNF-Phoenix-Engine
} else {
    Write-Host "FNF-Phoenix-Engine executable not found in $(Get-Location)." -ForegroundColor Red
}
Write-Host ""
Write-Host "------------------------------"
Write-Host ""
Write-Host "Look like the game closed... Closing in 10 seconds."
Start-Sleep -Seconds 10
