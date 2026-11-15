#!/usr/bin/env bash
# Runs the PlayerStats + PlaytimeTracker + StatsState + AchievementsMenuState specs
# in the Haxe interpreter AND typechecks them against static targets (cpp + js)
# across feature-flag combinations (with and without ACHIEVEMENTS_ALLOWED).
set -euo pipefail

cd "$(dirname "$0")/../.."
ROOT="$(pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

TEST_SRC="$TMP_DIR/src"
mkdir -p "$TEST_SRC/backend" "$TEST_SRC/states"
cp -r "$ROOT/tests/haxe/stubs/stats/." "$TEST_SRC/"
cp "$ROOT/source/backend/PlayerStats.hx" "$TEST_SRC/backend/PlayerStats.hx"
cp "$ROOT/source/backend/PlaytimeTracker.hx" "$TEST_SRC/backend/PlaytimeTracker.hx"
cp "$ROOT/source/states/StatsState.hx" "$TEST_SRC/states/StatsState.hx"
cp "$ROOT/source/states/AchievementsMenuState.hx" "$TEST_SRC/states/AchievementsMenuState.hx"

HAXE_BIN="${HAXE:-haxe}"

run_interp() {
  local main="$1"
  shift
  "$HAXE_BIN" -cp "$TEST_SRC" -cp "$ROOT/tests/haxe" "$@" -main "$main" --interp
}

run_typecheck() {
  local main="$1"
  local tag="$2"
  shift 2
  "$HAXE_BIN" -cp "$TEST_SRC" -cp "$ROOT/tests/haxe" "$@" -main "$main" -cpp "$TMP_DIR/cpp-$tag" --no-output
  "$HAXE_BIN" -cp "$TEST_SRC" -cp "$ROOT/tests/haxe" "$@" -main "$main" -js "$TMP_DIR/js-$tag.js" --no-output
}

# 1. Interpreter specs: with ACHIEVEMENTS_ALLOWED + MODS_ALLOWED + DISCORD_ALLOWED
run_interp PlayerStatsSpec -D ACHIEVEMENTS_ALLOWED -D MODS_ALLOWED
run_interp StatsStateSpec -D ACHIEVEMENTS_ALLOWED -D MODS_ALLOWED -D DISCORD_ALLOWED

# 2. Interpreter specs: without ACHIEVEMENTS_ALLOWED (verifies standalone StatsState & PlaytimeTracker)
run_interp PlayerStatsSpec
run_interp StatsStateSpec

# 3. Static-target typechecks (catches C++/JS strict typing pitfalls such as Float == null)
run_typecheck PlayerStatsSpec ps-full -D ACHIEVEMENTS_ALLOWED -D MODS_ALLOWED
run_typecheck StatsStateSpec ss-full -D ACHIEVEMENTS_ALLOWED -D MODS_ALLOWED -D DISCORD_ALLOWED
run_typecheck StatsStateSpec ss-no-ach
run_typecheck StatsStateSpec ss-mobile -D ACHIEVEMENTS_ALLOWED -D MODS_ALLOWED -D mobile
run_typecheck StatsStateSpec ss-nomouse -D ACHIEVEMENTS_ALLOWED -D MODS_ALLOWED -D FLX_NO_MOUSE
echo "Static target typechecks (cpp + js): OK"
