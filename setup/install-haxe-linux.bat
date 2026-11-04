@echo off
rem Port of install-haxe-linux.sh - keep in sync with the .sh / .ps1 versions.
rem That script installs the *Linux x86_64* Haxe binaries, which cannot run
rem under cmd.exe. If WSL is available this delegates to the .sh version
rem inside WSL; otherwise it explains how to install Haxe on Windows.
setlocal EnableExtensions EnableDelayedExpansion

where wsl.exe >nul 2>&1
if errorlevel 1 goto no_wsl

echo Delegating to install-haxe-linux.sh inside WSL...
pushd "%~dp0"
wsl.exe -- bash ./install-haxe-linux.sh
set "ERR=!ERRORLEVEL!"
popd
exit /b !ERR!

:no_wsl
echo install-haxe-linux installs the Linux x86_64 Haxe binaries and cannot run natively in cmd.exe. 1>&2
echo Either enable WSL ^(wsl --install^) and re-run this file, or install Haxe 1>&2
echo on Windows from https://haxe.org/download 1>&2
exit /b 1
