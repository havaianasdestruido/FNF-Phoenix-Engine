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
`vlog/log.txt`. It is **disabled by default** — nothing is written to disk
until it is switched on in **Options → Misc → "Enable VLog"** (saved as
`ClientPrefs.vlogEnabled`). When enabled, the log starts immediately and stays
on for the following launches; `Main` starts it before `CrashHandler.init`, so
the whole boot is covered, and on Android the file lives in the app's
external-files directory — the same directory the SAF **VLogs** root of
`PhoenixDocumentsProvider` exposes, so the log can be copied out of the game
through the system Files app exactly like `crash/` reports.

What goes in (all timestamped with the running frame index):

- **Session header/footer** — engine/JSE/Psych versions, target platform,
  working directory, launch arguments, the full hardware report (same source
  as crash logs), then duration, frame total, average FPS, peak frame/work
  times, lag-spike counts and peak heap/RSS.
- **One line per frame** — FPS, frametime, work time, update count, draw
  calls, managed heap, process RSS, the current state, and a **per-area RAM
  breakdown** (see below).
- **Per-area RAM** — a compact `ram{…}` block on every frame line and a rich
  `RAM` line every ~second and on every state change, splitting memory into
  engine assets, mod assets, engine code, mod code and runtime reserved (see
  [Per-area RAM attribution](#per-area-ram-attribution)).
- **Lag spikes** — any frame over max(2× budget, 25 ms) gets a dedicated
  `LAG SPIKE` line breaking the time into engine work vs. time outside the
  measured frame (vsync wait / system stall); over 100 ms it is `EXTREME LAG`.
  Lag lines also carry the per-area RAM block so a stall can be correlated
  with, say, a mod loading a large atlas.
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

Unticking the option closes the session (footer + forced flush) and restores
the default `trace()` printer, so a disabled vlog behaves exactly like a build
without it.

The writer is fail-safe: lines are buffered and flushed at most every 250 ms,
the live log rotates at 10 MiB (keeping `log.1.txt`/`log.2.txt`), and any
filesystem problem disables vlog writes for the session with a console notice
instead of affecting gameplay. Web and Flash builds have no writable
filesystem, so the log accumulates in a capped in-memory buffer that
`VLog.exportText()` returns; on HTML5, `VLog.download()` additionally saves
it as `log.txt` through the browser.

### Per-area RAM attribution

A single heap number does not tell you *what* is eating RAM on a weak device,
so `backend.MemoryLedger` splits process RAM into five areas and the vlog
reports them **every frame**:

| Area | What it counts | How it is measured |
|---|---|---|
| `engAssets` | CPU pixels / decoded audio cached from `assets/` | `w×h×4` per image, decoded PCM per sound (incremental on cache/clear) |
| `modAssets` | the same, cached from `mods/` | same, classified by the resolved `mods/<name>/…` path |
| `engCode` | the engine's own managed-heap footprint (Flixel/OpenFL/Lime/Haxe code + live state data) | `heap − assetCPU − interpreterBytes` |
| `modCode` | Lua states + Python/HScript/HaxeScript interpreters | Lua **exact** via `lua_gc(GCCOUNT)`; interpreters **estimated** from the load-time heap delta |
| `runtime` | Haxe/Flixel/etc. reserved stuff outside the managed heap (native libs, GPU driver, stacks, GC pools) | `RSS − heap − luaBytes`; the GC reserved-but-free pool is shown alongside |

Every frame line ends with a compact block:

```
[FRAME] fps=60 frame=16.7ms work=8.2ms upd=1 draws=42 heap=90.6MB rss=210MB ram{engAssets=12.3MB modAssets=45.6MB engCode=18.2MB modCode=3.1MB runtime=22MB} state=PlayState
```

…and once a second (and on every state change) a detailed `RAM` line adds GPU
bytes, asset/script counts, exact Lua vs. estimated interpreter memory, the GC
reserved pool, the boot-time engine baseline, and the **top mods by RAM**:

```
[RAM] engineAssets=12.3MB (gpu 4MB, 34 items) | modAssets=45.6MB (gpu 120MB, 17 items) | engineCode=18.2MB (boot baseline 15MB) | modCode=3.1MB (lua 2.8MB [6], interp 0.3MB [2] est) | runtime=22MB (gcReserved 18MB) | heap=90.6MB rss=210MB | topMods: mymod=40.1MB, other=5.5MB
```

Notes on the model:

- The five areas are an **approximate partition of process RSS**: when RSS is
  known they sum to ~RSS. GPU texture bytes are reported separately per asset
  area because VRAM is not process RSS on a discrete GPU (it is shared RAM on
  mobile, which is exactly where this breakdown matters most).
- Asset totals are maintained incrementally when `Paths` caches/clears an
  asset, so the per-frame cost is O(1); Lua memory is an O(1) counter read per
  state. Nothing here scans the asset cache each frame.
- GPU-cached images (`ClientPrefs.cacheOnGPU`) free their CPU pixels, so they
  contribute to the area's **GPU** figure rather than its RAM figure.
- Interpreter memory (Python/HScript/HaxeScript) lives in the managed heap and
  cannot be queried directly, so it is estimated and labelled `est`.
- Everything degrades gracefully: a target that cannot report RSS or the GC
  reserved pool shows `n/a` / `0` instead of failing, and any measurement error
  is swallowed so the ledger can never take the game down.
- The session footer reports the **peak** of each area (`peakRam{…}`), so a
  whole session's worst-case per-area usage is one line away.

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
