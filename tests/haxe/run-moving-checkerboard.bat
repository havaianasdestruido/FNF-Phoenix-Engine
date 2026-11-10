@echo off
setlocal
set "ROOT=%~dp0..\.."
set "WORK=%TEMP%\phoenix-moving-checkerboard-%RANDOM%-%RANDOM%"

mkdir "%WORK%\objects" >nul 2>nul || goto fail
copy /y "%ROOT%\source\objects\MovingCheckerboard.hx" "%WORK%\objects\" >nul || goto fail
xcopy /e /i /y "%ROOT%\tests\haxe\stubs\moving-checkerboard" "%WORK%" >nul || goto fail

if defined HAXE (
  "%HAXE%" -cp "%WORK%" -cp "%ROOT%\tests\haxe" -main MovingCheckerboardSpec --interp
) else (
  haxe -cp "%WORK%" -cp "%ROOT%\tests\haxe" -main MovingCheckerboardSpec --interp
)
if errorlevel 1 goto fail

rmdir /s /q "%WORK%" >nul 2>nul
exit /b 0

:fail
rmdir /s /q "%WORK%" >nul 2>nul
exit /b 1
