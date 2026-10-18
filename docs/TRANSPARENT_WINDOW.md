# Transparent window

Phoenix can punch a hole in its own window, so the desktop shows through — the
"4th wall breaking" effect used by desktop-pet / overlay mods (issue #95).

Two independent effects are exposed:

| Effect | What it does | Platforms |
|---|---|---|
| **Color-key transparency** | every pixel painted with the transparency color (`RGB(1, 1, 1)` by default) becomes see-through | Windows |
| **Whole-window alpha** | the whole window is drawn translucent (`0.0` invisible → `1.0` opaque) | Windows, Linux, macOS |
| **Click-through** | the window ignores the mouse, so clicks land on whatever is behind it | Windows |

Everything is a **safe no-op with one logged message** on targets that cannot do
it (HTML5, Flash/AIR, Android, iOS): the setters return `false`, never throw, and
never leave the window in a broken state.

## How it works

```
mods/MyMod/scripts/overlay.lua
        │  setWindowTransparent(true)
        ▼
backend.TransparentWindow      ← state, platform guard, fullscreen handling
        │
        ▼
backend.FlxTransWindow         ← Win32: WS_EX_LAYERED + SetLayeredWindowAttributes
                                 others: Lime/SDL window.opacity (alpha only)
```

The Windows path is a port of
[`FlxTransWindow.hx`](https://github.com/notmagniill/psych-engine-modified-build/blob/stable/source/backend/FlxTransWindow.hx)
from **psych-engine-modified-build** by *notmagniill*, extended with:

- an `HWND` lookup that can only return a window owned by this process (the
  port called `GetActiveWindow()` blindly, which can hit another application
  when the game is unfocused);
- whole-window alpha applied together with the color key — `SetLayeredWindowAttributes()`
  replaces the previous attribute, so asking for `LWA_COLORKEY` alone would drop
  the alpha (and the other way round);
- click-through (`WS_EX_TRANSPARENT`);
- a full "undo" (`clearTransparentWindow`).

Off Windows the alpha goes through Lime (`window.opacity`, i.e.
`SDL_SetWindowOpacity`), which is the only part the other desktops support.

## Fullscreen and window mode

Transparency only makes sense on a windowed game, so the API handles the window
mode for you:

- `setEnabled(true)` while the game is fullscreen **leaves fullscreen first**
  (and logs why).
- Entering fullscreen (F11, `FlxG.fullscreen = true`, a script, …) **suspends**
  the effect; it comes back automatically as soon as the game is windowed again.
  `TransparentWindow.enabled` stays `true` during the suspension — use
  `TransparentWindow.isActive` to know what the window is doing right now.

The watcher is installed once by `Main.setupGame()` (`TransparentWindow.init()`)
and costs a single boolean comparison per frame until transparency is enabled.

## Haxe

```haxe
import backend.TransparentWindow;

// Paint the background with the color key, then punch it out.
FlxG.camera.bgColor = 0xFF010101;

TransparentWindow.setColorKey(0xFF010101); // optional, this is the default
TransparentWindow.setAlpha(0.85);          // whole-window opacity (Windows/Linux/macOS)
TransparentWindow.setEnabled(true);        // see-through (Windows)
TransparentWindow.setClickThrough(true);   // let the mouse through (Windows)

TransparentWindow.reset();                 // back to a normal, opaque window
```

| Member | Meaning |
|---|---|
| `setEnabled(bool)` / `enable()` / `disable()` / `toggle()` | color-key transparency; returns whether it was applied |
| `setAlpha(0..1)` | whole-window opacity; returns whether it was applied |
| `setColorKey(FlxColor)` | the color that renders see-through |
| `setClickThrough(bool)` | `WS_EX_TRANSPARENT` on/off |
| `apply()` | re-applies every stored setting (after the window was recreated) |
| `reset()` | opaque, clickable window, all settings forgotten |
| `isSupported` / `supportsColorKey` / `supportsAlpha` / `supportsClickThrough` | what works on the running target |
| `isActive` | `enabled` **and** not suspended by fullscreen |
| `parseColor(Dynamic)` | reads a script-side color: `0xFF010101`, `'010101'`, `'#010101'`, `'0xFF010101'` |

## Lua

```lua
function onCreatePost()
    if not isWindowTransparencySupported() then return end

    -- The pixels of this color disappear; the game background has to be it.
    setProperty('camGame.bgColor', '010101')
    setWindowTransparencyColor('010101')
    setWindowAlpha(0.9)
    setWindowTransparent(true)
    setWindowClickThrough(true)
end

function onDestroy()
    setWindowTransparent(false)   -- always clean up: the window outlives the script
end
```

## Python

```python
def onCreatePost():
    if not isWindowTransparencySupported():
        return

    setProperty('camGame.bgColor', '010101')
    setWindowTransparencyColor('010101')
    setWindowAlpha(0.9)
    setWindowTransparent(True)
    setWindowClickThrough(True)


def onDestroy():
    setWindowTransparent(False)
```

| Lua / Python function | Arguments | Returns |
|---|---|---|
| `setWindowTransparent(enable = true)` | `bool` | applied? |
| `getWindowTransparent()` | – | `bool` |
| `setWindowAlpha(alpha)` | `0.0` – `1.0` | applied? |
| `getWindowAlpha()` | – | last alpha |
| `setWindowTransparencyColor(color)` | number or string | applied? |
| `setWindowClickThrough(enable = true)` | `bool` | applied? |
| `isWindowClickThrough()` | – | `bool` |
| `isWindowTransparencySupported()` | – | `bool` |
| `applyWindowTransparency()` | – | active? |

The names are identical in both languages (they are registered in
`psychlua/callbacks/WindowCallbacks.hx` and `psychlua/pystdlib/PyWindowLib.hx`),
and both lists are published in the generated API references.

## HScript

```haxe
addHaxeLibrary('TransparentWindow', 'backend');
TransparentWindow.setEnabled(true);
```

## Modding notes and pitfalls

- **The color key has to be painted.** Nothing becomes transparent until the
  background actually uses `colorKey`. Only the game camera is punched out — HUD,
  sprites and characters stay visible unless you also clear their backgrounds.
- **Clean up.** The window outlives the script: disable transparency in
  `onDestroy` (or when the song ends), otherwise the player is left with a hole
  in their game.
- **Click-through swallows input.** A click-through window cannot be clicked, so
  only enable it if the mod does not need the mouse (and remember the player can
  still use the keyboard).
- **Windows only for the real effect.** On Linux and macOS `setWindowAlpha()`
  works but `setWindowTransparent()` logs a message and returns `false`.
- **Never persisted.** Nothing is written to `ClientPrefs`: a mod that forgets to
  reset cannot leave the player with a permanently transparent game.

## Regression tests

```sh
python3 -m unittest discover -s tests -p 'test_transparent_window.py' -v
```

`tests/test_transparent_window.py` pins the platform guards, the Lua/Python
symmetry and the credits, without needing a Haxe toolchain.
