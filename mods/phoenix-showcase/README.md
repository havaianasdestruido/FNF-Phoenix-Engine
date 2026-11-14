# Phoenix Feature Tour

A bundled demo mod for **Phoenix Engine**. It turns **Erect Dad Battle** into a
guided tour of the engine's newer systems: the Lua modchart API, both modchart
playfields, 3D perspective, runtime and built-in shaders, custom cameras, HUD
hooks, save data, and an optional fourth-wall section built on `META_HORROR`.

The mod ships inside `mods/phoenix-showcase/`, is listed in `modsList.txt`, and
is bundled by `project.hxp` for **desktop and mobile** targets. It does not
modify any `assets/` file.

- **Week / freeplay entry:** Phoenix Feature Tour
- **Song:** Phoenix Feature Tour (Erect)
- **Base chart and audio:** Erect Dad Battle, chart by Kawai Sprite
- **Length:** about 2:10 at 190 BPM
- **Modchart language:** Lua only (no Python/HScript in this mod)

## How to run it

1. Launch the game and open **Freeplay**.
2. Pick the **Phoenix Feature Tour** week and the **Erect** difficulty.
3. The intro HUD shows the runtime feature probe:
   `shaders=...`, window alpha support, META_HORROR status.

`pack.json` enables the script sandbox. The mod uses **no** allowlisted file,
clipboard, window-list, or screen-capture calls, so it works with
`scriptSandbox: true` and an empty `scriptSandboxAllowlist`.

### Enabling the optional fourth-wall section

The song always works. The real window tricks need a build compiled with the
engine's opt-in define:

```bash
lime test windows -DMETA_HORROR
```

Without `META_HORROR`, `setWindowTitle()` returns `false`; the mod detects that
and explicitly labels the phase as a safe no-op instead of calling the rest of
the 4th-wall functions. With `META_HORROR`, the script only performs the
intrusive taskbar gag when `isRecording()` is false. Because `isRecording()`
fails open (returns `true` when it cannot read the process list), a streamer-safe
fallback is the default.

Whole-window alpha is a separate subsystem (`TransparentWindow`). It is gated by
`isWindowTransparencySupported()`, so mobile/web simply skip it.

## What is tested, and where

All 34 names in `ModifierRegistry` are installed at song start and every one is
marked off the HUD counter. The phases are 16 beats each.

| Beats | Phase | What it proves |
| --- | --- | --- |
| 0-15 | Intro | loading art, HUD text, logo tween, hardware globals, save counter |
| 16-31 | Timeline | `modSet`, `modEase`, `modAdd`, `modSetAdd`, `modCallback`, `modRepeater`, lane-specific `x0` |
| 32-47 | Scroll | `reverse`, `xmod`, `boost`, `brake`, `receptorScroll`, `zigZag` |
| 48-63 | Drunk family | `drunk`, `tipsy`, `schmovinDrunk`, `schmovinTipsy`, `drugged` |
| 64-79 | Geometry | `bounce`, `beat`, `bumpy`, `sawtooth`, `square`, `tornado`, `schmovinTornado` |
| 80-95 | Rotation | `rotate`, `centerRotate`, `fieldRotate`, `localRotate`, `confusion`, `counterClockWise` |
| 96-111 | Lanes | `invert`, `opponentSwap`, `spiral`, `infinite`, `radionic` |
| 112-127 | Scale / stealth | `scale`, `zoom`, `stealth`, `alpha` |
| 128-143 | 3D | `setModchartPerspective(true, fov, zScale)`, `z`, `rotateX/Y`, player-only offset |
| 144-159 | Shaders | `showcase.frag` + `#pragma include`, uniform tweens, chromatic, glitch, scanline, VCR, distant notes, bloom |
| 160-175 | 4th wall: window | `setWindowTitle`, `setAlwaysOnTop`, `flashTaskbar`, `hideTaskbar`/`restoreTaskbar`, persistent values, recording check |
| 176-191 | 4th wall: player | custom `FlxCamera` fake-desktop overlay, username, clock, uptime, `isLateNight`, window alpha |
| 192-207 | HUD | health/time bar colors, `onRecalculateRating` override, `cameraFlash`, `cameraShake`, HUD zoom, early/late readout |
| 208-223 | Cameras / sprites | `createCamera`/`addCamera`/`removeCamera`, `setObjectCamera`, sprites, blend modes, scroll factors, tweens |
| 224-239 | Audio | tagged `playSound`, `soundFadeOut`, `getSoundVolume`, `setPlaybackSpeed` 1.03 -> 1.0 |
| 240-255 | Playfield 2 | `addPlayfield()` + field-specific `modEase(..., field=1)` layered on field 0 |
| 256-271 | Chaos | `wiggle`, `vibrate`, `skewX`, `skewY` - registry reaches 34/34 |
| 272-287 | 3D finale | deep perspective + rotation + player-only translation |
| 288-303 | Combo | eight modifiers at once |
| 304-319 | Finale build | rising drunk/tipsy/bounce/scale, bloom, chromatic |
| 320-335 | Finale drop | `z` 160, glitch, chromatic, camera flash and shake |
| 336-351 | Cooldown | all percents returned to neutral, filters cleared |
| 352-367 | Reset check | `resetModchart()` and `isModchartActive()` |
| 368-383 | Engine info | hardware globals, play counter, `tour runs` persistent value |
| 384-399 | Credits | banner / text API |
| 400-415 | Cleanup | every optional system restored, `onDestroy` removes the camera |

Also exercised:

- custom screen shader warm-up via `stages/phoenix-showcase.json`'s
  `"shaders": ["showcase", ...]`, so gameplay does not compile it on the first
  frame
- `onEvent` / `Dadbattle Spotlight` in the stage script, driven by the copied
  `events-erect.json`
- per-mod save data (`plays`, `completed`, `early`, `late`, `lastModifiers`)
- `Function_Stop` / `Function_Continue` in `onRecalculateRating`
- sprite removal, camera removal, tween/timer cancellation, sound cleanup

## Layout

```text
mods/phoenix-showcase/
  pack.json
  README.md
  data/phoenix-feature-tour/
    phoenix-feature-tour-erect.json   # copied Erect Dad Battle chart, metadata changed
    phoenix-feature-tour-erect.lua    # the whole tour
    events-erect.json                 # copied camera + spotlight events
  songs/phoenix-feature-tour/
    Inst-erect.ogg
    Voices-bf-erect.ogg
    Voices-dad-erect.ogg
  stages/
    phoenix-showcase.json             # stage layout + shader warm-up list
    phoenix-showcase.lua              # stage art, beat pulse, spotlight event
  shaders/
    showcase.frag
    include/scanline.glsl
  images/
    showcase/stage.png                # generated stage background
    loading/phoenix-feature-tour.png  # generated loading art
  weeks/
    phoenix-showcase-week.json
    weekList.txt
```

The audio keeps the `-erect` suffix and the chart keeps
`specialAudioName: ""`, so the engine resolves `Inst-erect` / `Voices-*-erect`
from this mod's `songs/` folder without a rename step.

## Engine-side change needed for custom cameras

`createCamera()` already stored new cameras in `PlayState.variables`, but
`LuaUtils.cameraFromString()` only recognized `camGame`, `camHUD`, `camNotes`
and `camOther`. That meant `setObjectCamera(sprite, 'myCamera')` silently fell
back to `camGame`.

This branch changes `cameraFromString()` to return a camera from the state's
variable map first. Existing names keep their behaviour; custom names now work
with `setObjectCamera`, `cameraFlash`, `cameraShake`, `addShaderToCamera` and
anything else that resolves a camera by name.

## Safety / accessibility notes

- The fourth-wall window effects are **opt-in at build time**. Without
  `META_HORROR` every call is a no-op.
- `isRecording()` fails open. The mod treats `true` as "do not hide the taskbar".
- The title, always-on-top and taskbar state are restored with
  `restoreAllMetaEffects()` at the end of the section, on song end, on game over,
  and on `onDestroy` (retry/quit).
- `setWindowAlpha` can leave fullscreen on some desktops; the mod restores alpha
  to `1.0` in the same cleanup paths.
- The mod does **not** swap the wallpaper, kill wallpaper apps, hide all windows,
  capture the desktop, or touch the clipboard.
- Shader phases are skipped when the user has shaders off, and the HUD says so.
- Camera shakes are skipped when the user has **Reduced Motion** enabled
  (`ClientPrefs.reducedMotion`); flashes still follow the flashing setting.
- The top-left HUD block moves below the time bar in upscroll, and the bottom
  status line moves above it in downscroll.
- `addDistantNoteEffect` is a camera filter; it looks best with Middlescroll, and
  it is only active for one phase. The proper per-note camera layer is the
  engine's **Options -> Visuals and UI -> Distant Notes** option.

## Testing checklist

Because this checkout does not ship a Haxe/Lime toolchain, the mod was validated
statically (JSON parse, Lua parse, registry-name comparison, file layout) and
should be smoke-tested in a real build:

1. Boot with shaders on and off; confirm no Lua errors and the shader phase
   switches to its text-only fallback.
2. Play from freeplay at Erect; watch the HUD counter reach `34/34`.
3. Pause/retry during the 4th-wall section; confirm the title, taskbar,
   always-on-top and window alpha return to normal.
4. Build once without `-DMETA_HORROR`; confirm the phase reports
   `META_HORROR: OFF` and does not error.
5. Build once with `-DMETA_HORROR`; confirm the title changes at ~0:50 and the
   taskbar is restored at ~0:53.
6. Try a 21:9 window; the stage art is cover-scaled and the HUD is fixed.
7. Enable **Distant Notes** separately and confirm the engine's `camNotes` layer
   works alongside (or instead of) the demo's one-phase filter.

## Credits

- **Erect Dad Battle**: music/chart by Kawai Sprite; Friday Night Funkin' team.
- **Engine**: Phoenix Engine contributors.
- **Demo code, stage art and loading art**: written/generated for this mod.
- The base audio files are copied from the repository's existing
  `assets/songs/dad-battle/` erect stems; the chart/event JSON is copied from
  `assets/preload/data/dad-battle/` and re-titled.
