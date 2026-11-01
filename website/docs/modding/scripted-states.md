---
title: Scripted states
sidebar_position: 45
description: Softcode menus, pause, game over and custom screens with data/states/Name.hx.
---

# Scripted states and substates

Phoenix loads HScript files from **`data/states/<Name>.hx`** (also `.hscript` / `.hxs`)
in the current mod, global mods, `mods/data/states/`, and `assets/` preload. Every
`MusicBeatState` and `MusicBeatSubstate` participates — menus, pause, game over,
credits, freeplay, the fade transition, `PlayState`, and so on.

Requires `HSCRIPT_ALLOWED` (desktop, mobile, web — not Flash/AIR). Files are scanned
by [script security](./script-security.md) before they run.

## Overlay an existing screen

Drop a file named after the class:

```text
mods/MyMod/data/states/FreeplayState.hx
mods/MyMod/data/states/MainMenuState.hx
mods/MyMod/data/states/PauseSubState.hx
mods/MyMod/data/states/GameOverSubstate.hx
mods/MyMod/data/states/CreditsState.hx
mods/MyMod/data/states/CustomFadeTransition.hx
```

The source state still runs. Your script gets `state` / `game` pointing at that
instance and can add sprites, listen to beats, or `return Function_Stop` from
`onClose` to keep a substate open.

```haxe
function onCreatePost() {
    var watermark = new FlxText(8, 8, 0, "modded freeplay");
    watermark.setFormat(Paths.font("vcr.ttf"), 16, 0xFFFFFFFF);
    state.add(watermark);
}
```

## Replace a screen entirely (`ModState`)

`states.ModState` is an empty `MusicBeatState` whose whole UI comes from the script.
From Lua or Python:

```lua
switchCustomState("MyMenu")           -- data/states/MyMenu.hx
openModSubState("MyPause")            -- data/states/MyPause.hx
if customStateExists("MyMenu") then
    switchCustomState("MyMenu", {from = "freeplay"})
end
```

From HScript:

```haxe
switchCustomState("MyMenu", {from: "freeplay"});
openModSubState("MyPause");
```

`FlxG.switchState(() -> new ModState("MyMenu", data))` works from compiled code.
`data` is exposed to the script as `data` (and on the state as `state.data`).
`ModState.lastName` / `lastData` survive `FlxG.resetState()`.

`CustomSubstate` remains the PlayState helper (`openCustomSubstate(name, pauseGame)`
plus `onCustomSubstate*` hooks). It now also loads `data/states/<name>.hx` and can
be opened from any state, not only `PlayState`.

## Callbacks

Psych-style names and CNE-style aliases are both called:

| Psych | CNE alias | When |
|---|---|---|
| `onCreate` | `create` | end of `MusicBeatState.create` |
| `onCreatePost` | `postCreate` | first `update` after create |
| `onUpdate(elapsed)` | `update` | every frame |
| `onUpdatePost(elapsed)` | `postUpdate` | after `super.update` |
| `onDestroy` | `destroy` | before the state is destroyed |
| `onBeatHit(curBeat)` | `beatHit` | conductor beat |
| `onStepHit(curStep)` | `stepHit` | conductor step |
| `onSectionHit(curSection)` | `sectionHit` | states only |
| `onClose` | | substates; `Function_Stop` cancels `close()` |

Top-level code in the file runs when the script is loaded (start of `create`).

## What is in scope

Same seed as Lua-hosted HScript, plus `state`, `ModState`, `ModSubState`,
`StateScripts`, `switchCustomState`, `openModSubState`, `Function_Stop` /
`Function_Continue`. Pull extra types with `addHaxeLibrary('FreeplayState', 'states')`.

See [HScript](./hscript.md) and `docs/TemplateState.hx`.
