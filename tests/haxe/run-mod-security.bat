@echo off
rem Port of run-mod-security.sh - keep in sync with the .sh / .ps1 versions.
rem ModSecurity policy and the per-mod switch of Mod Info in the Mods menu.
setlocal EnableExtensions
cd /d "%~dp0..\.."
set "REPO=%CD%"
if not defined HAXE set "HAXE=haxe"
set "WORK=%TEMP%\phoenix-mod-security-%RANDOM%-%RANDOM%"
mkdir "%WORK%\backend" "%WORK%\states\helpers" || exit /b 1
copy /y "source\backend\ModSecurity.hx" "%WORK%\backend\" >nul || goto fail
copy /y "source\backend\ScriptSecurityScanner.hx" "%WORK%\backend\" >nul || goto fail
copy /y "source\states\helpers\ModInfoFlow.hx" "%WORK%\states\helpers\" >nul || goto fail

rem 1. Dependency-free contract: without MODS_ALLOWED nothing is read or written.
%HAXE% -cp "%WORK%" -cp tests/haxe -main ModSecuritySpec --interp || goto fail

rem 2. Logic of the Mod Info panel: switching off needs an explicit "Yes", and a
rem    mod cannot write into the panel through its name or its pack.json.
%HAXE% -cp "%WORK%" -cp tests/haxe -main ModInfoFlowSpec --interp || goto fail

rem 3. MODS_ALLOWED build with a stub backend.Mods. modSecurity.txt is relative to
rem    the working directory, so run inside the throwaway folder.
pushd "%WORK%"
%HAXE% -cp "%WORK%" -cp "%REPO%\tests\haxe\stubs\mod-security" -cp "%REPO%\tests\haxe" -main ModSecurityPlayerSpec -D MODS_ALLOWED --interp
if not errorlevel 1 goto haxe_ok
popd
goto fail
:haxe_ok
popd
rd /s /q "%WORK%" 2>nul
exit /b 0
:fail
set "ERR=%ERRORLEVEL%"
rd /s /q "%WORK%" 2>nul
if "%ERR%"=="0" set "ERR=1"
exit /b %ERR%
