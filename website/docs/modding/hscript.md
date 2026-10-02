---
title: HScript
sidebar_position: 50
description: Running Haxe code from a script when the Lua or Python API is not enough.
---

# HScript

HScript runs **Haxe source at runtime** through `hscript-improved`. It is the escape hatch
for things the Lua/Python API does not expose: constructing arbitrary Flixel objects,
calling static methods, subclassing behaviour on the fly.

Requires `HSCRIPT_ALLOWED` — enabled on desktop, mobile and web (not Flash/AIR).
`project.hxp` also sets `hscriptPos`, so runtime errors carry line numbers.

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
host, and `HScript.initHaxeModule(parent)` creates the interpreter lazily on the first
use, so scripts that never touch Haxe pay nothing.

On the engine side the API is:

```haxe
HScript.execute(codeToRun, ?funcToRun, ?funcArgs):Dynamic
HScript.executeFunction(funcToRun, funcArgs):Dynamic
```

## What is in scope

The interpreter is seeded with the engine's common types and a handle to the running
state. In practice you get:

- `game` — the `PlayState` instance (`PlayState.instance`),
- Flixel essentials (`FlxSprite`, `FlxG`, `FlxTween`, `FlxEase`, `FlxTimer`, `FlxColor`, …),
- engine classes such as `Paths`, `ClientPrefs`, `Conductor`, `Character`, `Note`,
- `Std`, `Math`, `StringTools` and the other usual Haxe statics.

Anything else can be reached with `Type.resolveClass('backend.ClientPrefs')`.

## Performance

Parsing is the expensive part, so the engine **caches parsed ASTs** — a repeated
`runHaxeCode` of the same source does not re-parse. That still leaves interpretation cost:
do not call `runHaxeCode` from `onUpdate`. The right pattern is to define functions once
in `onCreate` and call them later.

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

## Limits

- HScript is **interpreted Haxe**, not compiled Haxe: no macros, no type checking,
  no `#if` conditionals, and generics behave loosely.
- Code that works in a desktop build may fail elsewhere if it touches APIs that are gated
  by a feature flag in that build.
- Exceptions are caught per call and reported like other script errors, but a bad
  interaction with engine state (null characters, removed sprites) can still produce odd
  behaviour.

## When to use what

| Need | Use |
|---|---|
| Standard modding (sprites, tweens, events, camera) | [Lua](./lua-scripting.md) or [Python](./python-scripting.md) |
| One call into an engine class the API misses | `getPropertyFromClass` / `setPropertyFromClass` |
| Real logic against Haxe types | HScript |
| New engine behaviour used by many mods | add a callback in `psychlua/callbacks/` and send a PR |
