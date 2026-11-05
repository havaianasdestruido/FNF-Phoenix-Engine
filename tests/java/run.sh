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
