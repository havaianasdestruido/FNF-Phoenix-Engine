#!/usr/bin/env bash
# GDI HPPD test song: a modchart timeline whose beat-timed callbacks
# trigger GDI visual payloads through the modding API.
#
# Proves the payloads are reachable only through the modding API
# (GDIEffects.hppdTrigger) — a song drives them beat by beat, and
# nothing auto-runs or activates by date/time. On the interpreter the
# GDI bridge is a safe no-op, so this verifies the song wiring and
# timing; the native trigger is covered by tests/native/test_gdi_hppd.cpp.
set -euo pipefail
cd "$(dirname "$0")/../.."

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Copy the modchart core (the song timeline engine) and the GDI bridge.
mkdir -p "$work/modchart" "$work/backend"
cp -r source/modchart/. "$work/modchart/"
cp source/backend/GDIEffects.hx "$work/backend/"
cp source/backend/GdiNative.hx "$work/backend/"

# Provide the renderer-free FlxG stub the GDI bridge needs.
cp -R tests/haxe/stubs/gdi-hppd-song/. "$work/"

"${HAXE:-haxe}" -cp "$work" -cp tests/haxe -main GdiHppdSongSpec --interp

# --- Static wiring guards ----------------------------------------------------
# The payloads must never auto-run: GDI initialization must not call the
# HPPD trigger. They are reachable only through the modding API.

grep -q "phoenixGdiInitialize" source/backend/native/src/phoenix_gdi.cpp \
  || { echo "FAIL: phoenixGdiInitialize not found" >&2; exit 1; }

# phoenixGdiInitialize must not contain any HPPD trigger call.
init_body=$(sed -n '/phoenixGdiInitialize/,/^}/p' source/backend/native/src/phoenix_gdi.cpp || true)
if echo "$init_body" | grep -q "PhoenixHppdTrigger\|hppdTrigger"; then
  echo "FAIL: phoenixGdiInitialize must not auto-trigger any HPPD payload" >&2; exit 1
fi

# No date/timebomb activation in the Death Month subsystem: the date table
# and its accessors must be gone; only the visual renderers remain.
# (Ignore comment lines that merely mention the removed symbols.)
if grep -vE '^\s*(\*|//|/\*)' \
    source/backend/native/src/phoenix_gdi_hppd_death.cpp \
    source/backend/native/include/phoenix_gdi_hppd.h \
    | grep -q "PhoenixHppdDeathMonthToday\|PhoenixHppdDeathMonthName\|gPhoenixHppdDeathMonth\["; then
  echo "FAIL: date/timebomb activation must be fully removed" >&2; exit 1
fi

# The Death Month renderers (IDs 101-131) must still exist as visual-only.
grep -q "GDIPDeath01" source/backend/native/src/phoenix_gdi_hppd_death.cpp \
  || { echo "FAIL: Death Month visual renderers missing" >&2; exit 1; }
grep -q "GDIPDeath31" source/backend/native/src/phoenix_gdi_hppd_death.cpp \
  || { echo "FAIL: Death Month visual renderer 31 missing" >&2; exit 1; }

# The modding API is the sole trigger entry point.
grep -q "public static function hppdTrigger(id:Int):Bool" source/backend/GDIEffects.hx \
  || { echo "FAIL: GDIEffects.hppdTrigger must exist" >&2; exit 1; }

echo "GDI HPPD song wiring checks: PASS"
echo "gdi hppd song spec passed"
