@echo off
rem Port of run-mod-health.sh - keep in sync with the .sh / .ps1 versions.
rem The per-mod "why did it break?" report: ModHealth itself, then the
rem Mods.getPack() half against the small stubs in tests\haxe\stubs\mod-pack.
setlocal EnableExtensions
cd /d "%~dp0..\.."
set "REPO=%CD%"
if not defined HAXE set "HAXE=haxe"
set "WORK=%TEMP%\phoenix-mod-health-%RANDOM%-%RANDOM%"
mkdir "%WORK%\backend" "%WORK%\states\helpers" "%WORK%\pack\backend" || exit /b 1
copy /y "source\backend\ModHealth.hx" "%WORK%\backend\" >nul || goto fail
copy /y "source\backend\ModPathPolicy.hx" "%WORK%\backend\" >nul || goto fail
copy /y "source\states\helpers\ModInfoFlow.hx" "%WORK%\states\helpers\" >nul || goto fail

rem 1. The report itself: recording, severity, summary and the Mod Info block.
%HAXE% -cp "%WORK%" -cp "%REPO%\tests\haxe" -main ModHealthSpec --interp || goto fail

rem 2. The manifest half reads the real backend\Mods.hx inside a throwaway tree.
copy /y "source\backend\Mods.hx" "%WORK%\pack\backend\" >nul || goto fail
copy /y "source\backend\ModsList.hx" "%WORK%\pack\backend\" >nul || goto fail
copy /y "source\backend\ModHealth.hx" "%WORK%\pack\backend\" >nul || goto fail
copy /y "source\backend\ModPathPolicy.hx" "%WORK%\pack\backend\" >nul || goto fail
> "%WORK%\pack\import.hx" (
  echo #if !macro
  echo import sys.FileSystem;
  echo import sys.io.File;
  echo using StringTools;
  echo #end
)
pushd "%WORK%\pack"
%HAXE% -cp "%WORK%\pack" -cp "%REPO%\tests\haxe\stubs\mod-pack" -cp "%REPO%\tests\haxe" -main ModPackHealthSpec -D MODS_ALLOWED --interp
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
