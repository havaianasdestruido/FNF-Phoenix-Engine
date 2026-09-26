@echo off
rem Copy the Android NDK's libc++_shared.so into the generated Gradle project.
rem
rem Windows counterpart of setup/android-copy-stl.sh - keep the two in sync.
rem The prebuilt liblime.so NDLL that Lime puts into the APK is linked against
rem the shared C++ runtime, but nothing in Lime's Android target or the Gradle
rem project copies that runtime into the app, which produces an APK that dies
rem on launch with:
rem
rem     dlopen failed: library "libc++_shared.so" not found: needed by
rem     /data/app/.../lib/arm64/liblime.so
rem
rem project.hxp wires this up as a pre-build callback, which Lime runs after it
rem creates the Gradle project and before it copies the NDLLs and runs Gradle.
rem
rem Usage:
rem   android-copy-stl.bat [--ndk ^<ndk-root^>] ^<jniLibs-dir^> ^<abi^> [^<abi^> ...]

setlocal EnableExtensions EnableDelayedExpansion

set "PROGRAM=%~nx0"
set "NDK_ROOT="
set "JNI_LIBS_DIR="
set "ABIS="

:parse
if "%~1"=="" goto parsed
if /i "%~1"=="--ndk" (
	set "NDK_ROOT=%~2"
	shift
	shift
	goto parse
)
if /i "%~1"=="--help" goto help
if /i "%~1"=="-h" goto help
if not defined JNI_LIBS_DIR (
	set "JNI_LIBS_DIR=%~1"
) else (
	set "ABIS=!ABIS! %~1"
)
shift
goto parse

:parsed
if not defined JNI_LIBS_DIR goto help
if not defined ABIS goto help

rem Lime hands us POSIX style paths; normalise them for cmd's file commands.
set "JNI_LIBS_DIR=!JNI_LIBS_DIR:/=\!"
if defined NDK_ROOT set "NDK_ROOT=!NDK_ROOT:/=\!"

rem Resolve the NDK: explicit argument, then environment, then Lime's config.
if defined NDK_ROOT if not exist "!NDK_ROOT!\" (
	echo %PROGRAM%: ignoring --ndk "!NDK_ROOT!" ^(no such directory^) 1>&2
	set "NDK_ROOT="
)

if not defined NDK_ROOT if defined ANDROID_NDK_ROOT if exist "%ANDROID_NDK_ROOT%\" set "NDK_ROOT=%ANDROID_NDK_ROOT%"

if not defined NDK_ROOT (
	set "LIME_CFG=%USERPROFILE%\.lime\config.xml"
	if defined LIME_CONFIG set "LIME_CFG=!LIME_CONFIG!"
	if exist "!LIME_CFG!" (
		for /f "usebackq tokens=4 delims=^"" %%V in (`findstr /i /c:"ANDROID_NDK_ROOT" "!LIME_CFG!"`) do set "NDK_ROOT=%%V"
	)
)

if not defined NDK_ROOT goto no_ndk
if not exist "!NDK_ROOT!\" goto no_ndk

echo %PROGRAM%: NDK !NDK_ROOT!

for %%A in (!ABIS!) do call :copy_abi %%A
if errorlevel 1 exit /b 1

exit /b 0

:copy_abi
set "ABI=%~1"
set "TRIPLE="

if /i "!ABI!"=="arm64-v8a" set "TRIPLE=aarch64-linux-android"
if /i "!ABI!"=="armeabi-v7a" set "TRIPLE=arm-linux-androideabi"
if /i "!ABI!"=="x86_64" set "TRIPLE=x86_64-linux-android"
if /i "!ABI!"=="x86" set "TRIPLE=i686-linux-android"

if not defined TRIPLE (
	echo %PROGRAM%: unknown ABI "!ABI!", skipping 1>&2
	exit /b 0
)

set "SRC="

rem NDK r23 and newer: unified sysroot. Try both host folder spellings.
for %%H in (windows-x86_64 windows) do (
	if not defined SRC if exist "!NDK_ROOT!\toolchains\llvm\prebuilt\%%H\sysroot\usr\lib\!TRIPLE!\libc++_shared.so" (
		set "SRC=!NDK_ROOT!\toolchains\llvm\prebuilt\%%H\sysroot\usr\lib\!TRIPLE!\libc++_shared.so"
	)
)

rem NDK r18-r22: the STL was a separate download under sources/.
if not defined SRC if exist "!NDK_ROOT!\sources\cxx-stl\llvm-libc++\libs\!ABI!\libc++_shared.so" (
	set "SRC=!NDK_ROOT!\sources\cxx-stl\llvm-libc++\libs\!ABI!\libc++_shared.so"
)

if not defined SRC (
	echo %PROGRAM%: libc++_shared.so for "!ABI!" not found under !NDK_ROOT! 1>&2
	exit /b 1
)

if not exist "!JNI_LIBS_DIR!\!ABI!\" mkdir "!JNI_LIBS_DIR!\!ABI!"
copy /y "!SRC!" "!JNI_LIBS_DIR!\!ABI!\libc++_shared.so" >nul
if errorlevel 1 exit /b 1

echo %PROGRAM%: lib/!ABI!/libc++_shared.so ^<- !SRC!
exit /b 0

:no_ndk
echo %PROGRAM%: cannot find the Android NDK. 1>&2
echo   Set ANDROID_NDK_ROOT, pass --ndk ^<path^>, or run 'lime setup android'. 1>&2
exit /b 1

:help
echo Usage: %PROGRAM% [--ndk ^<ndk-root^>] ^<jniLibs-dir^> ^<abi^> [^<abi^> ...]
echo.
echo Copies libc++_shared.so from the Android NDK into ^<jniLibs-dir^>\^<abi^>\.
echo Recognised ABIs: arm64-v8a, armeabi-v7a, x86_64, x86
exit /b 2
