@echo off
rem Port of run-commit-freshness.sh - keep in sync with the .sh / .ps1 versions.
setlocal EnableExtensions
cd /d "%~dp0..\.."
if not defined HAXE set "HAXE=haxe"
set "TEST_SOURCE=%TEMP%\commit-freshness-%RANDOM%-%RANDOM%"
mkdir "%TEST_SOURCE%\backend" || exit /b 1
copy /y "source\backend\CommitFreshness.hx" "%TEST_SOURCE%\backend\" >nul || goto fail
copy /y "source\backend\HaxeCommit.hx" "%TEST_SOURCE%\backend\" >nul || goto fail
%HAXE% -cp "%TEST_SOURCE%" -cp tests/haxe -main CommitFreshnessSpec --interp || goto fail
rem Both sides of `#if commit`: unstamped builds keep the null fallback,
rem stamped builds embed this checkout's hash.
%HAXE% -cp "%TEST_SOURCE%" -cp tests/haxe -main CommitStampSpec --interp || goto fail
%HAXE% -cp "%TEST_SOURCE%" -cp tests/haxe -main CommitStampSpec -D commit --interp || goto fail
rd /s /q "%TEST_SOURCE%" 2>nul
exit /b 0
:fail
set "ERR=%ERRORLEVEL%"
rd /s /q "%TEST_SOURCE%" 2>nul
if "%ERR%"=="0" set "ERR=1"
exit /b %ERR%
