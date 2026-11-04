# Port of renderlol.bat - keep in sync with renderlol.bat / renderlol.sh.
Write-Host "hello there!"
Write-Host "PS: this will only work if you have ffmpeg installed and are using the classic rendering mode."
Write-Host ""
$renderFolder = Read-Host "enter the name of the song you'd like to render! (this is the folder that you'll use)"
Write-Host ""
$renderName = Read-Host "what would you like to name your rendered video?"
Write-Host ""
$vidFPS = Read-Host "what is the framerate of your images/video? (defaults to 60)"
if ([string]::IsNullOrWhiteSpace($vidFPS)) { $vidFPS = "60" }
Write-Host ""
$useLossless = Read-Host "lastly, are you rendering your video in a lossless format? (y/n, default n, makes the renderer find pngs instead of jpgs)"
if ($useLossless -ine "y") { $useLossless = "n" }
$fExt = if ($useLossless -ieq "y") { "png" } else { "jpg" }
Write-Host ""
Write-Host "Starting..."
Write-Host ""
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
ffmpeg -r $vidFPS -i "$scriptDir\$renderFolder\%07d.$fExt" "$renderName.mp4"
Read-Host "Press Enter to continue"
