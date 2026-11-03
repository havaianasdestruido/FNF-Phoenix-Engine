---
title: Debugging & crash handling
sidebar_position: 9
description: The verbose vlog, FPS/memory overlay, crash handler and error state, Discord RPC and build metadata.
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

### Hardware information in the crash log

Every crash log (`crash/FNF-Phoenix-Engine_<date>.log`) ends with the hardware the game
was running on, so a bug report carries it automatically:

```
GPU: NVIDIA GeForce RTX 3060
GPU Vendor: NVIDIA
GPU Driver: 535.104.05
Graphics API: OpenGL 4.6
CPU: Intel(R) Core(TM) i7-9700K CPU @ 3.60GHz
CPU Vendor: Intel
OS: Windows 10.0.19045
Audio: OpenAL Soft | 1.23.1
```

`backend.Native` collects the values: the GPU, its vendor and the driver version come
from the OpenGL context (`GL.VENDOR`, `GL.RENDERER`, `GL.VERSION`), the CPU and the
operating system from the small native layer in `source/backend/native/`. The GPU
sniffing is ported from the [Psych Plus Engine](https://github.com/Psych-Plus-Team/FNF-PlusEngine)
— thanks to the Psych Plus Team for the original implementation.

Everything degrades gracefully: a target without a render context or without the native
queries reports `Unknown` instead of failing, and the crash log is still written.

The same values are available to scripts through `getSystemInfo()`, `getGPUName()`,
`getGPUVendor()`, `getGPUDriverVersion()`, `getCPUName()`, `getCPUVendor()`,
`getOSName()`, `getOSVersion()`, `getGraphicsApi()` and `getAudioApi()` (Lua, Python and
HScript), see the [Lua](../modding/lua-api-reference.md) and
[Python](../modding/python-api-reference.md) API references.

## Verbose log (`vlog/log.txt`)

`backend.VLog` records an aggressively verbose, append-only session log at
`vlog/log.txt` in **every build**. It is initialized in `Main` before
`CrashHandler.init`, so the whole boot is covered, and on Android the file
lives in the app's external-files directory — the same directory the SAF
**VLogs** root of `PhoenixDocumentsProvider` exposes, so the log can be copied
out of the game through the system Files app exactly like `crash/` reports.

What goes in (all timestamped with the running frame index):

- **Session header/footer** — engine/JSE/Psych versions, target platform,
  working directory, launch arguments, the full hardware report (same source
  as crash logs), then duration, frame total, average FPS, peak frame/work
  times, lag-spike counts and peak heap/RSS.
- **One line per frame** — FPS, frametime, work time, update count, draw
  calls, managed heap, process RSS and the current state.
- **Lag spikes** — any frame over max(2× budget, 25 ms) gets a dedicated
  `LAG SPIKE` line breaking the time into engine work vs. time outside the
  measured frame (vsync wait / system stall); over 100 ms it is `EXTREME LAG`.
- **Every `trace()`** — captured through a rebound `haxe.Log.trace`, so engine
  traces and all three scripting runtimes end up in the log tagged
  `[Engine]`, `[Lua]`, `[Python]` or `[HScript]`. Script traces are logged
  even when `luaDebugMode` / `pythonDebugMode` (the in-game debug console)
  are off.
- **RAM asset caching** — images entering the cache (dimensions, CPU bitmap
  vs. GPU texture), sounds decoded into RAM, decode failures, missing assets,
  note-skin/splash loads, `clearStoredMemory` / `clearUnusedMemory` results
  and every explicit GC/heap compact with heap size before/after.
- **State changes and crashes** — every `FlxGame` state switch, and uncaught
  errors mirrored from `CrashHandler` (message, stack, hardware) so the live
  log carries the same context as the `crash/` report.

The writer is fail-safe: lines are buffered and flushed at most every 250 ms,
the live log rotates at 10 MiB (keeping `log.1.txt`/`log.2.txt`), and any
filesystem problem disables vlog writes for the session with a console notice
instead of affecting gameplay. Web and Flash builds have no writable
filesystem, so the log accumulates in a capped in-memory buffer that
`VLog.exportText()` returns; on HTML5, `VLog.download()` additionally saves
it as `log.txt` through the browser.

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
