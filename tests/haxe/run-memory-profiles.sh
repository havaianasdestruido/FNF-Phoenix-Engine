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
# definitions; only that shape is inspected, not the comments around it.
pairs="$(grep -oE "set\('[A-Za-z0-9_]+',[[:space:]]*(true|false|[0-9]+)\)" \
  "$root/source/backend/MemoryProfiles.hx" || true)"

if [ -z "$pairs" ]; then
  echo "FAIL: no profile overrides found in MemoryProfiles.hx" >&2
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
    echo "FAIL: profile override '$key' is not a ClientPrefs field" >&2
    exit 1
  fi

  case "$value" in
    true|false) want=Bool ;;
    *) want=Int ;;
  esac

  case "$decl" in
    *:Bool) have=Bool ;;
    *:Int) have=Int ;;
    *:Float) have=Int ;; # an integer literal is a valid Float value
    *:String) have=String ;;
    *) have=unknown ;;
  esac

  if [ "$want" != "$have" ]; then
    echo "FAIL: profile forces $key=$value ($want) but ClientPrefs declares $decl" >&2
    exit 1
  fi
  checked=$((checked + 1))
done < <(printf '%s\n' "$pairs" | sed -E "s/set\('([A-Za-z0-9_]+)',[[:space:]]*/\1 /; s/\)$//")

echo "MemoryProfilesSpec passed: $checked forced preferences verified against ClientPrefs.hx"
bash "$root/tests/haxe/run-song-audio-streaming.sh"
