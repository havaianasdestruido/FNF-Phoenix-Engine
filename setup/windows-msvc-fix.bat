@echo off
rem Port of windows-msvc-fix.ps1 - keep in sync with the .ps1 / .sh versions.
rem Ensures the hxcpp haxelib is set to the FunkinCrew git checkout that
rem setup\windows.bat installs (required for MSVC: the git hxcpp assembles
rem hxluau's libffi .asm files and honours HXCPP_CPP17; 4.3.2 does neither).
rem Idempotent. Run AFTER setup\windows.bat, before building.
rem Usage (from repo root): setup\windows-msvc-fix.bat
setlocal EnableExtensions EnableDelayedExpansion

set "EXPECTED_REMOTE=https://github.com/FunkinCrew/hxcpp"

for /f "delims=" %%P in ('haxelib path hxcpp 2^>nul') do if not defined HXPATH set "HXPATH=%%P"
if not defined HXPATH goto after_remote
if not exist "%HXPATH%\.git" goto after_remote
for /f "delims=" %%R in ('git -C "%HXPATH%" remote get-url origin 2^>nul') do set "ACTUAL_REMOTE=%%R"
if not defined ACTUAL_REMOTE goto after_remote
echo !ACTUAL_REMOTE! | findstr /c:"FunkinCrew/hxcpp" >nul
if errorlevel 1 (
    echo hxcpp checkout at %HXPATH% points at '!ACTUAL_REMOTE!', expected '%EXPECTED_REMOTE%' ^(see hmm.json^). Re-run setup\windows.bat. 1>&2
    exit /b 1
)
echo hxcpp remote verified: !ACTUAL_REMOTE!

:after_remote

set "HXLIST="
for /f "delims=" %%L in ('haxelib list hxcpp 2^>nul') do set "HXLIST=!HXLIST!%%L "
echo !HXLIST! | findstr /l /c:"[git]" >nul
if not errorlevel 1 (
    echo hxcpp already set to git. OK.
    goto done
)
echo !HXLIST! | findstr /i /c:"git" >nul
if not errorlevel 1 (
    echo Setting hxcpp to git...
    haxelib set hxcpp git >nul
    echo hxcpp set to git. OK.
    goto done
)
echo hxcpp git checkout not found in haxelib. Run setup\windows.bat first ^(it installs hxcpp from the FunkinCrew fork^). 1>&2
exit /b 1

:done
echo.
echo Done. Build with: lime build windows -DMODDING_LEVEL=2
endlocal
