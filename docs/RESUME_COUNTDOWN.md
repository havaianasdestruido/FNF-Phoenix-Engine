# Resume countdown

`ClientPrefs.resumeCountdown` (Options → Gameplay → **Resume Countdown**, default `on`):
unpausing a running song plays a 3-2-1-GO instead of resuming instantly. It matters most
on phones, where the thumb leaves the hitbox to press Resume in the pause menu; on desktop
it is the same one-option difference.

## How it works

- `PauseSubState` marks the intent (`PlayState.resumeCountdownWanted = true`) at the two
  call sites that resume the song (Resume, Resume from the pause menu); every other way of
  closing a substate resumes instantly as before.
- `PlayState.closeSubState()` checks `ResumeCountdownMath.shouldRun(resumeCountdown, paused,
  startingSong, canResync, ffmpegMode)`. Only a real unpause of a running song counts down:
  the preference on, the chart frozen, the intro countdown not running, resync allowed and
  not FFmpeg rendering.
- The countdown reuses the intro-countdown presentation: the `ready` / `set` / `go` art and
  the `intro3` / `intro2` / `intro1` / `introGo` sounds, and the same tick interval — one
  chart beat (`Conductor.crochet` / `playbackRate`, clamped to `[MIN, MAX]` in
  `ResumeCountdownMath.tickInterval`).
- `onResume`, the vocal resync and the Discord presence reset do not fire until the GO
  tick. `PlayState.paused` stays `true` and timers/tweens stay frozen between ticks.

## Scripting

`onResume` alone was ambiguous between "menu closed" and "song is live again", so the
countdown is script-visible like the other pause events:

```lua
function onResumeCountdownStart()
    -- Optional: return Function_Stop to skip the countdown and resume instantly.
end

function onResumeCountdownTick(count)
    -- count is 3, 2, 1 or 0 (GO).
end
```

`resumeCountdownActive` is readable from scripts (`getProperty('resumeCountdownActive')`,
`true` from the moment unpausing starts until GO) and `onResume` still fires at the true
resume. Both hooks are registered in `backend.LuaDiagnostics.KNOWN_HOOKS` and documented in
`docs/TemplateScript.lua` / `.py` / `.hx` and `website/docs/modding/script-hooks.md`.

Teardown (song end, destroy) cancels a pending countdown without resuming:
`PlayStateResume.cancel(state)` stops the timer and clears the intent.

Spec: `bash tests/haxe/run-resume-countdown.sh` (runs in `checks.yml`).
