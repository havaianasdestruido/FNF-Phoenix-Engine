---
title: Running & debugging
sidebar_position: 4
description: Launching the game, debug keybinds, the in-game editors, logging and profiling.
---

# Running & debugging

## Launching

```bash
lime test windows            # build + run
lime test windows -debug     # debug build (asserts, stack traces, slower)
```

A debug build defines `debug`, which the codebase uses to gate `trace()` calls and extra
tooling (`#if debug`).

## VS Code

The repository ships a ready-to-use configuration:

| File | What it gives you |
|---|---|
| `.vscode/tasks.json` | build/test tasks for each target |
| `.vscode/launch.json` | debugging through `hxcpp-debug-server` (breakpoints in Haxe) |
| `.vscode/extensions.json` | recommended extensions (Haxe, Lime) |
| `.vscode/settings.json` | formatter and checkstyle wiring |

These four files are deliberately **not** git-ignored (see the `!` rules in `.gitignore`)
so everyone shares the same setup.

## In-game debug tools

| Key / action | Effect |
|---|---|
| `F11` | fullscreen toggle (centralised in `backend.FunkinGame`) |
| FPS counter | `debug.FPSCounter`, toggled by the *Show FPS* option; can also show RAM and max RAM |
| Chart editor | `editors.ChartingState`, reachable from the pause menu and the editor hub |
| Editor hub | `editors.MasterEditorMenu` — chart, character, dialogue, week, menu-character and note-splash editors |
| Debug menu | `options.SuperSecretDebugMenu`, behind `FEATURE_DEBUG_FUNCTIONS` |
| Lua/Python debug text | `psychlua.DebugLuaText` prints script output on-screen via `debugPrint(...)` |

## Logging

`trace()` output goes to stdout on native targets. Keep new traces behind `#if debug` —
the codebase was explicitly cleaned of unconditional traces for performance.

Script errors surface in two places: on-screen through `DebugLuaText`, and in the console.

## Crash handling

`backend.CrashHandler` (flag `CRASH_HANDLER`) installs an OpenFL uncaught-error handler and
writes a crash log, then shows `states.ErrorState` instead of hard-killing the window.
The `HXCPP_STACK_*` defines in `project.hxp` are what make those logs readable.
`ClientPrefs.peOGCrash` switches back to the plain Psych-style crash dialog.

## Profiling

- `debug.Memory` / `utils.MemoryUtil` expose the memory figures shown by the FPS counter.
- `-DDEBUG_TRACY` (`FEATURE_DEBUG_TRACY`) compiles in Tracy profiler instrumentation.
- `-DULTRA_OPTIMIZED` is the experimental maximum-speed configuration; expect rough edges.

## Mods while developing

Mods are read from the `mods/` folder next to the executable. During development that is
`export/<target>/bin/mods/`; the repo's root `mods/` folder is the source copy that gets
packaged. `modsList.txt` controls which ones are enabled:

```text
bf-clicker|1
```

See [Mod folder structure](../modding/mod-folder-structure.md).
