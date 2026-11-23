#!/usr/bin/env bash
# Options -> Optimization -> Memory Profile.
#
# No game haxelibs needed:
#   1. Exercise the pure profile data and the actual apply/save/cleanup layer
#      (with tiny Flixel stubs), including profile transitions and restoration.
#   2. Check every forced literal against the real ClientPrefs declarations.
#   3. Exercise the streaming helper and production Paths routing/fallbacks
#      with and without native Vorbis/OpenAL support.
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/backend"
cp "$root/source/backend/MemoryProfiles.hx" "$work/backend/MemoryProfiles.hx"

"${HAXE:-haxe}" -cp "$work" -cp "$root/tests/haxe" -main MemoryProfilesSpec --interp

# Run the actual apply/save/restore and cleanup layer with small Flixel stubs.
cp -R "$root/tests/haxe/stubs/low-memory/." "$work/"
cp "$root/source/backend/LowMemory.hx" "$work/backend/LowMemory.hx"
mkdir -p "$work/options"
cp "$root/source/options/Option.hx" "$work/options/Option.hx"
"${HAXE:-haxe}" -cp "$work" -cp "$root/tests/haxe" -D DISCORD_ALLOWED -main LowMemorySpec --interp

# --- Static guard: every override is a real, correctly typed preference ------
# Overrides are written as `forced.set('field', literal)` in the profile
# definitions; reject any `forced.set(` call whose literal is not covered here.
all_sets="$(grep -c "forced\.set(" "$root/source/backend/MemoryProfiles.hx" || true)"
pairs="$(grep -oE "forced\.set\('[A-Za-z0-9_]+',[[:space:]]*(true|false|[0-9]+(\.[0-9]+)?|'[^']*')\)" \
  "$root/source/backend/MemoryProfiles.hx" || true)"

if [ -z "$pairs" ]; then
  echo "FAIL: no profile overrides found in MemoryProfiles.hx" >&2
  exit 1
fi

matched_sets="$(printf '%s\n' "$pairs" | grep -c '^forced\.set(' || true)"
if [ "$matched_sets" -ne "$all_sets" ]; then
  echo "FAIL: found $all_sets forced.set() calls in MemoryProfiles.hx, but only $matched_sets used literal values" >&2
  exit 1
fi

checked=0
while read -r key value; do
  [ -n "${key:-}" ] || continue

  case "$key" in
    memoryProfile|memoryProfileBaseline|lowMemoryMode)
      echo "FAIL: '$key' must never be forced by a profile (it is the profile state itself)" >&2
      exit 1
      ;;
  esac

  decl="$(grep -oE "public static var ${key}:(Bool|Int|Float|String)" \
    "$root/source/backend/ClientPrefs.hx" || true)"
  if [ -z "$decl" ]; then
    echo "FAIL: profile override '$key' is not a typed ClientPrefs field" >&2
    exit 1
  fi

  case "$value" in
    true|false) want=Bool ;;
    \'*\') want=String ;;
    *.*) want=Float ;;
    *) want=Int ;;
  esac

  case "$decl" in
    *:Bool) have=Bool ;;
    *:Int) have=Int ;;
    *:Float)
      if ! grep -q "'${key}' => true" "$root/source/backend/MemoryProfiles.hx"; then
        echo "FAIL: Float preference '$key' must be listed in MemoryProfiles.FLOAT_FIELDS" >&2
        exit 1
      fi
      if [ "$want" = "Int" ]; then have=Int; else have=Float; fi
      ;;
    *:String) have=String ;;
    *) have=unknown ;;
  esac

  if [ "$want" != "$have" ]; then
    echo "FAIL: profile forces $key=$value ($want) but ClientPrefs declares $decl" >&2
    exit 1
  fi
  checked=$((checked + 1))
done < <(printf '%s\n' "$pairs" | sed -E "s/forced\.set\('([A-Za-z0-9_]+)',[[:space:]]*/\1 /; s/\)$//")

echo "MemoryProfilesSpec passed: $checked forced preferences verified against ClientPrefs.hx"
bash "$root/tests/haxe/run-song-audio-streaming.sh"
