# Debugging "my Lua script does nothing"

A `.lua` mod script that never runs simply has no effect in game. That has a
small number of causes, and they happen in a fixed order. The engine reports
the ones it can see in lines that start with `[LuaDiag]`. This page explains
those lines, then walks the order and names the exact code that can stop a
script at each step.

Two specs automate this page:

```bash
# what the engine reports and when (rules, wording, wiring); needs only Haxe
bash tests/haxe/run-lua-diagnostics.sh

# the discovery and sandbox rules themselves
bash tests/haxe/run-lua-discovery.sh

# both also check themselves against a real interpreter when one is given
LUAJIT=/path/to/luajit bash tests/haxe/run-lua-diagnostics.sh
LUAJIT=/path/to/luajit bash tests/haxe/run-lua-discovery.sh
```

`run-lua-diagnostics.sh` compiles `source/backend/LuaDiagnostics.hx` on its own
(the class has no engine dependency) and runs it for the kinds of build that
report differently: a target that cannot include Lua (web/Flash), a native
build without the Lua VM (`-D native`, what `-DMODDING_LEVEL=0` produces) and
a native build with it (the default). `run-lua-discovery.sh` pulls
only `source/backend/ModSecurity.hx` and `ScriptSecurityScanner.hx` into its
classpath. Everything else is read from the tree as data, so neither suite can
drift from the engine.

---

## Start here: what the engine says

Start the game from a terminal (see [Where the lines go](#where-the-lines-go)),
play the song, and read the lines that start with `[LuaDiag]`.

### Always printed

No setting is needed for these. Each one names the file and the reason.

| Line (shortened) | What it means | Step |
|---|---|---|
| `This build does NOT include the Lua VM (LUA_ALLOWED is off): .lua scripts cannot run.` at start-up, and `ERROR: N Lua scripts found, but this build cannot run Lua …` on every song that has scripts | The executable was built without Lua. The scripts are not at fault. The song notice is also shown on screen, once per run. | [0](#0-is-lua-compiled-into-this-build) |
| `WARNING: <file> looks like a Lua script but is not loaded: the file name must end in exactly ".lua" …` | `Script.LUA`, `script.lua.txt`, `script.lua.bak` | [1](#1-is-the-script-in-a-folder-the-engine-walks) |
| `WARNING: <folder>/ has N Lua scripts but is not the folder this song reads …` | The song folder exists under another spelling | [2](#2-does-the-song-folder-name-match-the-chart) |
| `ERROR: <file> was blocked by ModSecurity before it ran: <rule> (line N). …` | The security scan refused the file. The rest of the line is the `pack.json` entry that allows it. | [3](#3-does-the-script-pass-the-modsecurity-source-gate) |
| `WARNING: <file>: the file is empty …` or `… contains NUL bytes …` | Nothing to run, or the file was saved as UTF-16 | [5](#5-did-the-top-level-chunk-actually-load) |
| `ERROR: <file> did not load: it could not be read …` | The file is there but cannot be opened (permissions, a broken link) | [5](#5-did-the-top-level-chunk-actually-load) |
| `ERROR: <file> did not load: the file does not compile (syntax error): …` | Followed by the source line the error points at | [5](#5-did-the-top-level-chunk-actually-load) |
| `ERROR: <file> did not load: the file compiled, but its top-level code raised an error while running (runtime error): …` | Same, for code outside any function | [5](#5-did-the-top-level-chunk-actually-load) |
| `WARNING: <file> defines <hook>, but the engine looked that hook up before the script had finished loading …` | The hook will never be called | [6](#6-is-the-hook-being-fired-at-all) |
| `ERROR: hook <hook> of <file> failed: …` | A hook raised. Each distinct error is printed the first time it happens; the total follows when the song ends. | [6](#6-is-the-hook-being-fired-at-all) |
| `Lua scripts for "<song>": N loaded, N FAILED, …` | The summary, with one line per script that did not load. Printed when a script failed or was skipped for its name. | |

A song whose scripts all load prints none of these.

### Verbose mode

Verbose mode adds a line for every step: each folder that is searched and what
is done with each file in it, each stage of loading a script, the hooks the
script defines, global functions that look like a misspelt hook
(`oncreate`, `onUpdatPost`), and the first run of each hook. Warnings, errors
and the summary headline are also shown on screen. Any one of these turns it on:

| Switch | Notes |
|---|---|
| **Options → Misc → Verbose Lua Logging** | Saved with the other settings; applies at once |
| `flags.ini`: `[scripts]` `verboseLua = true` | Next to the executable; no need to reach the menu |
| Environment variable `PHOENIX_LUA_VERBOSE=1` | Also `true`, `yes`, `on` |
| Build with `-DLUA_VERBOSE` | Always on in that build |

Verbose mode works in a build without Lua too: it lists the scripts that such a
build finds and cannot run.

### Where the lines go

* **Console.** Start the game from a terminal. A Windows build has no console
  window of its own, but it writes to the console it was started from, so run
  the `.exe` from `cmd` or PowerShell.
* **`vlog/log.txt`**, while **Options → Misc → Enable VLog** is on. The lines
  carry the tag `LUA`.
* **Android:** `adb logcat -s trace`.
* **On screen**, in the same overlay as `debugPrint`: the "no Lua in this build"
  notice in any mode (once per run), everything else only in verbose mode. A
  message stays for six seconds, so the console remains the place to read a
  whole session.

### Example

The output below is from a Linux build and a test mod made to trip each check
once. Engine lines that do not start with `[LuaDiag]` are left out, and `...`
stands for further lines left out.

A build without Lua (`lime build linux -DMODDING_LEVEL=0`). A plain
`lime build linux` includes Lua now; this is what a level-0 build says:

```text
[LuaDiag] This build does NOT include the Lua VM (LUA_ALLOWED is off): .lua scripts cannot run.
...
[LuaDiag] ERROR: 16 Lua scripts found, but this build cannot run Lua (it was compiled without LUA_ALLOWED).
[LuaDiag] ERROR: The scripts are not at fault: the Lua VM is not in this executable.
[LuaDiag] ERROR: Rebuild with -DMODDING_LEVEL=1 (Lua) or -DMODDING_LEVEL=2 (Lua + Python).
[LuaDiag] ERROR: Example: lime test linux -DMODDING_LEVEL=1. The build log explains the choice on its "Script support" line; see docs/LUA_SCRIPT_DEBUGGING.md, step 0.
[LuaDiag] ERROR:   not run: mods/diag-test/scripts/blocked.lua
[LuaDiag] ERROR:   not run: mods/diag-test/scripts/bom.lua
[LuaDiag] ERROR:   not run: mods/diag-test/scripts/closer.lua
[LuaDiag] ERROR:   not run: mods/diag-test/scripts/eager.lua
[LuaDiag] ERROR:   not run: mods/diag-test/scripts/empty.lua
[LuaDiag] ERROR:   not run: mods/diag-test/scripts/good.lua
[LuaDiag] ERROR:   not run: mods/diag-test/scripts/hookerror.lua
[LuaDiag] ERROR:   not run: mods/diag-test/scripts/latecloser.lua
[LuaDiag] ERROR:   ... and 8 more
[LuaDiag] Lua scripts for "Transparency Test": 0 loaded, 2 skipped (file name is not *.lua), 1 replaced by a same-named script, 16 not run (no Lua support in this build)
...
```

A build with Lua (`lime build linux -DMODDING_LEVEL=1`), no setting changed:

```text
[LuaDiag] WARNING: mods/diag-test/scripts/Shout.LUA looks like a Lua script but is not loaded: the file name must end in exactly ".lua" (lower case, with no second extension such as ".lua.txt").
[LuaDiag] WARNING: mods/diag-test/scripts/notes.lua.txt looks like a Lua script but is not loaded: the file name must end in exactly ".lua" (lower case, with no second extension such as ".lua.txt").
[LuaDiag] ERROR: mods/diag-test/scripts/syntax.lua did not load: the file does not compile (syntax error): mods/diag-test/scripts/syntax.lua:3: unexpected symbol near '='
[LuaDiag]        2 | function onCreate()
[LuaDiag]   >    3 |     local b = = 2
[LuaDiag]        4 | end
[LuaDiag] ERROR: mods/diag-test/scripts/runtime.lua did not load: the file compiled, but its top-level code raised an error while running (runtime error): mods/diag-test/scripts/runtime.lua:3: attempt to call global 'thisFunctionDoesNotExist' (a nil value)
[LuaDiag]        2 |
[LuaDiag]   >    3 | thisFunctionDoesNotExist(a)
[LuaDiag]        4 | function onCreate() end
[LuaDiag] ERROR: mods/diag-test/scripts/blocked.lua was blocked by ModSecurity before it ran: lua.os (line 2). To run it anyway add "scriptSandboxAllowlist": ["lua.os"] to mods/diag-test/pack.json (or "scriptSandbox": false to turn the scan off for this mod), or remove the flagged code. The scan matches text, so it also fires on a string or a trailing comment.
[LuaDiag] WARNING: mods/diag-test/scripts/empty.lua: the file is empty, so it defines no hooks
[LuaDiag] WARNING: mods/diag-test/scripts/utf16.lua: the file contains NUL bytes (saved as UTF-16, or not a text file?). Save it as UTF-8 text
[LuaDiag] ERROR: mods/diag-test/scripts/utf16.lua was blocked by ModSecurity before it ran: security.binary-source (line 1). The file contains NUL bytes, which Lua source text never does: it was most likely saved as UTF-16 ("Unicode" in some Windows editors). Save it again as UTF-8 so the engine can read it.
[LuaDiag] WARNING: mods/diag-test/scripts/eager.lua defines onEvent, but the engine looked that hook up before the script had finished loading and cached it as missing: it will not be called. Do not trigger engine events from top-level code; do it in onCreate.
[LuaDiag] ERROR: mods/scripts/looseblocked.lua was blocked by ModSecurity before it ran: lua.io (line 2). This is a loose script (not inside a mod folder), so there is no pack.json to allow ["lua.io"]. Move it into a mod folder (mods/<your mod>/...) and add "scriptSandboxAllowlist": ["lua.io"] to that mod's pack.json, or remove the flagged code.
[LuaDiag] WARNING: mods/diag-test/data/Transparency Test/ has 1 Lua script but is not the folder this song reads: the engine looks in mods/diag-test/data/transparency-test/ (the song name in lower case, with spaces as dashes). Rename the folder to "transparency-test".
[LuaDiag] Lua scripts for "Transparency Test": 11 loaded, 5 FAILED, 2 skipped (file name is not *.lua), 1 replaced by a same-named script
[LuaDiag]   SKIPPED mods/diag-test/scripts/Shout.LUA - the file name does not end in exactly ".lua"
[LuaDiag]   SKIPPED mods/diag-test/scripts/notes.lua.txt - the file name does not end in exactly ".lua"
[LuaDiag]   FAILED  mods/diag-test/scripts/syntax.lua - syntax error: mods/diag-test/scripts/syntax.lua:3: unexpected symbol near '='
[LuaDiag]   FAILED  mods/diag-test/scripts/runtime.lua - runtime error: mods/diag-test/scripts/runtime.lua:3: attempt to call global 'thisFunctionDoesNotExist' (a nil value)
[LuaDiag]   FAILED  mods/diag-test/scripts/blocked.lua - blocked by ModSecurity: lua.os (line 2)
[LuaDiag]   FAILED  mods/diag-test/scripts/utf16.lua - blocked by ModSecurity: security.binary-source (line 1)
[LuaDiag]   FAILED  mods/scripts/looseblocked.lua - blocked by ModSecurity: lua.io (line 2)
[LuaDiag] ERROR: hook onUpdate of mods/diag-test/scripts/hookerror.lua failed: mods/diag-test/scripts/hookerror.lua:3: attempt to index local 'nothing' (a nil value) (printed once; set luaDebugMode = true in the script to see every occurrence in game)
[LuaDiag] "Transparency Test": 259 Lua hook errors in total, 1 distinct (the first occurrence of each is printed above).
```

The same build with `PHOENIX_LUA_VERBOSE=1`, shortened to one script of each
kind:

```text
[LuaDiag] verbose Lua logging ON (PHOENIX_LUA_VERBOSE environment variable). This build includes the Lua VM (LUA_ALLOWED).
[LuaDiag] ==== script load: "Transparency Test" ====
[LuaDiag] This build includes the Lua VM (LUA_ALLOWED).
[LuaDiag] song "Transparency Test" -> data folder "transparency-test", stage "transparency-test"
[LuaDiag] working directory: /home/user/FNF-Phoenix-Engine/build/release/linux/bin/
[LuaDiag] current mod: diag-test; global mods ("runsGlobally" in pack.json): []
[LuaDiag] scan "global scripts": 3 folders, searched in this order (the first folder wins when two scripts share a file name):
...
[LuaDiag]   mods/diag-test/scripts/ -> 15 entries, 12 Lua scripts to load
[LuaDiag]     Shout.LUA -> SKIPPED: the name does not end in exactly ".lua"
[LuaDiag]     blocked.lua -> load
[LuaDiag]     bom.lua -> load
[LuaDiag]     closer.lua -> load
[LuaDiag]     eager.lua -> load
[LuaDiag]     empty.lua -> load
[LuaDiag]     good.lua -> load
[LuaDiag]     hookerror.lua -> load
[LuaDiag]     latecloser.lua -> load
[LuaDiag]     notes.lua.txt -> SKIPPED: the name does not end in exactly ".lua"
[LuaDiag]     runtime.lua -> load
[LuaDiag]     sub/ -> not searched: script folders are read one level deep, so the 1 .lua file inside is not loaded from here
[LuaDiag]     syntax.lua -> load
[LuaDiag]     typo.lua -> load
[LuaDiag]     utf16.lua -> load
[LuaDiag] load #1: mods/diag-test/scripts/good.lua (file)
[LuaDiag]   source: 201 bytes, 10 lines
[LuaDiag]   security: owner "diag-test", sandboxed, allowlist [], 0 finding(s)
[LuaDiag]   sandbox: bootstrap installed
[LuaDiag]   api: 365 global functions are available to the script
[LuaDiag]   hooks defined (3): onCreate, onCreatePost, onUpdate
[LuaDiag]   other global functions: helperThing
[LuaDiag]   loaded in 1 ms
[LuaDiag] hook onCreate ran for the first time in mods/diag-test/scripts/good.lua (returned Function_Continue)
...
[LuaDiag]   mods/scripts/ -> 2 entries, 1 Lua script to load
[LuaDiag]     good.lua -> SKIPPED: mods/diag-test/scripts/good.lua has the same file name and is searched first
[LuaDiag]     looseblocked.lua -> load
...
[LuaDiag]   assets/scripts/ -> does not exist
...
[LuaDiag] lookup characters/gf.lua -> no such script (mod folders, then assets/characters/gf.lua)
...
[LuaDiag] scan "song scripts": 3 folders, searched in this order (the first folder wins when two scripts share a file name):
...
[LuaDiag]   mods/diag-test/data/transparency-test/ -> 4 entries, 1 Lua script to load
[LuaDiag]     song.lua -> load
...
[LuaDiag] Lua scripts for "Transparency Test": 11 loaded, 5 FAILED, 2 skipped (file name is not *.lua), 1 replaced by a same-named script
...
[LuaDiag] hook onCreatePost ran for the first time in mods/diag-test/scripts/good.lua (returned Function_Continue)
[LuaDiag] hook onCreatePost ran for the first time in mods/diag-test/scripts/latecloser.lua (returned Function_Continue)
[LuaDiag] mods/diag-test/scripts/latecloser.lua called close() during onCreatePost: it is stopped and gets no more hooks
...
[LuaDiag] hook onUpdate ran for the first time in mods/diag-test/scripts/good.lua (returned Function_Continue)
[LuaDiag] ERROR: hook onUpdate of mods/diag-test/scripts/hookerror.lua failed: mods/diag-test/scripts/hookerror.lua:3: attempt to index local 'nothing' (a nil value)
...
[LuaDiag] "Transparency Test": 267 Lua hook errors in total, 1 distinct (the first occurrence of each is printed above).
```

---

## 0. Is Lua compiled into this build?

`FunkinLua` and every `psychlua/*.hx` file sit behind `#if LUA_ALLOWED`
(`source/import.hx`). When the define is absent the executable contains no Lua
VM and cannot run a `.lua` file.

**Every native build includes Lua by default.** `project.hxp` turns the
`LUA_ALLOWED` and `PYTHON_ALLOWED` defaults on for every target that can link
LuaJIT: Windows, Linux, macOS, Android and iOS. That is modding level 2
(Lua + Python), and no flag is needed.

| Command | Lua | Python |
|---|---|---|
| `lime test windows`, `linux`, `mac`, `android`, `ios`, `lime build …` | **on** | **on** |
| the same with `-DMODDING_LEVEL=1` | on | off |
| the same with `-DMODDING_LEVEL=0` or `-DNO_LUA_ALLOWED` | off | off |
| `lime test flash`, `html5`, `air` | off | off |

Web, WebAssembly, Flash and AIR are the only targets left out: LuaJIT ships
prebuilt binaries only for the native platforms above, and
`source/import.hx` does `#if LUA_ALLOWED import hxluajit.*;`, so a define
without the haxelib would not compile either.

> **Do not add `-cpp` to get Lua.** That is Lime's optional *target flag*, not
> what decides script support. It used to be the gate here, and because
> `lime build windows|linux|mac|android|ios` never sets it, every plain build
> and every CI build silently shipped without Lua. The gate is now
> `supportsScriptModding()` in `project.hxp`, which reads the compile target
> (`targetType`); `-cpp` changes nothing about it.

CI builds `lime build windows -Dcommit` and `lime build android`
(`-DofficialBuild` for releases) and passes `-DMODDING_LEVEL=2` explicitly
(`moddingLevel` input, default `2`), then fails the job if the build's
`Script support:` line does not say `Lua ON, Python ON`.

The build says which one it made. Look for this line in the build output:

```text
[INFO] Script support: Lua ON, Python ON, HScript ON (Lua: default for this target)
```

A build that lost script support looks like this instead:

```text
[INFO] Script support: Lua OFF, Python OFF, HScript ON (Lua: default for this target)
[WARN] Lua scripts (.lua) will NOT run in this build: LUA_ALLOWED is off.
[WARN] Add -DMODDING_LEVEL=1 (Lua) or -DMODDING_LEVEL=2 (Lua + Python) to include them.
```

With `-DMODDING_LEVEL=1` the line reads
`[INFO] Script support: Lua ON, Python OFF, HScript ON (Lua: -DMODDING_LEVEL=1)`
and there is no warning.

At run time, a C++ build without Lua prints
`[LuaDiag] This build does NOT include the Lua VM (LUA_ALLOWED is off): .lua scripts cannot run.`
when it starts. When a song has `.lua` files it lists them as `not run:` and
puts a notice on screen (first example above). The diagnostics page
(`phoenix://diagnostics`, see `URI.MD`) lists `LUA` in its Features row only
when the build includes it. HScript is not affected: `.hx` scripts run in
every build.

**Mobile has the same support as desktop.** `LUA_ALLOWED` and the Lua bindings
are decided by one condition in `project.hxp`, so they cannot disagree:

| What | Where | Condition |
|---|---|---|
| `LUA_ALLOWED` define | `configureFeatureFlags()` | `supportsScriptModding()`, or `-DMODDING_LEVEL=1`/`2` |
| `hxluajit` haxelib | `configureHaxelibs()` | `supportsScriptModding() && LUA_ALLOWED.isEnabled(this)` |

`supportsScriptModding()` is `isNativeCpp() && (isDesktop() || isMobile())`,
and `isNativeCpp()` checks `targetType == "cpp"`. hxluajit ships prebuilt
LuaJIT in `project/luajit/lib/{Windows,Linux,MacOS,Android,iOS}`, so Android
(armv7, x86, arm64, x86_64) and iOS (device and simulator) link it like any
desktop target. Passing `-DMODDING_LEVEL=1` on a web or Flash build is the only
combination that still stops at `source/import.hx`; the build log warns about it.

## 1. Is the script in a folder the engine walks?

`PlayState.create()` builds its script list from these directories:

| Scope | Directories |
|---|---|
| Always scanned | `mods/scripts/`, `assets/scripts/` (`Paths.getPreloadPath('scripts/')`) |
| Current mod | `mods/<mod>/scripts/` for `Mods.currentModDirectory` |
| Global mods | `mods/<mod>/scripts/` for every mod whose `pack.json` sets `"runsGlobally": true` |
| Song | `mods/<mod>/data/<song>/` (current mod and global mods), `mods/data/<song>/`, `assets/data/<song>/` |
| Stage | `stages/<curStage>.lua` |
| Characters | `characters/<name>.lua` |
| Note types | `custom_notetypes/<type>.lua` |
| Events | `custom_events/<event>.lua` |

Consequences that account for most "nothing happens" reports:

* `mods/<mod>/scripts/` is **not** scanned just because the mod is enabled in
  `modsList.txt`. It is read while that mod is the current mod, and on every song
  only for mods returned by `Mods.getGlobalMods()` (which filters on
  `runsGlobally`). A mod that is merely enabled contributes nothing. Verbose
  mode prints the current mod and the global mods at the top of each song, and
  names every enabled mod whose `scripts/` folder holds `.lua` files that are
  skipped for this reason.
* After two unclean exits in a row (a crash or a forced close) the game starts
  on the **Safe Mode** screen, where "Start with all mods disabled" is ticked
  by default. A session started that way searches nothing under `mods/` (only
  `assets/`), so no mod script runs until the game is restarted. Verbose mode
  says so at the top of each song.
* Each folder is read with `readDirectory()` and **only one level deep**. A
  script in `mods/data/song/scripts/song.lua` is never found. Verbose mode
  lists a sub-folder that holds `.lua` files as `not searched`.
* The file name must end in exactly `.lua`: the engine tests
  `file.endsWith('.lua')`, which is case-sensitive. `Script.LUA` and
  `script.lua.txt` (what Windows shows as `script.lua` while extensions are
  hidden) are skipped. The engine prints a `WARNING` for each such file.
* Within one scan the folders are searched in order, and **the first script
  with a given file name wins**: a `good.lua` in the current mod replaces a
  `good.lua` in `mods/scripts/`. This is how a mod overrides a base script, so
  it is not reported as a problem. Verbose mode names such files, and the
  summary counts them (`1 replaced by a same-named script`). Give unrelated
  scripts different file names.

## 2. Does the song folder name match the chart?

The song script folder is `mods/data/<Paths.formatToSongPath(SONG.song)>/`, and
`SONG.song` comes from the **chart's `song` field**, not from the name of the
file that was requested. In `Paths.formatToSongPath` spaces become `-`, the
first of `~&\\;:<>#` becomes `-`, the first of `.,'"%?!` is dropped, and
everything is lowercased.

So a chart that says `"song": "Transparency Test"` is loaded from
`mods/data/transparency-test/`; a folder named `transparency test` or
`transparency_test` is never consulted, and neither the script nor the
instrumental is found. Keep the folder, `Inst.ogg` and the chart's `song` field
on the same formatted name.

The engine checks for this. When a folder next to the expected one is the same
name under another spelling and holds `.lua` files, it prints
`WARNING: <folder>/ has N Lua scripts but is not the folder this song reads`,
with the name to rename it to. A folder that differs only in letter case loads
on Windows and macOS and not on Linux or Android; verbose mode notes that case.

## 3. Does the script pass the ModSecurity source gate?

`FunkinLua`'s constructor scans the source **before** creating a Lua state
(`ModSecurity.checkScript`). If the scan returns any finding the constructor sets
`closed = true` and returns: no Lua state, no hooks.

The scanner is a text matcher (`source/backend/ScriptSecurityScanner.hx`), so it
also fires on **comments and strings on an otherwise executable line**:

* `os.` / `io.` (rule `lua.os` / `lua.io`). A mention such as
  `-- os.execute would…` is fine only when the whole line is a comment.
* `dofile(`, `loadfile(`, `loadstring(`, `load(` (`lua.dynamic-code`)
* `require(`, `module(` (`lua.package`)
* `debug.`, `ffi.`, `jit` (`lua.native`)
* `http://`, `file://`, … (`network.url`)
* `curl`, `wget`, `python -c`, `cmd /c`, `bash -c` (`process.shell`)

A blocked script is reported twice: by ModSecurity itself
(`[ModSecurity] BLOCKED lua script …`, with the rule and the source line) and
by a `[LuaDiag] ERROR` line that carries the fix:

```text
[LuaDiag] ERROR: mods/diag-test/scripts/blocked.lua was blocked by ModSecurity before it ran: lua.os (line 2). To run it anyway add "scriptSandboxAllowlist": ["lua.os"] to mods/diag-test/pack.json (or "scriptSandbox": false to turn the scan off for this mod), or remove the flagged code. The scan matches text, so it also fires on a string or a trailing comment.
```

Fix the script, or, if the capability is genuinely wanted, add the rule id to
`scriptSandboxAllowlist` in the mod's `pack.json`:

```json
{
  "name": "My Mod",
  "scriptSandboxAllowlist": ["lua.os"]
}
```

`"scriptSandbox": false` (or `"allowUnsafeScripts": true`) disables the whole
scan for that mod. Both are logged at load time.

Two cases get their own wording:

* A **loose script** (directly under `mods/scripts/`, `mods/data/<song>/`, …)
  is always scanned and has no `pack.json` to carry an allowlist. The line
  says to move it into a mod folder.
* A file with **NUL bytes** (rule `security.binary-source`) is almost always a
  script saved as UTF-16. Allowing the rule would not help, because LuaJIT
  cannot compile such a file either. The line says to save it as UTF-8.

## 4. Does the sandbox bootstrap load, and does it leave the stdlib alone?

For a sandboxed script, `ModSecurity.luaBootstrap()` is installed right after
`luaL_openlibs` and replaces `os`, `io`, `debug`, `ffi`, `jit`, `package`,
`require`, `module`, `load*` with sealed proxies. Two failure modes matter:

* If the bootstrap itself fails to compile or raises, the constructor closes the
  state and the script never runs. The message is
  `failed to initialise Lua sandbox: …`, at load time, and the summary lists
  the script as `FAILED … - sandbox bootstrap failed`.
* If the bootstrap accidentally replaces something a normal mod needs
  (`string`, `table`, `math`, `pairs`, `pcall`, `error`, …) then every
  *hook call* of every sandboxed script fails. `run-lua-discovery.sh` probes
  this surface on purpose.

The replacement is deliberate and correct: `os.execute` inside a sandboxed
script must raise. If your script needs it, allowlist the rule (step 3).

Verbose mode prints the outcome of this step for each script:
`security: owner "<mod>", sandboxed, allowlist […], 0 finding(s)` and
`sandbox: bootstrap installed`.

## 5. Did the top-level chunk actually load?

`FunkinLua` runs the buffer with `luaL_loadbuffer` + `pcall` **at the end of the
constructor**, after every engine global and callback is registered. A syntax
error, or an undefined global used at the top level, closes the state. The text
appears as `Error on lua script! <…>` in the log (and, on Windows, in a message
box).

The `[LuaDiag] ERROR` line says which of the two it was and shows the line:

```text
[LuaDiag] ERROR: mods/diag-test/scripts/syntax.lua did not load: the file does not compile (syntax error): mods/diag-test/scripts/syntax.lua:3: unexpected symbol near '='
[LuaDiag]        2 | function onCreate()
[LuaDiag]   >    3 |     local b = = 2
[LuaDiag]        4 | end
```

* **Syntax error**: the file does not compile, so nothing in it ran.
* **Runtime error**: the file compiled, and code outside any function raised
  while running. The usual cause is a call to a function that does not exist
  (a misspelt engine function, or a helper defined further down the file).
  Nothing after that line was defined, so the script has no hooks.

Other things to know about this step:

* `os.exit`, `error` and friends are the sandboxed versions by this point, so a
  script that exits early is dead.
* A script that calls `close()` at the top level loads and then never receives
  a hook, not even `onCreate`. That is the usual way for a script to switch
  itself off, so it is only noted in verbose mode.
* An empty file, or one saved as UTF-16, gets a `WARNING` before the load is
  attempted. A UTF-8 byte-order mark is harmless.

## 6. Is the hook being fired at all?

Declaring `function onWhatever()` does nothing unless something calls it.
`PlayState.callOnScripts()` dispatches to Lua, Python and HScript; the names come
from `callOnLuas('…')` call sites in `source/`. If a hook you rely on is never
in that list, it is never invoked. `docs/TemplateScript.lua` lists the full
documented set, and the spec cross-checks the two.

* **Hook names are case-sensitive.** `function oncreate()` defines a global
  that nothing calls. Verbose mode lists the hooks each script defines
  (`hooks defined (2): onCreate, onUpdate`) and warns about a global function
  whose name is a hook in the wrong case or one letter away from one:
  `defines "onUpdatPost", which the engine never calls. Did you mean the hook "onUpdatePost"?`
  The match is a guess, which is why it is verbose only.
* **Not every hook starts with `on`.** The note hooks are `goodNoteHit`,
  `opponentNoteHit`, `noteMiss` and `noteMissPress`. `function onGoodNoteHit()`
  defines a global that nothing calls. Verbose mode lists such a function under
  `other global functions` instead of `hooks defined`.
* **A hook that raises is skipped for that call and the song goes on.** In game
  the error is shown only when the script sets `luaDebugMode = true`. The
  console always gets it: the first occurrence of each distinct error is
  printed as `[LuaDiag] ERROR: hook <name> of <file> failed: …`, and the total
  is printed when the song ends
  (`"<song>": 249 Lua hook errors in total, 1 distinct`). Verbose mode repeats
  the line at the 10th, 100th and 1000th occurrence.
* **Do not trigger engine events from top-level code.** The first time a hook
  is dispatched to a script that does not define it, the engine remembers the
  hook as missing for that script (`_missingCalls`) and never looks again. A
  top-level `triggerEvent(…)` dispatches `onEvent` before the rest of the file
  has defined it, so the script's `onEvent` is never called afterwards. The
  engine prints a `WARNING` for this. Move the call into `onCreate`.
* Verbose mode prints `hook <name> ran for the first time in <file>`, which is
  the proof that the engine does call it.

## 7. Is the script still registered when the hook fires?

`FunkinLua` pushes itself into `PlayState.luaArray` **before** it publishes its
globals and before it runs the script. Any exception while publishing a global
therefore leaves a half-built script in the dispatch list, and the next hook
call reaches it. Keep this in mind when debugging a Lua error that seems to
come from an unrelated script.

A script that calls `close()` inside a hook is removed after that hook returns.
Verbose mode prints `<file> called close() during <hook>: it is stopped and gets no more hooks`.

## Reading the evidence

1. Start the game from a terminal and play the song. Read the `[LuaDiag]`
   lines. A `WARNING` or `ERROR` that names your script is the answer.
2. If there is none, turn verbose mode on
   ([four ways](#verbose-mode)) and play the song again. Find your file:
   * It is not mentioned at all: it is not in a folder the engine searched.
     The `scan` lines list the folders, in order (steps 1 and 2).
   * It appears as `SKIPPED` or `not searched`: the line says why (step 1).
   * It has a `load #N` block: read down the block. It ends in an `ERROR`
     (steps 3 to 5) or in `hooks defined (…)`. If the hook you wrote is not in
     that list, the name is wrong (step 6).
   * The hook is listed and `ran for the first time` never appears for it: the
     engine did not dispatch it during this run (step 6).
3. A line that says the build does not include the Lua VM ends the search: no
   script can run until the game is rebuilt with Lua (step 0).

The engine's older messages are still printed and are still worth searching
for. `[ModSecurity] BLOCKED`, `Error on lua script!`,
`failed to initialise Lua sandbox` and `debugPrint` output are `trace()`d, so
they always reach the console. `ERROR (<hook>): …` is different: it is shown on
screen and in the console only while the script sets `luaDebugMode = true`;
otherwise it goes to `vlog/log.txt` alone. The `[LuaDiag] ERROR: hook …` line
does not depend on that setting.

The durable session log is off by default. It is only written when
**Options → Misc → Enable VLog** (`ClientPrefs.vlogEnabled`) is on, which
rebinds `haxe.Log.trace` and writes `vlog/log.txt`.
