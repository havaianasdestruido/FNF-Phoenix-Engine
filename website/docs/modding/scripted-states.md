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

## A complete `ModState` screen

`data/states/CreditsCard.hx` — a screen of its own, reachable with
`switchCustomState("CreditsCard")`. Top-level code runs when the script loads, so
`var` declarations belong there:

```haxe
// mods/MyMod/data/states/CreditsCard.hx
var title:FlxText;
var body:FlxText;
var hint:FlxText;

function onCreatePost() {
    title = new FlxText(0, 120, FlxG.width, 'CREDITS', 48);
    title.setFormat(Paths.font('vcr.ttf'), 48, 0xFFFFEE88, 'center');
    title.screenCenter();      // XY
    title.y = 120;             // put it back at the top
    state.add(title);

    body = new FlxText(0, 220, FlxG.width, 'Art: me\nMusic: someone else', 24);
    body.setFormat(Paths.font('vcr.ttf'), 24, 0xFFFFFFFF, 'center');
    state.add(body);

    hint = new FlxText(0, FlxG.height - 80, FlxG.width, 'Press ENTER or ESC', 20);
    hint.setFormat(Paths.font('vcr.ttf'), 20, 0xFFAAAAAA, 'center');
    state.add(hint);

    // Any payload passed to switchCustomState() arrives as `data`.
    if (data != null && data.from != null)
        debugPrint('opened from ' + data.from);
}

function onUpdate(elapsed:Float) {
    if (FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.ESCAPE) {
        FlxG.switchState(MainMenuState.new);   // needs the import below
    }
}

function onBeatHit(curBeat:Int) {
    // Little scale pop on every 4th beat: grow, then settle back.
    if (curBeat % 4 == 0)
        FlxTween.tween(title.scale, {x: 1.05, y: 1.05}, 0.12, {
            ease: FlxEase.quadOut,
            onComplete: function(_) FlxTween.tween(title.scale, {x: 1, y: 1}, 0.2)
        });
}
```

`FlxG.switchState(MainMenuState.new)` needs `MainMenuState` to be resolvable, which the
seeded scope does not include — either declare `import states.MainMenuState;` at the top
of the file or call `addHaxeLibrary('MainMenuState', 'states')` first. A `.hscript` file
in a sandboxed mod cannot resolve extra classes at all, so keep menu navigation in
`switchCustomState(...)` there.

## A pause-menu substate

`data/states/PauseMenu.hx` opened from a PlayState script with
`openCustomSubstate('PauseMenu', true)`:

```haxe
// mods/MyMod/data/states/PauseMenu.hx
var box:FlxSprite;
var resumeBtn:FlxText;

function onCreate() {
    box = new FlxSprite(0, 0).makeGraphic(420, 220, 0xFF101018);
    box.screenCenter();
    box.alpha = 0.92;
    state.add(box);

    resumeBtn = new FlxText(box.x + 40, box.y + 40, box.width - 80, 'RESUME', 28);
    resumeBtn.setFormat(Paths.font('vcr.ttf'), 28, 0xFFFFFFFF, 'center');
    state.add(resumeBtn);

    debugPrint('pause menu opened for ' + customSubstateName);
}

function onUpdate(elapsed:Float) {
    if (FlxG.keys.justPressed.ENTER || FlxG.mouse.justPressed)
        state.close();                 // runs onClose first
}

function onClose() {
    debugPrint('pause menu closed');
    return Function_Continue;
}
```

The substate's own camera is the last camera in `FlxG.cameras.list`, so sprites added here
draw above the song without extra setup. Return `Function_Stop` from `onClose` to keep the
menu open (for example while an animation plays).

## Calling state scripts from Lua or Python

```lua
function onEvent(name, value1, value2)
    if name == 'Open Credits' then
        if customStateExists('CreditsCard') then
            switchCustomState('CreditsCard', {from = 'song'})
        else
            debugPrint('data/states/CreditsCard.hx is missing from this mod')
        end
    end
end
```

`customStateExists` checks every folder in the state-script search order, so a global mod
that ships the file counts too.

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

Same seed as Lua-hosted HScript (including `SystemInfo` and
`getMonotonicSeconds()` / `getProcessCPUSeconds()` / `getLogicalCPUCount()` /
`getPageSize()` / `getTotalPhysicalMemory()`), plus `state`, `ModState`,
`ModSubState`, `StateScripts`, `switchCustomState`, `openModSubState`,
`Function_Stop` / `Function_Continue`. Pull extra types with
`addHaxeLibrary('FreeplayState', 'states')`.

See [HScript](./hscript.md) and `docs/TemplateState.hx`.
