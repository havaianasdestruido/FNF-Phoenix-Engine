# Debugging "my Lua script does nothing"

A `.lua` mod script that never runs produces no error in game: it simply has no
effect. That silence has a small number of causes, and they happen in a fixed
order. This page walks that order and names the exact code that can stop a
script at each step.

The checks in `tests/haxe/LuaScriptDiscoverySpec.hx` automate this list:

```bash
# pure Haxe stages, no interpreter needed
bash tests/haxe/run-lua-discovery.sh

# run the shipped mod scripts through the real sandbox bootstrap
LUAJIT=/path/to/luajit bash tests/haxe/run-lua-discovery.sh
```

Only `source/backend/ModSecurity.hx` and `ScriptSecurityScanner.hx` are pulled
into the test classpath; everything else is read from the tree as data, so the
suite cannot drift from the engine.

---

## 0. Is Lua compiled into this build?

`FunkinLua` and every `psychlua/*.hx` file sit behind `#if LUA_ALLOWED`
(`source/import.hx`). When the define is absent the engine has no Lua support at
all and `.lua` files are ignored without a message.

`project.hxp` decides the flag from two independent expressions:

| What | Where | Condition |
|---|---|---|
| `LUA_ALLOWED` define | `configureFeatureFlags()` | `(isDesktop() \|\| isMobile()) && … && isCPP()` |
| `hxluajit` haxelib | `configureHaxellibs()` | `isDesktop() && LUA_ALLOWED.isEnabled(this)` |

`source/import.hx` does `#if LUA_ALLOWED import hxluajit.*;`, so the bindings
haxelib has to be on the classpath exactly when the define is set. **The two
conditions do not agree on mobile**: `LUA_ALLOWED` covers `isMobile()`, the
haxelib is desktop-only. On Android/iOS that means either Lua is silently
unavailable despite the define, or the build fails on a missing
`hxluajit.*` import — check this first when Lua "does nothing at all" on a
phone.

Also confirm the build was not made with `-DMODDING_LEVEL=0` (Lua and Python
off) or `-DNO_LUA_ALLOWED`.

## 1. Is the script in a folder the engine walks?

`PlayState.create()` builds its script list from these directories:

| Scope | Directories |
|---|---|
| Always scanned | `mods/scripts/`, `assets/scripts/` (`Paths.getPreloadPath('scripts/')`) |
| Current mod | `mods/<mod>/scripts/` for `Mods.currentModDirectory` |
| Global mods | `mods/<mod>/scripts/` for every mod whose `pack.json` sets `"runsGlobally": true` |
| Song | `mods/data/<song>/`, `assets/data/<song>/` |
| Stage | `stages/<curStage>.lua` |
| Note types | `custom_notetypes/<type>.lua` |
| Events | `custom_events/<event>.lua` |

Two consequences that account for most "nothing happens" reports:

* `mods/<mod>/scripts/` is **not** scanned just because the mod is enabled in
  `modsList.txt`. It is read while that mod is the current mod, and on every song
  only for mods returned by `Mods.getGlobalMods()` (which filters on
  `runsGlobally`). A mod that is merely enabled contributes nothing.
* Each folder is read with `readDirectory()` and **only one level deep**. A
  script in `mods/data/song/scripts/song.lua` is never found.

## 2. Does the song folder name match the chart?

The song script folder is `mods/data/<Paths.formatToSongPath(SONG.song)>/`, and
`SONG.song` comes from the **chart's `song` field** — not from the name of the
file that was requested. `Paths.formatToSongPath` spaces become `-`, the first of
`~&\\;:<>#` becomes `-`, the first of `.,'"%?!` is dropped, everything is
lowercased.

So a chart that says `"song": "Transparency Test"` is loaded from
`mods/data/transparency-test/`; a folder named `transparency test` or
`transparency_test` is never consulted, and neither the script nor the
instrumental is found. Keep the folder, `Inst.ogg` and the chart's `song` field
on the same formatted name.

## 3. Does the script pass the ModSecurity source gate?

`FunkinLua`'s constructor scans the source **before** creating a Lua state
(`ModSecurity.checkScript`). If the scan returns any finding the constructor sets
`closed = true` and returns — no Lua state, no hooks, no output beyond the
`[ModSecurity] BLOCKED …` lines in the log.

The scanner is a text matcher (`source/backend/ScriptSecurityScanner.hx`), so it
also fires on **comments and strings on an otherwise executable line**:

* `os.` / `io.` (rule `lua.os` / `lua.io`) — including `-- os.execute would…`
  is fine only when the whole line is a comment.
* `dofile(`, `loadfile(`, `loadstring(`, `load(` (`lua.dynamic-code`)
* `require(`, `module(` (`lua.package`)
* `debug.`, `ffi.`, `jit` (`lua.native`)
* `http://`, `file://`, … (`network.url`)
* `curl`, `wget`, `python -c`, `cmd /c`, `bash -c` (`process.shell`)

Fix the script, or — if the capability is genuinely wanted — add the rule id to
`scriptSandboxAllowlist` in the mod's `pack.json`:

```json
{
  "name": "My Mod",
  "scriptSandboxAllowlist": ["lua.io"]
}
```

`"scriptSandbox": false` (or `"allowUnsafeScripts": true`) disables the whole
scan for that mod. Both are logged at load time.

## 4. Does the sandbox bootstrap load, and does it leave the stdlib alone?

For a sandboxed script, `ModSecurity.luaBootstrap()` is installed right after
`luaL_openlibs` and replaces `os`, `io`, `debug`, `ffi`, `jit`, `package`,
`require`, `module`, `load*` with sealed proxies. Two failure modes matter:

* If the bootstrap itself fails to compile or raises, the constructor closes the
  state and the script never runs — the message is
  `failed to initialise Lua sandbox: …`, at load time.
* If the bootstrap accidentally replaces something a normal mod needs
  (`string`, `table`, `math`, `pairs`, `pcall`, `error`, …) then every
  *hook call* of every sandboxed script fails, again with no visible effect in
  game. `run-lua-discovery.sh` probes this surface on purpose.

The replacement is deliberate and correct: `os.execute` inside a sandboxed
script must raise. If your script needs it, allowlist the rule (step 3).

## 5. Did the top-level chunk actually load?

`FunkinLua` runs the buffer with `luaL_loadbuffer` + `pcall` **at the end of the
constructor**, after every engine global and callback is registered. A syntax
error, or an undefined global used at the top level, closes the state. The text
appears as `Error on lua script! <…>` in the log (and, on Windows, in a message
box).

Note that `os.exit`, `error` and friends are the sandboxed versions by this
point, so a script that exits early is also silently dead.

## 6. Is the hook being fired at all?

Declaring `function onWhatever()` does nothing unless something calls it.
`PlayState.callOnScripts()` dispatches to Lua, Python and HScript; the names come
from `callOnLuas('…')` call sites in `source/`. If a hook you rely on is never
in that list, it is never invoked — `docs/TemplateScript.lua` lists the full
documented set, and the spec cross-checks the two.

## 7. Is the script still registered when the hook fires?

`FunkinLua` pushes itself into `PlayState.luaArray` **before** it publishes its
globals and before it runs the script (line numbers in the constructor:
`luaArray.push` ~160, last `set(...)` ~296). Any exception while publishing a
global therefore leaves a half-built script in the dispatch list, and the next
hook call reaches it. Keep this in mind when debugging a Lua error that seems to
come from an unrelated script.

## Reading the evidence

Lua errors and `debugPrint` output are `trace()`d, so they always reach the
console. The durable session log is off by default — it is only written when
**Options → Misc → Enable VLog** (`ClientPrefs.vlogEnabled`) is on, which rebinds
`haxe.Log.trace` and writes `vlog/log.txt`.

To diagnose a script that does nothing:

1. Turn VLog on before playing, then read `vlog/log.txt`.
2. Look for `[ModSecurity] BLOCKED`, `Error on lua script!`,
   `failed to initialise Lua sandbox`, and `ERROR (<hook>)` lines.
3. No line for your script at all means it was never discovered — go back to
   steps 0–2.
