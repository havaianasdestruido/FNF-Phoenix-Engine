#!/usr/bin/env bash
# Host-JVM regression tests for the Android bridge/policy classes.
# Requires javac + java (JDK 17 in CI). No Android SDK or device needed.
set -euo pipefail
cd "$(dirname "$0")/../.."

JAVAC="${JAVAC:-javac}"
JAVA="${JAVA:-java}"
command -v "$JAVAC" >/dev/null || { echo "javac is required" >&2; exit 1; }
command -v "$JAVA" >/dev/null || { echo "java is required" >&2; exit 1; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
classes="$work/classes"
mkdir -p "$classes"
android_src=source/android/src/quack/fnf/phoenix/android
test_src=tests/java/quack/fnf/phoenix/android

# --- Stub layout --------------------------------------------------------------
# tests/java/stubs holds the Android API doubles every host-JVM test compiles
# against; tests/java/tv_stubs adds only the extra API the Android TV / remote
# classes touch, and is fed to javac for the TV test alone. A shared stub must
# therefore never name a tv-only type — the cutout compile (which sees
# tests/java/stubs only) would fail with "cannot find symbol". Checked here so
# the breakage is reported as a layout error instead of a javac wall of text.
while IFS= read -r -d '' tv; do
  tv_name=$(basename "$tv" .java)
  while IFS= read -r -d '' shared; do
    if grep -qE "(^|[^A-Za-z0-9_])${tv_name}([^A-Za-z0-9_]|$)" "$shared"; then
      echo "FAIL: $shared uses ${tv_name}, which only exists in tests/java/tv_stubs;" >&2
      echo "      move that stub into tests/java/stubs (it is shared API)." >&2
      exit 1
    fi
  done < <(find tests/java/stubs -name '*.java' -print0)
done < <(find tests/java/tv_stubs -name '*.java' -print0)

# --- SAF document path policy ------------------------------------------------
"$JAVAC" -encoding UTF-8 -d "$classes" \
  "$android_src/PhoenixDocumentPathPolicy.java" \
  "$test_src/PhoenixDocumentPathPolicyTest.java"
"$JAVA" -cp "$classes" quack.fnf.phoenix.android.PhoenixDocumentPathPolicyTest

# --- Media3 bridge lifecycle / artwork / action protocol ---------------------
"$JAVAC" -encoding UTF-8 -d "$classes" \
  "$android_src/PhoenixMediaBridgeState.java" \
  "$android_src/PhoenixMediaAction.java" \
  "$test_src/PhoenixMediaBridgeStateTest.java"
"$JAVA" -cp "$classes" quack.fnf.phoenix.android.PhoenixMediaBridgeStateTest

# --- Cutout policy / layout / display lifecycle ------------------------------
# Compile the production classes and the rendered MainActivity template against
# the minimal Android API doubles in tests/java/stubs.
mkdir -p "$work/src/quack/fnf/phoenix"
sed 's/::APP_PACKAGE::/quack.fnf.phoenix/g' \
  source/templates/android/MainActivity.java > "$work/src/quack/fnf/phoenix/MainActivity.java"

stub_sources=()
while IFS= read -r -d '' f; do stub_sources+=("$f"); done \
  < <(find tests/java/stubs -name '*.java' -print0)

"$JAVAC" -encoding UTF-8 -d "$classes" \
  "${stub_sources[@]}" \
  "$android_src/PhoenixCutoutPolicy.java" \
  "$android_src/PhoenixCutoutLayout.java" \
  "$android_src/PhoenixDisplay.java" \
  "$work/src/quack/fnf/phoenix/MainActivity.java" \
  "$test_src/PhoenixCutoutTest.java"
"$JAVA" -cp "$classes" quack.fnf.phoenix.android.PhoenixCutoutTest

# --- Android TV detection, Back/Menu routing, and task backgrounding ---------
classes_tv="$work/classes_tv"
mkdir -p "$classes_tv"

tv_stub_sources=()
while IFS= read -r -d '' f; do
  case "$f" in
    tests/java/stubs/quack/fnf/phoenix/android/PhoenixCore.java|tests/java/stubs/quack/fnf/phoenix/android/PhoenixInput.java) continue ;;
  esac
  tv_stub_sources+=("$f")
done < <(find tests/java/stubs tests/java/tv_stubs -name '*.java' -print0)

"$JAVAC" -encoding UTF-8 -d "$classes_tv" \
  "${tv_stub_sources[@]}" \
  "$android_src/PhoenixCutoutPolicy.java" \
  "$android_src/PhoenixCutoutLayout.java" \
  "$android_src/PhoenixDisplay.java" \
  "$android_src/PhoenixCore.java" \
  "$android_src/PhoenixInput.java" \
  "$work/src/quack/fnf/phoenix/MainActivity.java" \
  "$test_src/PhoenixTVNavigationTest.java"
"$JAVA" -cp "$classes_tv" quack.fnf.phoenix.android.PhoenixTVNavigationTest
