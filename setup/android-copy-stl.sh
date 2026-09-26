#!/bin/sh
# Copy the Android NDK's libc++_shared.so into the generated Gradle project.
#
# WHY THIS EXISTS
# ---------------
# The prebuilt `liblime.so` NDLL that Lime drops into the APK is dynamically
# linked against the *shared* C++ runtime:
#
#     $ readelf -d ndll/Android/liblime-64.so | grep NEEDED
#      0x00000001 (NEEDED)   Shared library: [libc++_shared.so]
#
# Neither Lime's Android target (tools/platforms/AndroidPlatform.hx) nor the
# Gradle project it generates ever copies that runtime into the app, so the
# APK ships lib/arm64-v8a/liblime.so with an unsatisfied dependency and dies
# before the first frame is drawn:
#
#     dlopen failed: library "libc++_shared.so" not found: needed by
#     /data/app/.../lib/arm64/liblime.so in namespace clns-N
#
# Lime runs pre-build callbacks after `update()` (which creates the Gradle
# project) and before `build()` (which copies the NDLLs and invokes Gradle),
# so project.hxp wires this script up as a pre-build callback: it is the last
# moment the file can be dropped into the right place.
#
# USAGE
# -----
#   android-copy-stl.sh [--ndk <ndk-root>] <jniLibs-dir> <abi> [<abi> ...]
#
#   --ndk         Android NDK root. Optional; falls back to $ANDROID_NDK_ROOT
#                 and then to Lime's config file ($LIME_CONFIG or
#                 ~/.lime/config.xml).
#   <jniLibs-dir> Usually build/<type>/android/bin/app/src/main/jniLibs
#   <abi>         arm64-v8a, armeabi-v7a, x86_64 or x86
#
# Exits non-zero when the runtime cannot be found, so a broken APK is never
# produced silently.

set -eu

PROGRAM=$(basename "$0")

usage() {
	cat <<EOF
Usage: $PROGRAM [--ndk <ndk-root>] <jniLibs-dir> <abi> [<abi> ...]

Copies libc++_shared.so from the Android NDK into <jniLibs-dir>/<abi>/.
Recognised ABIs: arm64-v8a, armeabi-v7a, x86_64, x86
EOF
}

# Read a value out of Lime's config file, e.g.
#   <set name="ANDROID_NDK_ROOT" value="/opt/android-ndk" />
lime_config_value() {
	_name=$1
	_cfg=${LIME_CONFIG:-}

	if [ -z "$_cfg" ]; then
		for _home in ${HOME:-} ${USERPROFILE:-}; do
			if [ -n "$_home" ] && [ -f "$_home/.lime/config.xml" ]; then
				_cfg="$_home/.lime/config.xml"
				break
			fi
		done
	fi

	[ -n "$_cfg" ] && [ -f "$_cfg" ] || return 1

	sed -nE "s/.*<set(env)? name=\"$_name\" value=\"([^\"]*)\".*/\2/p" "$_cfg" | tail -n 1
}

NDK_ROOT=""
JNI_LIBS_DIR=""
ABIS=""

while [ $# -gt 0 ]; do
	case $1 in
		--ndk)
			[ $# -ge 2 ] || { echo "$PROGRAM: --ndk needs a value" >&2; exit 2; }
			NDK_ROOT=$2
			shift 2
			;;
		-h | --help)
			usage
			exit 0
			;;
		*)
			if [ -z "$JNI_LIBS_DIR" ]; then
				JNI_LIBS_DIR=$1
			else
				ABIS="$ABIS $1"
			fi
			shift
			;;
	esac
done

if [ -z "$JNI_LIBS_DIR" ] || [ -z "$ABIS" ]; then
	usage >&2
	exit 2
fi

# Resolve the NDK: explicit argument, then environment, then Lime's config.
if [ -n "$NDK_ROOT" ] && [ ! -d "$NDK_ROOT" ]; then
	echo "$PROGRAM: ignoring --ndk \"$NDK_ROOT\" (no such directory)" >&2
	NDK_ROOT=""
fi

if [ -z "$NDK_ROOT" ] && [ -n "${ANDROID_NDK_ROOT:-}" ] && [ -d "${ANDROID_NDK_ROOT:-}" ]; then
	NDK_ROOT=$ANDROID_NDK_ROOT
fi

if [ -z "$NDK_ROOT" ]; then
	NDK_ROOT=$(lime_config_value ANDROID_NDK_ROOT || true)
fi

if [ -z "$NDK_ROOT" ] || [ ! -d "$NDK_ROOT" ]; then
	echo "$PROGRAM: cannot find the Android NDK." >&2
	echo "  Set ANDROID_NDK_ROOT, pass --ndk <path>, or run 'lime setup android'." >&2
	exit 1
fi

echo "$PROGRAM: NDK $NDK_ROOT"

for abi in $ABIS; do
	case $abi in
		arm64-v8a) triple=aarch64-linux-android ;;
		armeabi-v7a) triple=arm-linux-androideabi ;;
		x86_64) triple=x86_64-linux-android ;;
		x86) triple=i686-linux-android ;;
		*)
			echo "$PROGRAM: unknown ABI \"$abi\", skipping" >&2
			continue
			;;
	esac

	src=""

	# NDK r23 and newer: everything lives in the unified sysroot. The host
	# folder (linux-x86_64 / darwin-x86_64 / windows-x86_64) is matched with a
	# glob so the script does not care which one the NDK ships.
	for candidate in "$NDK_ROOT"/toolchains/llvm/prebuilt/*/sysroot/usr/lib/"$triple"/libc++_shared.so; do
		if [ -f "$candidate" ]; then
			src=$candidate
			break
		fi
	done

	# NDK r18-r22: the STL was a separate download under sources/.
	if [ -z "$src" ]; then
		for candidate in "$NDK_ROOT"/sources/cxx-stl/llvm-libc++/libs/"$abi"/libc++_shared.so; do
			if [ -f "$candidate" ]; then
				src=$candidate
				break
			fi
		done
	fi

	if [ -z "$src" ]; then
		echo "$PROGRAM: libc++_shared.so for \"$abi\" not found under $NDK_ROOT" >&2
		echo "  Looked in toolchains/llvm/prebuilt/*/sysroot/usr/lib/$triple/ and" >&2
		echo "  sources/cxx-stl/llvm-libc++/libs/$abi/" >&2
		exit 1
	fi

	mkdir -p "$JNI_LIBS_DIR/$abi"
	cp -f "$src" "$JNI_LIBS_DIR/$abi/libc++_shared.so"
	chmod 0644 "$JNI_LIBS_DIR/$abi/libc++_shared.so"

	echo "$PROGRAM: lib/$abi/libc++_shared.so <- $src"
done
