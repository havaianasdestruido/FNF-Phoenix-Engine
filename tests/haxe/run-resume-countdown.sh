#!/usr/bin/env bash
# Resume countdown (ClientPrefs.resumeCountdown): unpausing a running song
# counts 3-2-1-GO instead of resuming instantly.
#
# `play.helpers.ResumeCountdownMath` is Flixel-free and `PlayStateResume` only
# needs a small state surface, so both run under the Haxe interpreter with the
# stubs in tests/haxe/stubs/resume-countdown, without the game haxelibs.
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
cp -R tests/haxe/stubs/resume-countdown/. "$test_source/"
mkdir -p "$test_source/play/helpers"
cp source/play/helpers/ResumeCountdownMath.hx "$test_source/play/helpers/"
cp source/play/helpers/PlayStateResume.hx "$test_source/play/helpers/"

"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main ResumeCountdownSpec --interp

# --- Static guard: the Gameplay row is wired to the preference ---------------
grep -q "'resumeCountdown'," source/options/GameplaySettingsSubState.hx \
  || { echo "FAIL: no 'resumeCountdown' row in GameplaySettingsSubState.hx" >&2; exit 1; }

grep -q "public static var resumeCountdown:Bool" source/backend/ClientPrefs.hx \
  || { echo "FAIL: ClientPrefs.resumeCountdown is missing or not a Bool" >&2; exit 1; }

# --- Static guard: the countdown is the unpause path -------------------------
grep -q "ResumeCountdownMath.shouldRun" source/play/PlayState.hx \
  || { echo "FAIL: closeSubState() does not gate on ResumeCountdownMath.shouldRun" >&2; exit 1; }
grep -q "PlayStateResume.begin(this)" source/play/PlayState.hx \
  || { echo "FAIL: closeSubState() does not start the resume countdown" >&2; exit 1; }
grep -q "PlayStateResume.finish(this)" source/play/PlayState.hx \
  || { echo "FAIL: closeSubState() does not perform the instant resume" >&2; exit 1; }
grep -q "PlayStateResume.cancel(this)" source/play/PlayState.hx \
  || { echo "FAIL: destroy() does not tear down a pending resume countdown" >&2; exit 1; }

# Both unpause sites mark the intent; other substate closes resume instantly.
wanted=$(grep -c "resumeCountdownWanted = true" source/states/substates/PauseSubState.hx || true)
[ "$wanted" -ge 2 ] || { echo "FAIL: PauseSubState marks the unpause intent at $wanted sites, expected at least 2" >&2; exit 1; }

# The hooks are registered like every other script event.
grep -q "'onResumeCountdownStart'" source/backend/LuaDiagnostics.hx \
  || { echo "FAIL: onResumeCountdownStart is missing from LuaDiagnostics.KNOWN_HOOKS" >&2; exit 1; }
grep -q "'onResumeCountdownTick'" source/backend/LuaDiagnostics.hx \
  || { echo "FAIL: onResumeCountdownTick is missing from LuaDiagnostics.KNOWN_HOOKS" >&2; exit 1; }

for template in docs/TemplateScript.lua docs/TemplateScript.py docs/TemplateScript.hx; do
  grep -q "onResumeCountdownStart" "$template" \
    || { echo "FAIL: $template does not document onResumeCountdownStart" >&2; exit 1; }
  grep -q "onResumeCountdownTick" "$template" \
    || { echo "FAIL: $template does not document onResumeCountdownTick" >&2; exit 1; }
done

grep -q "onResumeCountdownStart" website/docs/modding/script-hooks.md \
  || { echo "FAIL: website/docs/modding/script-hooks.md does not document onResumeCountdownStart" >&2; exit 1; }
grep -q "onResumeCountdownTick" website/docs/modding/script-hooks.md \
  || { echo "FAIL: website/docs/modding/script-hooks.md does not document onResumeCountdownTick" >&2; exit 1; }

echo "Resume countdown checks: PASS"
