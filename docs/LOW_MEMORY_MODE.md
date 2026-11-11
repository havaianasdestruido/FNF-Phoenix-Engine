# Low Memory Mode / memory profiles

Options → **Optimization** → **Memory Profile** switches on a bundle of
memory-saving settings for devices that are short on RAM. It is Phoenix's take
on Codename Engine's *Low Memory Mode* (`Options > Appearance`), with two levels
instead of one switch.

| Profile   | What it does | Cleanup |
|-----------|--------------|---------|
| `Off`     | Nothing. Every option is exactly what you set. | None |
| `Low`     | Caps note splashes at 4 and turns off the moving menu checkerboard. | Unused assets freed after every song, when the window loses focus, and every 45 s while idle in a menu. |
| `Extreme` | Everything `Low` does, plus: Low Quality stages, no note splashes, no shaders, no anti-aliasing, no camera bop zooms. | Everything `Low` does, plus a deep release when a song's PlayState is destroyed, and an idle pass every 20 s. |

`Off` is the default, so an existing install behaves exactly as before until the
option is touched.

## Your own settings are not overwritten

A profile is an **override layer**, not a rewrite:

* Turning a profile on snapshots your current values for the preferences it
  manages (into `ClientPrefs.memoryProfileBaseline`, a small JSON blob) and then
  forces the profile's values.
* `ClientPrefs.saveSettings()` restores your values before writing `funkin.sol`
  and re-applies the profile afterwards, so a forced value never becomes your
  saved choice.
* Choosing `Off` restores the snapshot and forgets it.
* Settings export/import (`Export Settings (.json)`) writes and reads *your*
  values, not the forced ones; the baseline blob itself is not part of a backup.

While a profile is on, the managed options show the forced value in the Options
list. Changing one of them has no lasting effect — pick `Off` first if you want
to choose those values yourself, or use a lower profile.

## What is actually freed

Everything goes through the calls the menus already use:

* `Paths.clearUnusedMemory()` — drops tracked images and sounds that no live
  sprite or sound references, then runs the GC (`Paths` handles that).
* `Paths.clearStoredMemory()` — the deep variant: also drops cached bitmap/sound
  entries and song audio, then GCs. It disposes engine-generated bitmaps too, so
  it only runs when a state is already going away (`PlayState.destroy`), never
  from a live options menu.

Hooks, in order of how often a player will hit them:

| Hook | Where | Policy |
|------|-------|--------|
| Song end | `PlayState.endSong()` → `LowMemory.onSongEnd()` | `trimOnSongEnd` (`Low`, `Extreme`) |
| PlayState teardown | `PlayState.destroy()` → `LowMemory.onPlayStateExit()` | `releaseOnPlayStateExit` (`Extreme`) |
| Window/app backgrounded | `FlxG.signals.focusLost` (registered in `InitState`) | `trimOnFocusLost` (`Low`, `Extreme`) |
| Idle in a menu | `MusicBeatState.update()` → `LowMemory.update(elapsed)` | `idleTrimSeconds` (45 s / 20 s) |
| Android memory pressure | `AndroidPlatform.releaseCaches()` → `LowMemory.reportSystemPressure()` | Always releases (existing Android behaviour); the report is logged against the active profile |

None of these touch graphics that are currently on screen, so they cannot blank
a stage mid-song. Idle trims are skipped while a `PlayState` is the active state,
and signal-driven trims are throttled to one per second.

## Scripting

`memoryProfile` and `lowMemoryMode` are published to Lua, Python/Hython and
HScript alongside `lowQuality`:

```lua
function onCreate()
    debugPrint('memory profile: ' .. memoryProfile .. ' (active: ' .. tostring(lowMemoryMode) .. ')')
end
```

`lowMemoryMode` is derived: it is `true` for `Low` and `Extreme`, and is kept so
older mods that check the old field keep working. Do not set it directly — pick
a profile instead:

```lua
-- Runtime override, e.g. from a "reduce RAM" button in a pause script.
runHaxeCode([[
    backend.LowMemory.setProfile('Extreme', true);
]])
```

`backend.LowMemory.trim(false)` releases unused cached assets immediately (same
as the **Free Memory Now** option); `trim(true)` is the deep variant and is only
safe while a state is entering or leaving. `backend.LowMemory.current()` and
`backend.LowMemory.statusLine()` read the active profile.

## Where the code lives

| File | Role |
|------|------|
| `source/backend/MemoryProfiles.hx` | Pure data: profile ids, aliases, overrides, cleanup policy, baseline codec (`encodeBaseline`/`decodeBaseline`/`coerce`). No Flixel imports. |
| `source/backend/LowMemory.hx` | Applies/restores the overrides, save-window handling, cleanup policy, runtime hooks. |
| `source/options/OptimizationSubState.hx` | The `Memory Profile` dropdown and the `Free Memory Now` action. |
| `source/backend/ClientPrefs.hx` | `memoryProfile`, `memoryProfileBaseline`, and the legacy `lowMemoryMode` mirror. |
| `source/backend/DiagnosticsReport.hx` | The diagnostics page reports the active profile and its policy. |

## Tests

```sh
bash tests/haxe/run-memory-profiles.sh
```

The spec (`tests/haxe/MemoryProfilesSpec.hx`) runs in the Haxe interpreter with
no stubs: aliases and unknown values, override contents, `Extreme` being at
least as strict as `Low`, the baseline round trip, junk baselines being ignored,
and the type coercion that keeps an `Int` preference an `Int` across JSON.

The same script greps `source/backend/ClientPrefs.hx` for every preference a
profile forces and checks the literal's type, so renaming a preference fails CI
instead of leaving half a profile doing nothing. `run-diagnostics-report.sh`
covers the new `Memory profile` row.

## Adding a profile or a managed option

1. Add the value to `MemoryProfiles.NAMES` and a `build()` branch, or extend
   `lowOverrides()` / `extremeOverrides()`.
2. Only manage preferences the player can live without during a song (visual
   extras, splash limits, stage detail). Never force scroll direction, note
   speed, hit windows or anything that changes how a chart plays.
3. Run `bash tests/haxe/run-memory-profiles.sh`; the static guard picks the new
   key up automatically.
