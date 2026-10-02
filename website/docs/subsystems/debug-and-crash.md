---
title: Debugging & crash handling
sidebar_position: 9
description: The FPS/memory overlay, crash handler and error state, Discord RPC and build metadata.
---

# Debugging & crash handling

## FPS and memory overlay

`debug.FPSCounter` (created in `Main.setupGame()` as `Main.fpsVar`) shows framerate and,
optionally, RAM and peak RAM. Driven by:

| Preference | Effect |
|---|---|
| `showFPS` | show the counter at all |
| `showRamUsage` / `showMaxRamUsage` | add current / peak memory |
| `debugInfo` | extra diagnostics |

Memory numbers come from `debug.Memory` and `utils.MemoryUtil`; `debug/mem/` contains a
small C++ include (`GetTotalMemory.hx` + `build.xml`) for an accurate native figure.

Two optimizations to preserve: the PlayState check is cached (`Main.isPlayState()`) rather
than re-running `Std.isOfType` each frame, and the text outline redraw is throttled.

## Crash handling

With `CRASH_HANDLER` enabled (the default), `backend.CrashHandler.init()` runs before the
game is created and installs an OpenFL uncaught-error handler. On a crash it writes a log
and shows `states.ErrorState` instead of killing the window.

The readable native stack traces come from defines set in `project.hxp`:
`openfl-enable-handle-error`, `HXCPP_CHECK_POINTER`, `HXCPP_STACK_LINE`,
`HXCPP_STACK_TRACE`, `HXCPP_CATCH_SEGV`.

`ClientPrefs.peOGCrash` switches to the plain Psych-style crash dialog for users who
prefer it. `CoolUtil.coolError(message, title)` is the engine's own error popup, used for
recoverable problems (for example opening the Note Colors menu with the feature off).

## Script errors

Lua, Python and HScript errors never take the game down:

- `shaders.ErrorHandledShader` catches shader compile failures.
- `psychlua.DebugLuaText` prints script errors and `debugPrint(...)` output on screen,
  through `luaDebugGroup` / `pythonDebugGroup` in `PlayState`.
- Script hosts catch exceptions per call, so one broken hook does not stop the others.

## Build metadata

`backend.HaxeCommit` exposes the git branch/commit the build came from (printed by
`project.hxp`'s `flair()` at build time), which is what crash reports and the title screen
can show. `VERSION` in `project.hxp` is the single source of the version string.

## Discord Rich Presence

`backend.DiscordClient` (flag `DISCORD_ALLOWED`, library `hxdiscord_rpc`) publishes the
current state and song. It is toggled by `ClientPrefs.discordRPC`, scripts can change it
with `changePresence(...)`, and option menus set an `rpcTitle`. On Android the equivalent
is routed through `android.platform.AndroidDiscord`.

## Profiling and experimental builds

| Define | Effect |
|---|---|
| `-DDEBUG_TRACY` / `FEATURE_DEBUG_TRACY` | Tracy profiler instrumentation |
| `-DULTRA_OPTIMIZED` | experimental maximum-speed configuration |
| `-DULTRA_HTML5` | experimental web optimization |
| `-debug` | Flixel/Haxe debug build, enables `#if debug` blocks |

## Tracing conventions

Unconditional `trace()` calls were deliberately removed from hot paths. New ones belong
inside `#if debug`:

```haxe
#if debug
trace('loaded ${notes.length} notes');
#end
```

## Screenshots

`backend.Screenshot` plus the `backend.SSPlugin` Flixel plugin (added in
`Main.setupGame()`) capture the window to disk without going through the OS.
