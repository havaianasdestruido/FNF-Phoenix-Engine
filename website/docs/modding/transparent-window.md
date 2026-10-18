---
title: Transparent window
sidebar_position: 45
description: Punch a hole in the game window — color-key transparency, whole-window alpha and click-through for overlay/desktop-pet mods.
---

# Transparent window

Phoenix can make its own window (partially) see-through, so the desktop shows
behind the game. It is what overlay and "desktop pet" mods need, and it is
exposed to Lua, Python and Haxe.

| Effect | What it does | Platforms |
|---|---|---|
| Color-key transparency | every pixel painted with the transparency color (`RGB(1, 1, 1)` by default) becomes see-through | Windows |
| Whole-window alpha | the window is drawn translucent (`0.0` invisible → `1.0` opaque) | Windows, Linux, macOS |
| Click-through | the window ignores the mouse, clicks land on what is behind it | Windows |

On HTML5, Flash/AIR, Android and iOS every call is a **no-op that logs one line**
and returns `false`, so a mod can call them unconditionally.

## Quick start (Lua)

```lua
function onCreatePost()
    if not isWindowTransparencySupported() then return end

    -- The pixels of this color disappear — the game background has to be it.
    setProperty('camGame.bgColor', '010101')
    setWindowTransparencyColor('010101')
    setWindowAlpha(0.9)
    setWindowTransparent(true)
end

function onDestroy()
    setWindowTransparent(false)   -- the window outlives the script: clean up
end
```

## Quick start (Python)

```python
def onCreatePost():
    if not isWindowTransparencySupported():
        return

    setProperty('camGame.bgColor', '010101')
    setWindowTransparencyColor('010101')
    setWindowAlpha(0.9)
    setWindowTransparent(True)


def onDestroy():
    setWindowTransparent(False)
```

## Functions

Identical names in both languages — see
[Lua API reference](./lua-api-reference.md#window) and
[Python API reference](./python-api-reference.md#window):

`setWindowTransparent(enable = true)`, `getWindowTransparent()`,
`setWindowAlpha(alpha)`, `getWindowAlpha()`,
`setWindowTransparencyColor(color)`, `setWindowClickThrough(enable = true)`,
`isWindowClickThrough()`, `isWindowTransparencySupported()`,
`applyWindowTransparency()`.

From Haxe:

```haxe
import backend.TransparentWindow;

TransparentWindow.setColorKey(0xFF010101);
TransparentWindow.setAlpha(0.85);
TransparentWindow.setEnabled(true);
TransparentWindow.setClickThrough(true);
```

…or from HScript with `addHaxeLibrary('TransparentWindow', 'backend')`.

## Fullscreen

Transparency only makes sense on a windowed game, so the engine handles the
window mode:

- enabling it while fullscreen **leaves fullscreen** first;
- entering fullscreen (F11, a script, …) **suspends** the effect, which comes
  back as soon as the game is windowed again — no setting is lost, and
  `TransparentWindow.isActive` reports what the window is doing right now.

## Pitfalls

- **Paint the color key.** Nothing turns transparent until the background
  actually uses `colorKey`. Only that color is punched out: HUD, sprites and
  characters stay visible.
- **Click-through needs a layered window** (`setWindowTransparent(true)` or an
  alpha below `1`), otherwise Windows ignores the flag — and it also means the
  player cannot click the game any more.
- **Clean up in `onDestroy`.** The window outlives the script.
- **Nothing is persisted.** There is no `ClientPrefs` entry on purpose: a mod
  that forgets to reset cannot leave the player with a permanently transparent
  game.

The full technical write-up — the Win32 implementation, the ported code and its
credits, and the platform guard internals — lives in
[`docs/TRANSPARENT_WINDOW.md`](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/blob/main/docs/TRANSPARENT_WINDOW.md).
