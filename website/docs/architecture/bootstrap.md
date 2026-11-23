---
title: Boot sequence
sidebar_position: 3
description: Everything that happens between main() and the title screen.
---

# Boot sequence

## `Main`

`source/Main.hx` is the OpenFL entry point (`MAIN_CLASS` in `project.hxp`). It is a plain
`openfl.display.Sprite` added to `Lib.current`:

```haxe
public static function main():Void {
  backend.CommandLine.load();
  if (answerInformationRequest()) return; // --help / --version print and exit 0
  Lib.current.addChild(new Main());
}
```

`backend.CommandLine` parses the launch arguments with
[docopt-ng](https://lib.haxe.org/p/docopt-ng/) before a window exists, and the
resulting record is read all through the boot: window mode and framerate in
`new Main()`, the first screen in `InitState`, plus the frame profiler, the
verbose log and the `phoenix://` links. A launch option applies to that session
only — nothing is written to the save file — and an argument the parser cannot
use never stops the boot. See
[Launch options](../getting-started/running-and-debugging.md#launch-options) and
`docs/CLI.md`.

### `__init__()` — before anything exists

Under `GAMEMODE_ALLOWED` (Linux desktop), requests Feral GameMode. Failure is non-fatal:
`gamemoded` may simply not be installed. `Main.shutdownGameMode()` releases it on exit.

### `new Main()`

In order:

1. `backend.deeplink.DeepLinks.init()` — arms the native callbacks and queues the
   `phoenix://` links `backend.CommandLine` collected from the arguments (or built from
   `--song` / `--mod`, unless `--no-deeplinks` withholds them), so a link that launched
   the app is queued before any state exists. It registers nothing: on Windows the scheme
   is claimed by the player from Options → Misc ("Toggle Deeplink").
2. **Mobile only**: `mobile.StorageUtil.requestPermissions()`, then on Android
   `android.platform.AndroidPlatform.init()` (lifecycle, media session, audio focus,
   gamepads, memory handling), then `Sys.setCwd(StorageUtil.getStorageDirectory())` so all
   relative paths resolve inside the app's storage.
3. `CrashHandler.init()`.
4. **Windows only**, via inline C++: `SetProcessDPIAware()` (crisp visuals),
   `SetConsoleOutputCP(CP_UTF8)` (correct console encoding) and
   `DisableProcessWindowsGhosting()` (the window stays movable when busy). The build pulls
   in `wininet.lib` and `dwmapi.lib` through `@:buildXml`.
5. The launch options that shape the window: `--fps=<n>` sets the rate `FlxGame` boots
   with, and `--windowed` / `--fullscreen` / `--borderless` override the saved window mode
   for this session (`ClientPrefs.applyWindowModePreference` applies borderless once the
   window exists).
6. `setupGame()`.

### `setupGame()`

- Computes zoom/size from the stage for older OpenFL versions.
- `ClientPrefs.loadDefaultStuff()` and, under `ACHIEVEMENTS_ALLOWED`, `Achievements.load()`.
- Constructs **`backend.FunkinGame`** (a `FlxGame` subclass) at 1280×720, 60 FPS,
  `skipSplash = true`, initial state `states.InitState`.
  On mobile with mods enabled, the initial state becomes `mobile.CopyState` instead when
  `CopyState.checkExistingFiles()` reports that assets still need to be copied to storage.
- Adds `debug.FPSCounter` (`Main.fpsVar`) and the screenshot plugin (`backend.SSPlugin`).

`Main.instance` is the global handle; `Main.isPlayState()` is the cheap check the FPS
counter and others use instead of repeated `Std.isOfType` calls.

:::note[--troll]

`Main.superDangerMode` is `true` when the executable is launched with `--troll`; the
historical `-troll` spelling is normalized to it by `backend.CommandLine`. Targets
without a command line — web, Flash, AIR — can never set it.

:::

## `states.InitState`

A bare `FlxState` whose only job is first-run initialisation:

| Step | What it does |
|---|---|
| Flixel setup | `FlxG.game.focusLostFramerate = ClientPrefs.focusLostFramerate` (60 by default), mute/volume keys from `TitleState`, `preventDefaultKeys = [TAB]`, `fixedTimestep = false`. The game runs at 1280×720 with `menuFramerate` (60 by default); `play.PlayState` keeps `framerate` |
| Save binding | `FlxG.save.bind('funkin', CoolUtil.getSavePath())` |
| Input | `PlayerSettings.init()` |
| Preferences | `ClientPrefs.loadPrefs()` |
| Mods | `Mods.pushGlobalMods()` (under `MODS_ALLOWED`), then `Mods.loadTopMod()` so a mod can replace menu music/backgrounds from the very first frame |
| Memory | `Paths.clearStoredMemory()` + `Paths.clearUnusedMemory()` |
| Hand-off | `backend.LaunchState.resolve(ClientPrefs.disableSplash, --freeplay, --menu)` → `FreeplayState`, `MainMenuState`, `LoadingState(TitleState)` or `StartupState` (the boot loading screen sits between the splash and the title screen). The two options are the runtime twins of the `-DFREEPLAY` / `-DMENU` build flags and go through the same resolver |

## `states.StartupState` → `states.TitleState`

`StartupState` is the engine splash; pressing `ENTER`/accept, or letting it finish, moves
to `TitleState` through `LoadingState` (the boot loading screen). With *disable splash*
enabled (the default), `InitState` goes straight to `LoadingState` and then `TitleState`.

`TitleState` then either:

- goes to `states.FlashingState` (the flashing-lights warning) on a first run,
- goes to `states.OutdatedState` when `CHECK_FOR_UPDATES` finds a newer release,
- or goes to `states.MainMenuState`.

```mermaid
flowchart LR
    M["Main"] --> I["InitState"]
    I -->|"disableSplash"| L["LoadingState"] --> T["TitleState"]
    I --> S["StartupState"] --> L
    T --> F["FlashingState"] --> MM["MainMenuState"]
    T --> O["OutdatedState"] --> MM
    T --> MM
```

Deep links queued by `DeepLinks.init()` are consumed once the menu states exist — see
[Deep links](../subsystems/deep-links.md).

## Shutdown

- `Main.shutdownGameMode()` releases GameMode.
- `ClientPrefs.saveSettings()` persists preferences through `FlxG.save`.
- The Android platform layer unregisters its media session via `AndroidPlatform`.
