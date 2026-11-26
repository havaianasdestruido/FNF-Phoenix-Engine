# WIN32MODCHART

A bundled test mod for **Phoenix Engine**. It turns **Erect Dad Battle** into a
song that changes its modchart on **every turn**, then hands the desktop over to
the engine's bundled **Windows GDI** effects for the last chorus.

- **Week / freeplay entry:** WIN32 Modchart
- **Song:** WIN32MODCHART (Erect)
- **Base chart and audio:** Erect Dad Battle - chart and music by Kawai Sprite
- **Length:** about 2:11 at 190 BPM (416 beats, 104 sections)
- **Platform:** Windows only (`"platforms": ["windows"]` in `pack.json`)
- **Modchart language:** Lua only

## How to run it

1. Launch the game and open **Freeplay**.
2. Pick the **WIN32 Modchart** week.
3. Play on **Erect**. (`Normal` is offered in the week file only because the
   engine needs a non-Erect difficulty to include Erect in the menu; the Erect
   chart and stems are the ones this mod ships.)

On Windows the top-right HUD line reads `WIN32 GDI: armed`. On every other
target it reads `WIN32 GDI: simulated` and the desktop payloads are skipped -
the climax still reads through the camera.

## What changes on every turn

Dad Battle hands sections back and forth between dad and bf. A *block* is four
beats of one side singing, and every block gets a different move from a fixed
twelve-move cycle.

Peaks below are measured by the validator over a whole playthrough, not the
nominal constants, so they already include the intensity scaling.

| # | Move | What the player sees (measured peak) |
| --- | --- | --- |
| 1 | `x slide` | the field slides sideways, 56 px |
| 2 | `y lift` | the field rises, 36 px |
| 3 | `field tilt` | 5.5 degree rotation around the lane centre |
| 4 | `inner swap` | the two middle columns trade places, 27 px |
| 5 | `scale squash` | arrows shrink to 84% and recover |
| 6 | `scale puff` | arrows grow to 112% and recover |
| 7 | `drunk sway` | a slow sine sway, 19 px |
| 8 | `sawtooth climb` | notes drift forward and snap back, 39 px |
| 9 | `beat bounce` | the field bounces on the beat, 25 px |
| 10 | `diagonal` | 34 px across with 22 px of lift |
| 11 | `tilt + slide` | 44 px sideways with a 5 degree counter-tilt |
| 12 | `lane pinch` | outer columns relax, inner columns converge, 18 px each |

Two things follow from the cycle:

- because it advances **every block**, the modchart also changes during long
  stretches where only one side sings (bf owns beats 240-384), and
- because each block opens and closes its own move, a percent is never left
  displaced: the validator below proves the arrows are home on every block
  boundary.

Only the side that is singing moves. The other side's playfield is untouched,
which is what makes the hand-over readable: you can always see which half of
the screen is "yours" right now.

Intensity is measured from the chart, not guessed: sections are ranked by notes
per section and the loudest move is 1.00 on sparse hits, while the densest part
of the song (beat 208, 12.5 notes per section) gets 0.60.

## The companion scripts

Every `.lua` in `data/win32modchart/` is loaded automatically
(`PlayState.hx` walks the song folder), so these five files sit **alongside** the
modchart rather than being called by it. Each one is independent: delete the
file and the others keep working. They never write a modchart percent and never
touch `camGame`, which belongs to `win32modchart-erect.lua`.

| File | What it changes | Keys | Off switch |
| --- | --- | --- | --- |
| `w32_bus.lua` | A turn counter under the modchart HUD: `TURN 07/20  YOU`, `OPPONENT`, or `CLIMAX`. Green on your turns, blue on dad's, orange in the climax. | – | always on (it is a read-out, not an effect) |
| `w32-desk.lua` | Desktop framing: a scanline pass on `camOther`, a window title chip with the executable path, CRT side strips, and an "active window" line that brightens on the beat. | `1` cycles the dressing, `2` toggles the scanlines | `modchart` false |
| `w32-chars.lua` | Who the camera is looking at: a dim spotlight behind the owning side with a `YOU` / `OPPONENT` caption, a GF dance step, and a letterbox that closes in for the climax. | – | `modchart` false |
| `w32-play.lua` | Gameplay: a miss guard (the screen dims, three misses in a row puts `MISS x3` up), a `25 COMBO` milestone caption with a camera bump, and scroll-speed control. | `3` faster, `4` slower | `modchart` false |
| `w32-window.lua` | The OS window itself dims a few percent on every note you hit, with a sustain vibrato. | – | `modchart` false |

### The window script is a port, not the original

The well-known "move the window on every note" script drives
`openfl.Lib.application.window.x/y` through `setPropertyFromClass`. Two things
stop that here:

1. `openfl.Lib` is on `ScriptSecurityScanner`'s native-class blacklist
   (`source/backend/ScriptSecurityScanner.hx`), so the engine **refuses the whole
   file** before its first line runs. `tools/simulate_win32_scripts.py` reports
   the finding.
2. The Lua API has no window-position setter. `WindowCallbacks.hx` exposes the
   display mode, the size, transparency and whole-window alpha — not an origin.

So `w32-window.lua` keeps the original's curve, decay, smoothing and sustain
vibrato, and maps them onto `setWindowAlpha` / `getWindowAlpha`, which every
desktop target supports. Measured on the real code:

| | original | port |
| --- | --- | --- |
| punch | window jumps 35 px (4.9 % of the frame) | alpha 0.968 (3.2 % dim) |
| sustain vibrato | ±12 px (1.7 %) | alpha 0.985 (1.5 % dim) |
| both | — | alpha 0.964 (3.6 % dim) |

The punch peaks around 65 % of `moveAmount` because `returnSpeed` starts pulling
the target home on the next frame — true of the original too. Alpha is scalar,
so the punch can no longer tell left from right; direction still picks the axis
for the sustain vibrato, as before. A whole-window brightness change *is* a
flash, so with `flashing` off or `reducedMotion` on this file writes no alpha at
all.

### Shared rules

- **`modchart` gates all four effects.** Set the `modchart` persistent variable
  to `false` and they tear themselves down on the next frame; nothing is
  unloaded, and the turn counter stays.
- **Everything is undone.** Sprites and texts are removed, tweens cancelled,
  `songSpeed` written back to the value the song started with (read before
  anything touched it), and the window alpha restored to what it was. That
  happens on `onEndSong`, on `onGameOver` and on `onDestroy`, so an aborted run
  cannot leave a story week with a dimmed window or a fast scroll speed.
- **Reduced motion** drops the beat brightening, the GF camera shake, the combo
  camera bump and the letterbox easing. **Flashing** off drops the beat
  brightening and disables the window script entirely.
- **Scroll speed** is written through the property (`setProperty` /
  `startTween`), never as a raw field, because the `songSpeed` setter is what
  recomputes `noteKillOffset`.
- **The HUD is checked for collisions**, not eyeballed. The harness compares
  every rectangle these scripts draw against the engine's time bar, health bar
  and score text, and the modchart's own five lines, in **both** scroll
  directions — the modchart read-out moves from y 74 to y 18 when downscroll is
  on.

## The climax

Beats 336-416 are free of hand-overs and are the densest stretch of the song.
The HUD switches to `CLIMAX`, and the desktop joins in through the softmodding
API only:

| Beat | Time | Phase | Calls |
| --- | --- | --- | --- |
| 336 | 1:46 | desktop glitch + titles | `gdiRegisterEffect`/`gdiEnableEffect` `ScreenGlitches` and `SetTitleText`, then `gdiSetTitleText('WIN32MODCHART')` |
| 344 | 1:49 | icons chase the cursor | `DrawIcons` + `ScreenBlink` (blink skipped with flashing off) |
| 352 | 1:51 | tunnel + shake | `ScreenTunnel`, `ScreenShake`, `gdiHppdTrigger(12)` horizontal tearing |
| 360 | 1:54 | fractured screen | `gdiHppdTrigger(16)` plus another glitch sweep |
| 376 | 1:59 | first heavy payload | `gdiHppdTrigger(7)` plasma hue |
| 392 | 2:04 | heaviest colour pass | `gdiHppdTrigger(13)` chromatic plasma |
| 408 | 2:09 | the peak | `gdiHppdTrigger(24)` absolute GDI chaos |
| 408 | 2:09 | wind down | `gdiHppdStopAll`, every effect disabled and unregistered, `gdiDestroy` |

The camera half of the climax (zoom 12%, two ±5 degree rocks, HUD jitter) runs
on every platform, so the section still builds on a build without GDI.

## Layout

```text
mods/win32modchart/
  pack.json
  README.md
  data/win32modchart/
    win32modchart-erect.json   # copied Erect Dad Battle chart, metadata changed
    win32modchart-erect.lua    # the per-turn modchart and the GDI climax
    events-erect.json          # copied camera + spotlight events
    w32_bus.lua                # turn counter (top-left read-out)
    w32-desk.lua               # Windows desktop framing: scanlines, title chip
    w32-chars.lua              # spotlight, captions, GF reaction, letterbox
    w32-play.lua               # miss guard, combo milestones, speed control
    w32-window.lua             # the game window reacts to your notes
  songs/win32modchart/
    Inst-erect.ogg
    Voices-bf-erect.ogg
    Voices-dad-erect.ogg
  weeks/
    win32modchart-week.json
    weekList.txt
```

The audio keeps the `-erect` suffix and the chart keeps
`specialAudioName: ""`, so the engine resolves `Inst-erect` / `Voices-*-erect`
from this mod's `songs/` folder without a rename step. The week file lists
`"difficulties": "Normal,Erect"` because the freeplay and story menus only offer
Erect when it is appended to a difficulty list that already contains Normal.

`project.hxp` bundles this folder for the `windows` tag only
(`BUNDLED_MOD_PLATFORMS`), and `modsList.txt` enables it.

## Safety and accessibility

- **Every GDI payload is torn down** in `onPause`, `onGameOver`, `onEndSong` and
  `onDestroy`. Pausing stops the worker (`gdiSetPaused`), the wind-down at beat
  408 restores the desktop, and `onDestroy` removes the registered effects even
  if the player retries mid-climax.
- The original window titles are written back (`gdiSetTitleText('')`) before the
  effects are unregistered.
- Heavy HPPD payloads serialise on one worker, so the script checks
  `gdiHppdIsHeavy` / `gdiHppdIsRunning` and never queues a second one.
- **Reduced Motion** (`ClientPrefs.reducedMotion`) removes the two rotating moves
  and every camera shake.
- **Flashing** (`ClientPrefs.flashing`) disables the desktop blink sweep.
- Displacement is capped: |x| <= 64 px, |y| <= 40 px, rotation <= 8 degrees,
  scale 0.84-1.12. `invert`/`flip` are deliberately not used - both move a lane
  by a full 112 px, which is too much to read while playing.

## Why the eases are scheduled from callbacks

`ModchartEvent` captures an ease's start value on its **first update**
(`source/modchart/ModchartEvent.hx`). Two eases queued on the same percent would
both capture the value the first one left behind, so a pre-scheduled
open/close pair silently collapses into one move. Each block therefore parks its
percents with `setPercent` and schedules its opening and closing eases from its
own `modCallback` hook, when the block owns the percent and nothing else is
queued on it. Scheduling from the block's *nominal* beat (not the callback's
fire beat) keeps the two legs from ever sharing a frame.

## Validation

`tools/validate_win32modchart.py` runs the real Lua script against a faithful
Python port of `ModchartEvent` / `ModchartEventManager` / `PercentStore` and of
the modifier maths (`Transform`, `Rotate`, `Invert`, `Scale`, `Zoom`, `Drunk`,
`SawTooth`, `Bounce`). It needs `lupa`:

```bash
python3 -m venv /tmp/v && /tmp/v/bin/pip install lupa
/tmp/v/bin/python tools/validate_win32modchart.py
```

It checks the chart metadata, that the turn table matches the chart's real
hand-overs, the `ScriptSecurityScanner` rules, the displacement budgets, ease
overlaps, leftover displacement, that only one side moves at a time, the GDI
teardown, and that the HUD reaches the climax banner.

`tools/simulate_win32_scripts.py` is the companion half. It gives each companion
script its **own** `LuaRuntime` — the engine gives every file its own Lua state —
stubs the engine functions with their real signatures, and drives a whole song
through them: all 104 sections, 416 beats, a combo run, three misses, a sustain,
a pause, a resume and an end. Then it asserts:

- no script raised a runtime error, in six scenarios: defaults, reduced motion,
  flashing off, `modchart` off, no window support, and an aborted run where only
  `onDestroy` fires
- every sprite, text, tween and camera filter is gone afterwards
- `songSpeed` is back on the value the song started with, and the window alpha is
  back to what it was — after the song *and* after a hard destroy
- the window dim stays between 1 % and 12 % (visible, but not a flash) and is not
  written at all when flashing is off
- the HUD rectangles do not overlap the engine's or the modchart's text, in both
  scroll directions
- the scripts created objects during the song, so "nothing left behind" is not
  vacuous
- three mutations are caught: skipping the sprite teardown, the speed restore or
  the window restore each fails the audit

It runs standalone too:

```bash
/tmp/v/bin/python tools/simulate_win32_scripts.py
```

## Manual smoke test

This checkout has no Haxe/Lime toolchain, so the mod has been validated
statically only. In a real Windows build:

1. Play from freeplay on **Erect**; confirm the HUD turn counter walks through
   all twenty turns and the move label changes every four beats.
2. Watch turns 1-8 with a metronome ear: the arrows must be back in place on
   every hand-over.
3. At 1:46 confirm the window titles change, the desktop glitches, and the HUD
   GDI line says `armed`.
4. Pause during the climax: the desktop must stop moving behind the pause menu.
5. Die during the climax, then retry: the desktop must be clean on the retry.
6. Play the whole song on a non-Windows build: the HUD must say `simulated` and
   no GDI call may error.
7. Turn on **Reduced Motion** and confirm no shake and no rotation.
8. Press `1` during the intro: the title chip, the CRT strips and the window
   line must disappear, and `1` twice more must bring them back.
9. Press `2`: the scanlines must toggle without touching the playfield.
10. Press `3` a few times: the `speed` read-out in the left column must climb,
    late notes must still spawn, and the next hand-over must snap it back to the
    chart speed.
11. Hit a note and watch the window: it should dim very slightly for a moment.
    Turn **Flashing** off and confirm it stops dimming entirely.
12. With **Downscroll** on, confirm nothing in the left column lands on the
    modchart's own read-out (it moves from y 74 to y 18).
13. Set the `modchart` variable to `false` mid-song: the dressing, the
    spotlight, the gameplay layers and the window effect must all go away, while
    the turn counter stays and the scroll speed returns to normal.

## Credits

- **Erect Dad Battle**: music and chart by Kawai Sprite; Friday Night Funkin'
  team.
- **Engine**: Phoenix Engine contributors.
- **Mod code**: written for this mod. The chart and event JSON are copied from
  `assets/preload/data/dad-battle/` and re-titled; the audio is copied from
  `assets/songs/dad-battle/`.
