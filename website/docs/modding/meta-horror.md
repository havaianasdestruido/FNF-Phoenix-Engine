---
title: 4th wall breaking (META_HORROR)
sidebar_position: 55
description: The 4th-wall-breaking system effects (wallpaper, taskbar, volume, mouse/keyboard) and how to use them safely.
---

# 4th wall breaking (META_HORROR)

Phoenix Engine can break the fourth wall: horror mods can mess with the
player's desktop — swap the wallpaper, hide the taskbar or other windows,
control system volume, move the mouse or type into other applications.

These effects are **only compiled into `-DMETA_HORROR` builds**. On a normal
build the functions all exist but do nothing and print
`... requires a -DMETA_HORROR build of Phoenix Engine.` to the debug text, so
your mod degrades gracefully.

:::warning[Warn your players]

These effects are scary *on purpose*. If your mod uses them, say so in the mod
description and warn the player before they trigger — mods that mess with the
player's system silently are indistinguishable from scareware, and engines
shipping that by default get flagged by antivirus tools. This is also why the
engine keeps the feature behind `-DMETA_HORROR`.

:::

## Quick example

```lua
function onCreatePost()
    if isRecording() then
        -- someone is streaming: keep it safe
        return
    end

    setWallpaper('horror/desktop', false) -- mods/images/horror/desktop.png
    hideTaskbar()
    setSysVolume(100)
end

function onSongEnd()
    -- clean up after the effect
    restoreWallpaper()
    restoreTaskbar()
    resetWindowEffects()
end
```

HScript has access to the same functions (they are registered for both
languages) and can also call `backend.MetaHorror` directly from `runHaxeCode`.

## Function reference

### Detecting streamers

| Function | Returns |
| --- | --- |
| `isRecording()` | `true` when OBS, Bandicam, Fraps, XSplit, Hycam2 or Twitch Studio seems to be running. Fails **open** (returns `true`) when the process list cannot be read, so an error never leaks content to a live stream |

You can add more names by editing `backend.MetaHorror.programList` in Haxe.

### Wallpaper

| Function | Effect |
| --- | --- |
| `setWallpaper(path, ?absolute = false)` | Change the desktop wallpaper. `absolute=false` resolves `mods/images/<path>.png` first, then any embedded asset (embedded art is dumped to a temp file automatically, because the OS needs a real file). Windows only |
| `restoreWallpaper()` | Restore the wallpaper from before the first `setWallpaper` of this session |
| `killWallpaperApps()` | Force-close Lively / Wallpaper Engine processes so your swap is actually visible (they redraw over the wallpaper). Windows only |

The wallpaper that was there before your swap is always remembered for
`restoreWallpaper()` — use it in `onSongEnd`, `onGameOver`, etc.

### Taskbar & other windows

| Function | Effect |
| --- | --- |
| `hideTaskbar()` / `restoreTaskbar()` | Hide / bring back the Windows taskbar |
| `hideAllWindows()` | Hide every visible window except the game (and the shell). Returns how many were hidden |
| `restoreAllWindows()` | Bring back everything `hideAllWindows()` hid (without stealing focus) |

### The game window

| Function | Effect |
| --- | --- |
| `removeWindowIcon()` | Remove the window icon and with it the system menu (close/minimize/maximize). Windows only |
| `setWindowAlpha(alpha)` | Whole-window opacity, `0.0` (invisible) to `1.0` (opaque). Windows only |
| `setWindowColorKey(color)` | Pixels whose color equals `color` (a `0xRRGGBB` integer) become see-through to the desktop. Windows only |
| `resetWindowEffects()` | Restore the window's original style — undoes `setWindowAlpha` and `setWindowColorKey` |

### System volume, mouse & keyboard

| Function | Effect |
| --- | --- |
| `setSysVolume(percentage)` | Set the system master volume, 0-100. Windows only |
| `getSysVolume()` | Read the master volume back (`-1` if unavailable) |
| `setSysMute(mute)` / `getSysMute()` | Mute / unmute (read back) the default output device |
| `moveMousePos(x, y)` | Move the cursor by a relative offset in pixels |
| `typeText(text, ?delay = 0.05)` | Type `text` into whatever window has focus, `delay` seconds per character. `\n` = Enter, `\t` = Tab, `\b` = Backspace. A second call cancels the first |

These are implemented natively (WASAPI / Win32 `SendInput`) — the game never
needs an external helper binary.

### Files & info

| Function | Effect |
| --- | --- |
| `openFile(path)` | Open a file with the OS default application (Notepad, an image viewer...). Windows/Linux/macOS |
| `duplicateImage(imageFile, finalFileName, ?fileType = 'png', ?location)` | "Leak" a game image to disk. Returns the written path, or `null` on failure. Default location: `<temp>/phoenix_horror` |
| `getSystemRAM()` | Installed system RAM in megabytes |

## Behaviour on unsupported platforms

Every function compiles on every target and returns its failure value
(`false`, `0`, `null`) when the platform cannot do the effect, tracing the
reason. Windows-only effects are exactly the ones the desktop has — Linux and
macOS support `isRecording`, `openFile` and `duplicateImage` (desktop builds).

## Credits

Ported (with adaptation) and credited upstream:

- [psych-engine-modified-build](https://github.com/notmagniill/psych-engine-modified-build)
  — `CoolUtil.hx` `META_HORROR` section (Apache License 2.0).
- [Mario Madness](https://github.com/Dewott2501/Mario-Madness) — `CppAPI.hx`
  and its `WindowsData` / `Wallpaper` / `Transparency` helpers
  (Apache License 2.0).

Upstream's `nircmd`-based volume/mouse/keyboard helpers were re-implemented
natively, `obtainRAM` now uses the engine's own `debug.system.SystemInfo`, and
the window style effects gained a working reset — see
[`docs/META_HORROR.md`](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/blob/main/docs/META_HORROR.md)
in the repository for the full engineering notes.
