@echo off
rem Port of run-ci-artifact-names.sh - keep in sync with the .sh / .ps1 versions.
setlocal EnableExtensions
cd /d "%~dp0..\.." || exit /b 1
if not defined HAXE set "HAXE=haxe"
"%HAXE%" -cp tests/haxe -main CIArtifactNamesSpec --interp
exit /b %ERRORLEVEL%
