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

## Launch options

A built executable also reads the arguments it was started with. They are parsed with
[docopt-ng](https://lib.haxe.org/p/docopt-ng/) by `backend.CommandLine`, they apply to
that one session, and they never touch the save file:

```bash
cd build/release/windows/bin
FNF-Phoenix-Engine.exe --help                 # usage text, then exit
FNF-Phoenix-Engine.exe --fullscreen --fps=144
FNF-Phoenix-Engine.exe --freeplay             # straight to FreeplayState
./FNF-Phoenix-Engine --song=bopeebo --profile
./FNF-Phoenix-Engine "phoenix://menu/mods"    # a deep link, like a protocol launch
```

| Option | Effect |
|---|---|
| `-h` / `--help`, `--version` | Print the usage text / the engine version and exit before a window opens |
| `-w`, `-f`, `-b` | Windowed, exclusive fullscreen or borderless for this session |
| `--fps=<n>` | Gameplay framerate (`1`-`10000`); menus keep *Menu Framerate* |
| `--freeplay` / `--menu` | Runtime twins of the `-DFREEPLAY` / `-DMENU` build flags, through the same `backend.LaunchState` resolver |
| `--song=<name>` / `--mod=<id>` | Open that [deep link](../subsystems/deep-links.md) once a menu is idle |
| `--profile` / `--vlog` | Frame profiler (its log is exported on exit) / verbose log |
| `--safe-mode` | Boot into the recovery screen, exactly like a crash loop does |
| `--troll` | Super danger mode (`CoolUtil.selfDestruct()`); the legacy `-troll` spelling works too |
| `--no-deeplinks` | Ignore the `phoenix://` links on the command line |

An argument the parser cannot use is reported in the verbose log (`[CLI] ignored: ...`)
and dropped: the game boots with the saved preferences either way. These are arguments
for the built executable, not for `lime`, which consumes the flags it knows. Full
reference, precedence rules and the checklist for adding an option: `docs/CLI.md`.
Spec: `bash tests/haxe/run-command-line.sh`.

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
