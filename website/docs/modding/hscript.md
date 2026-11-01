---
title: HScript
sidebar_position: 50
description: Standalone .hx/.hscript mods — Haxe scripts with the full engine hook lifecycle, plus running Haxe from Lua.
---

# HScript

HScript runs **Haxe source at runtime** through `hscript-improved`. There are two ways to
use it:

1. **Standalone scripts** — drop a `.hx` or `.hscript` file anywhere the engine loads
   Lua/Python scripts and it runs as a first-class mod script with the full
   [hook lifecycle](./script-hooks.md). No Lua parent required.
2. **Embedded in Lua** — the original escape hatch: `runHaxeCode(...)` from a Lua
   script when the Lua/Python API does not expose something (constructing arbitrary
   Flixel objects, calling static methods, and so on).

Requires `HSCRIPT_ALLOWED` — enabled on desktop, mobile and web (not Flash/AIR), and
independent of `-DMODDING_LEVEL`: standalone HScript mods work even in
`-DMODDING_LEVEL=0` builds. File discovery uses the mod filesystem, so on non-`sys`
targets scripts can still be created from strings with `HScript.fromFile(name, code)`.
`project.hxp` also sets `hscriptPos`, so runtime errors carry line numbers.

## Standalone scripts

```haxe
// mods/MyMod/scripts/beatbounce.hx
var star:FlxSprite;

function onCreatePost() {
    star = new FlxSprite(FlxG.width / 2, 80);
    star.makeGraphic(24, 24, FlxColor.YELLOW);
    star.cameras = [game.camHUD];
    game.add(star);
}

function onBeatHit() {
    if (curBeat % 2 == 0)
        FlxTween.tween(star, {y: 120}, Conductor.crochet / 1000, {ease: FlxEase.quadOut});
    return Function_Continue;
}
```

Start from `docs/TemplateScript.hx`, which stubs every hook with its exact signature.

### Where they load from

Exactly the same places as `.lua`/`.py`, in the same priority order
(global mods → active mod → loose `mods/` → `assets/preload`):

| Path | When |
|---|---|
| `scripts/*.hx`, `scripts/*.hscript` | every song (global scripts) |
| `data/<song>/*.hx` / `*.hscript` | that song |
| `stages/<stage>.hx` / `.hscript` | when that stage loads |
| `characters/<name>.hx` / `.hscript` | when that character is added |
| `custom_notetypes/<type>.hx` / `.hscript` | when a note of that type exists in the chart |
| `custom_events/<event>.hx` / `.hscript` | when that event exists in the chart |

For the folder-scanned scopes (`scripts/`, `data/<song>/`), `hud.hx` and `hud.hscript`
count as **the same script**: within one folder the `.hx` spelling wins, and across
folders the first folder in priority order wins — the other file is not loaded twice.
Extensions are matched case-insensitively.

### Lifecycle and return values

Top-level code runs once at load (imports, `var` initialisers, function declarations),
then the engine calls `onCreate()`. From there a standalone script gets the same hooks,
in the same broadcast as Lua and Python (Lua first, then Python, then HScript), and is
torn down with `onDestroy()` when the song ends. The sentinels are the shared ones:

| Return | Effect |
|---|---|
| nothing / `Function_Continue` | proceed normally |
| `Function_Stop` | cancel the engine's default behaviour for cancellable hooks |
| `Function_StopLua` / `Function_StopAll` | stop the hook propagating to later scripts |

A hook that throws is reported and disabled for that script only (the song keeps
playing); set `hscriptDebugMode = true;` at the top level to see hook errors on
screen while developing, mirroring `luaDebugMode`/`pythonDebugMode`.

Scripts can also be managed at runtime: `addHScript('scripts/extra')`,
`removeHScript('scripts/extra')`, the generic `addScript(...)` (all three languages),
`getRunningScripts()`, `isRunning(...)` and `callOnScripts(...)` are seeded into every
standalone script, and Lua/Python expose `addHScript`/`removeHScript` too.
On the engine side the equivalents are `PlayState.startHScriptOnFolder(path)`,
`PlayState.removeHScript(path)` (extension optional for both) and
`HScript.fromFile(path, ?code)`.

### What is in scope

Each script gets its **own interpreter**: top-level variables and functions are private
to that file. The scope is seeded with:

- `game` — the `PlayState` instance, plus the flat engine globals Lua/Python get
  (`curBeat`, `songName`, `downscroll`, `difficultyName`, ...), kept current by the
  engine. Read them freely; do **not** redeclare them with `var`, which would shadow
  the engine's copy.
- Flixel essentials by short name: `FlxG`, `FlxSprite`, `FlxCamera`, `FlxTimer`,
  `FlxTween`, `FlxEase`, `FlxMath`, and `FlxColor` (an object shim with the preset
  constants and `fromRGB`/`fromInt`/`fromString`/`fromHSB`/`fromHSL`, since abstracts
  have no runtime class).
- Engine classes: `PlayState`, `Paths`, `Conductor`, `ClientPrefs`, `Character`,
  `Alphabet`, `CustomSubstate`, `Native` (+ the `getGPUName()`-style helpers),
  `Achievements` and `DiscordClient` when those features are compiled in.
- `Math`, `Std`, `StringTools`, `Type`, `Reflect` (the last two withheld from
  sandboxed mods), `debugPrint(...)`, and the shared-state trio
  `setVar`/`getVar`/`removeVar` (backed by `PlayState.variables`, shared with
  Lua/Python).
- `openCustomSubstate` / `closeCustomSubstate` / `insertToCustomSubstate`; the live
  substate and its name are also published as the `customSubstate` /
  `customSubstateName` globals.

Anything else can be pulled in with a normal Haxe import at the top of the file —
`import states.FreeplayState;`, aliased imports included — or at runtime with
`addHaxeLibrary('FreeplayState', 'states')`. A leading `package ...;` line is
tolerated (it is commented out before parsing, preserving line numbers), so a plain
`.hx` file works as-is. `public var` / `static var` at the top level are supported and
kept in their own buckets, readable back from the host with `script.get('name')`.

### Sandbox

Standalone scripts go through the same [script security sandbox](./script-security.md)
as Lua/Python, scanned with the Haxe rules (`haxe.process`, `haxe.filesystem`,
`haxe.reflection`, ...) before any code runs. While sandboxed, `import` resolution and
the `Type`/`Reflect` seeds are disabled and `addHaxeLibrary` refuses privileged
classes; `addHScript`/`addScript` are blocked by the `engine.script-loader` rule like
their Lua/Python twins. Trusted mods use `scriptSandboxAllowlist` in `pack.json` as
usual.

## From a Lua script

```lua
function onCreate()
    runHaxeCode([[
        var spr = new FlxSprite(100, 100);
        spr.makeGraphic(200, 50, FlxColor.RED);
        game.add(spr);
    ]]);
end
```

`psychlua.HScript.implement(funk)` installs the Haxe-execution callbacks into the Lua
host, and `HScript.initHaxeModule(parent)` creates the interpreter lazily on first use,
so scripts that never touch Haxe pay nothing. The interpreter belongs to that Lua
script (`parentLua` is in scope) and shares the seeded scope above.

On the engine side the API is:

```haxe
HScript.execute(codeToRun, ?funcToRun, ?funcArgs):Dynamic
HScript.executeFunction(funcToRun, funcArgs):Dynamic
```

## Performance

Parsing is the expensive part, so standalone files are parsed once at load and
embedded `runHaxeCode` snippets have their ASTs **cached** — a repeated call with the
same source does not re-parse. Interpretation still costs more than compiled Haxe: do
not call `runHaxeCode` from `onUpdate`. Define functions once in `onCreate` and call
them later, or use a standalone script whose hooks are already parsed functions.

```lua
function onCreate()
    runHaxeCode([[
        function spawnThing(x:Float, y:Float) {
            var s = new FlxSprite(x, y);
            s.makeGraphic(20, 20, FlxColor.WHITE);
            game.add(s);
        }
    ]]);
end

function onBeatHit()
    runHaxeFunction('spawnThing', {math.random(0, 1000), 300});
end
```

## File-based state scripts

State scripts are a different host again: `.hx` files under `data/states/` run on
`psychlua.HaxeScript`, discovered by `psychlua.StateScripts` from
`data/states/<Name>.hx` (not the PlayState script scopes above). Overlay every menu/pause/game
over, or switch to a blank `ModState`. See [Scripted states](./scripted-states.md).

## Limits

- HScript is **interpreted Haxe**, not compiled Haxe: no macros, no type checking,
  and generics behave loosely. Type annotations are parsed and ignored. Scripted
  *classes*/states are a separate feature — standalone scripts are hook functions,
  like Lua/Python.
- Code that works in a desktop build may fail elsewhere if it touches APIs that are
  gated by a feature flag in that build.
- Exceptions are caught per call and reported like other script errors, but a bad
  interaction with engine state (null characters, removed sprites) can still produce
  odd behaviour. Null-check `game.boyfriend` and friends in `onCreate`.

## When to use what

| Need | Use |
|---|---|
| Standard modding (sprites, tweens, events, camera) | [Lua](./lua-scripting.md) or [Python](./python-scripting.md) |
| Typed-feeling logic against real engine classes, no Lua parent | standalone `.hx` / `.hscript` |
| One call into an engine class the API misses, from Lua | `getPropertyFromClass` / `setPropertyFromClass` |
| Real logic against Haxe types, from Lua | embedded HScript (`runHaxeCode`) |
| New engine behaviour used by many mods | add a callback in `psychlua/callbacks/` and send a PR |
