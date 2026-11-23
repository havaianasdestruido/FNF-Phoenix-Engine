# Low Memory Mode / memory profiles

Options → **Optimization** → **Memory Profile** switches on a bundle of
memory-saving settings for devices that are short on RAM. It is Phoenix's take
on Codename Engine's *Low Memory Mode* (`Options > Appearance`), with several
levels instead of one switch. `Off` is the default.

| Profile | What it does | Cleanup |
|---------|--------------|---------|
| `Off` | Nothing. Every option is exactly what you set. | None |
| `Low` | Caps note splashes at 4 and turns off the moving menu checkerboard. | Trims unused assets after songs, on focus loss, and every 45 s outside gameplay. |
| `Extreme` | Everything `Low` does, plus Low Quality stages, no note splashes, shaders, anti-aliasing or camera bop zooms. | Also releases caches when PlayState is destroyed; trims every 20 s outside gameplay. |
| `Experimental Extreme` | Everything `Extreme` does, plus a HUD-only song view, GPU texture caching, enabled GC, no note color shader, popups, NPS history, diagnostic overlays, menu tips or Discord RPC. Skips speculative song preloads and tries to stream song audio. | Releases old caches before a song loads, retains the `Extreme` hooks, trims every 5 s outside gameplay and requests heap compaction on every trim. |
| `Arduino Nano R3` | Joke-named ATmega328P ("2 KB SRAM @ 16 MHz") tier that goes strictly beyond `Experimental Extreme`: hides all HUD/time-bar/watermark furniture, disables extra vocal stems, pause music, hitsounds/miss SFX/metronome/haptics, camera flashes/motion/CrossFade trails, per-note Lua/Python/HScript callbacks (`noSpawnFunc` / `noHitFuncs` / `noSkipFuncs`), switches `Alphabet` to GPU-cached spritesheets instead of 8 MB CPU font glyph pages, strips menu/title/Freeplay/Story/countdown ornament art and fade transitions, and caps menus to 15 FPS (1 FPS unfocused) while keeping gameplay FPS, scroll, note speed and hit windows untouched. | Everything `Experimental Extreme` does, plus unpins `Paths.dumpExclusions` so menu/pause audio is evicted during songs, drops dynamic font glyph pages, and runs an explicit full mark-and-sweep GC + heap compaction every **1 s** outside gameplay. |

## Experimental Extreme: compatibility warning

This tier is **experimental** and prioritizes RAM over appearance, loading time,
and compatibility. Stages and character scripts may not run, character-specific
behavior and mod effects may change, and some mods can break. GPU caching can
increase VRAM use or cause missing/broken graphics on older GPUs or with mods
that need CPU-readable pixels. Skipping preloads and more frequent garbage
collection/compaction can cause longer loads or stutters. Streaming can also
cause audio hiccups or synchronization issues on slow storage. Try `Extreme`
or `Off` if anything goes wrong; start/restart the song for stage, texture and
audio changes to take effect.

The goal is the smallest practical **system RAM** footprint, not a guaranteed
number. GPU caching applies to newly loaded textures and only where a GPU
context is available; VRAM or shared GPU memory may increase. The engine tries
to stream each instrumental and vocal with a separate Vorbis decoder on native
OpenAL/Vorbis builds with accessible, seekable `.ogg` files. MP3s, embedded
assets without a file path, web/Flash, unsupported builds and failed streams
fall back to the normal decoder. No note visibility, input, scroll direction,
speed, hit-window or script-dispatch preference is forced, but removing
stages/characters can still change mod-specific mechanics. FPS/RAM overlays and
the pause-menu RAM graph are disabled while this tier is active; the
diagnostics page remains available.

Experimental songs use tiny invisible character stand-ins. They read character
JSON for vocal-stem selection, health icons/colors, drain settings and note
skins, without loading character atlases or character scripts. Stage JSON remains
available for pixel notes and countdowns, but stage visuals and stage scripts are
skipped. A character-specific note skin is used only when its stage-appropriate
assets are complete; otherwise notes and receptors use the chart's original
skin. Separate and difficulty-specific event charts remain enabled, including
when packaged as OpenFL assets. General song/event scripts are still supported,
but may depend on the missing visuals or character scripts. Restart after
changing profiles:
its stage, character representation, visual animations and character-event mode
are chosen at song creation.

## Your own settings are not overwritten

A profile is an **override layer**, not a rewrite:

* Turning a profile on snapshots your current values for the preferences it
  manages (into `ClientPrefs.memoryProfileBaseline`, a small JSON blob) and then
  forces the profile's values.
* Switching to a different tier restores the old snapshot before capturing the
  new one. Choosing `Off` restores the snapshot and forgets it.
* `ClientPrefs.saveSettings()` restores your values before writing `funkin.sol`
  and re-applies the profile afterwards, so a forced value never becomes your
  saved choice.
* Settings export/import (`Export Settings (.json)`) writes and reads *your*
  values, not the forced ones; the baseline blob itself is not part of a backup.

While a profile is on, the managed options show the forced value in the Options
list. Changing one of them has no lasting effect — pick `Off` first if you want
to choose those values yourself, or use a lower profile. The pause-menu RAM
graph toggle is locked while a profile manages it.

## What is actually freed

Cleanup uses the existing `Paths` cache routines:

* `Paths.clearUnusedMemory()` drops tracked images and sounds not marked as
  locally used or excluded. Skin-template sprites are released before an
  unused atlas is checked; an atlas with a live Flixel graphic user is kept.
  Flixel-owned sounds, including paused music and sounds, remain usable.
  Request-based local tracking is not a complete account of external mod
  references, so this is still best effort.
* `Paths.clearStoredMemory()` resets local tracking and clears additional
  unused bitmap-cache entries; a following unused pass releases the newly
  untracked assets. Deep profile cleanup is scheduled at state teardown, not
  periodically against a live options menu or song.
* On experimental song exit, the song's persistent instrumental is stopped and
  released only if menu or other music has not replaced it. Stream cache
  entries are dropped without forcibly closing externally held sounds; their
  native decoders can be reclaimed after all owners release them and GC runs.
  If the profile was disabled mid-song, one final teardown still retires that
  song's experimental resources.
* `Paths.compress()` runs after each experimental trim even if no asset was
  evicted. Compaction is platform-dependent and may cause noticeable pauses.

| Hook | Where | Policy |
|------|-------|--------|
| Song end | `PlayState.endSong()` → `LowMemory.onSongEnd()` | Shallow trim for all active profiles |
| PlayState teardown | `PlayState.destroy()` → `LowMemory.onPlayStateExit()` | Deep cleanup for `Extreme`, `Experimental Extreme` and `Arduino Nano R3` |
| Entering a song | `PlayState.create()` | `Experimental Extreme` and `Arduino Nano R3` clear old unused assets before loading new ones; `Arduino Nano R3` also skips silent SFX/alphabet warm-ups, countdown sprites, credit popups and receptor intro tweens |
| Window/app backgrounded | `FlxG.signals.focusLost` (registered in `InitState`) | Shallow trim for all active profiles, throttled to one per second and skipped during LoadingState |
| Outside gameplay | `MusicBeatState.update()` → `LowMemory.update(elapsed)` | Periodic shallow trim (45 s / 20 s / 5 s / 1 s); `Arduino Nano R3` also runs a full major GC + font-atlas clear before heap compaction; skipped in PlayState and LoadingState |
| Android memory pressure | `AndroidPlatform.releaseCaches()` → `LowMemory.onSystemPressure()` | Logged for every profile. Pressure during LoadingState is coalesced and drained with a shallow trim after loading; elsewhere `Experimental Extreme` and `Arduino Nano R3` use a shallow trim and other profiles retain the existing deep cleanup. |

The experimental song-loading screen does not preload speculative characters,
HUD variants, audio or dialogue, and gameplay does not warm popup art or a
regular noteskin atlas for pixel stages. Assets that are actually needed still
load on demand. The title screen retains its normal preloads. No periodic deep
clear is run against live gameplay or menus.

## Scripting

`memoryProfile` and `lowMemoryMode` are published to Lua, Python/Hython and
HScript alongside `lowQuality`:

```lua
function onCreate()
    debugPrint('memory profile: ' .. memoryProfile .. ' (active: ' .. tostring(lowMemoryMode) .. ')')
end
```

`lowMemoryMode` is derived: it is `true` for all four active tiers (`Low`,
`Extreme`, `Experimental Extreme` and `Arduino Nano R3`), and is
kept so older mods that check the old field keep working. Do not set it directly
— pick a profile instead:

```lua
-- Runtime override, e.g. from a "reduce RAM" button in a pause script.
runHaxeCode([[
    backend.LowMemory.setProfile('Arduino Nano R3', true);
]])
```

`backend.LowMemory.trim(false)` releases unused cached assets immediately (same
as the **Free Memory Now** option); `trim(true)` is the deep variant and is only
safe while a state is entering or leaving. `backend.LowMemory.current()` and
`backend.LowMemory.statusLine()` read the active profile.

## Where the code lives

| File | Role |
|------|------|
| `source/backend/MemoryProfiles.hx` | Pure data: ids, aliases, overrides, policies and baseline codec. No Flixel imports. |
| `source/backend/LowMemory.hx` | Applies/restores overrides, save-window handling, cleanup policy and runtime hooks. |
| `source/backend/SongAudioStreaming.hx` / `Paths.hx` | Best-effort independent Vorbis streams, decoder fallbacks, and live-safe cache/template cleanup. |
| `source/states/LoadingState.hx` / `LoadingStateRouter.hx` | Deferred target construction and experimental no-preload queue. |
| `source/play/` / `source/objects/Character.hx` | Metadata-only characters, stage/skin selection, song playback and teardown. |
| `source/options/OptimizationSubState.hx` | The `Memory Profile` dropdown and the `Free Memory Now` action. |
| `source/backend/ClientPrefs.hx` | `memoryProfile`, `memoryProfileBaseline`, and the legacy `lowMemoryMode` mirror. |
| `source/backend/DiagnosticsReport.hx` | Reports the active profile and its policy. |

## Tests

With Haxe, Python 3 and Node available, the dependency-light suites exercise
production code against stubs (the chart and router suites also run on JS):

```sh
bash tests/haxe/run-memory-profiles.sh       # includes song-audio routing/fallbacks
bash tests/haxe/run-asset-cache.sh           # includes character-file lookup
bash tests/haxe/run-song-character-info.sh
bash tests/haxe/run-loading-state-router.sh
bash tests/haxe/run-chart-loading.sh
bash tests/haxe/run-chart-loader.sh
bash tests/haxe/run-diagnostics-report.sh
```

For optional Linux/Neko integration smokes, set `LIME_PATH`, `OPENFL_PATH`,
`FLIXEL_PATH`, `FLIXEL_ADDONS_PATH`, `FLIXEL_UI_PATH` and `TJSON_PATH` to the
project's installed library roots (see `hmm.json` and [BUILDING.md](../BUILDING.md)).
Set `HAXE` and `NEKO` if the executables are not on `PATH`; Lime's Linux64
native `lime.ndll` is required. Then run:

```sh
bash tests/haxe/run-song-character-flixel-smoke.sh
bash tests/haxe/run-song-audio-native-smoke.sh
bash tests/haxe/run-playstate-memory-flixel-smoke.sh
```

The last runner typechecks the production gameplay path for C++ with and without
`MODS_ALLOWED`, plus an Android-defined variant, using `--no-output`. It then
exercises real LoadingState/PlayState transitions for Bopeebo and the pixel-stage
Senpai chart, note/skin lifetime, streamed playback, profile changes and restarts.
The Neko runs use a temporary FlxBar initialization shim, dummy SDL video and
OpenAL null audio; they do not enable Lua/Python/HScript or Android. These tests
are **not** a full build, a complete playthrough, an audible-device audio test,
a hardware GPU test or an Android-device test;
validate representative mods and target devices separately.

## Adding a profile or a managed option

1. Add the value to `MemoryProfiles.NAMES` and a `build()` branch, or extend
   an existing override map.
2. Only manage preferences the player can live without during a song (visual
   extras, splash limits, stage detail). Never force scroll direction, note
   speed, hit windows or anything that directly changes how a chart plays.
3. Run `bash tests/haxe/run-memory-profiles.sh`; the static guard picks the new
   key up automatically.
