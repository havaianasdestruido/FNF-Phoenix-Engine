---
title: stdfire utilities
sidebar_position: 55
description: Cross-platform window titles, native message boxes and small non-modal warnings for softmods.
---

# stdfire utilities

`stdfire` is a built-in namespace, available without an import to Lua, Python/Hython,
and standalone or embedded HScript whenever that scripting host is enabled. It is
also available to sandboxed mods; it does not require `META_HORROR`.

| Function | Purpose |
|---|---|
| `stdfire.NativeTitleRename(title)` | Set the running window, browser tab or mobile activity/scene title. Pass `nil` / `None` / `null` to restore the engine title. |
| `stdfire.NativeMSGBox(message, title?)` | Show a **modal** native message box. The optional title defaults to `Phoenix Engine`; browsers ignore it. |
| `stdfire.NativeWarn(message, title?)` | Show a short **non-modal** warning. The optional title defaults to `Phoenix Engine` where supported. |

All three return a boolean. `true` means the request was accepted or queued, not that
the OS or browser actually displayed it; `false` means invalid input, no suitable
window/platform, or a rejected request. In particular, Lime's native dialog API
discards SDL's display status, so even a returned `true` cannot confirm the dialog
appeared. Android's dialog reports `false` for a rejected activity or UI-thread
call, or a non-OK dialog result. A title reset with no active override is a
successful no-op. A null message is invalid; warnings must also contain non-whitespace
text. Unicode text is supported; embedded NUL characters are rejected rather than
silently truncating text on native platforms.

The title override is **global to the running game**, not private to a script. Normal
song/menu title updates do not overwrite it. Reset it when you are finished; resetting
restores the **latest** engine title, even if the song or menu changed meanwhile.
Other mods can change or reset the same override, so coordinate if several scripts use it.
Direct window-title effects, such as `META_HORROR`, can temporarily replace the displayed
title; the next normal engine update reapplies the override. Neither mobile implementation
changes the installed app's launcher name.

```lua
-- mods/MyMod/scripts/notice.lua
function onCreatePost()
    stdfire.NativeTitleRename('My mod')
    stdfire.NativeWarn('Good luck!')
end

function onDestroy()
    stdfire.NativeTitleRename(nil) -- restore the engine's current title
end

-- For a deliberately modal dialog, for example from a one-time event:
-- stdfire.NativeMSGBox('Please read this.', 'My mod')
```

```python
def onCreatePost():
    stdfire.NativeTitleRename('My mod')
    stdfire.NativeWarn('Good luck!')

def onDestroy():
    stdfire.NativeTitleRename(None)
```

```haxe
function onCreatePost() {
    stdfire.NativeTitleRename('My mod');
    stdfire.NativeWarn('Good luck!');
}
function onDestroy() {
    stdfire.NativeTitleRename(null);
}
```

## Platform behavior

| Target | Title | `NativeMSGBox` | `NativeWarn` |
|---|---|---|---|
| Windows (native) | Lime/SDL window title | Owned Unicode Win32 `MessageBoxW` | Win32 notification-area balloon; Windows may route or suppress it |
| Linux (native) | Lime/SDL window title | SDL native dialog | Desktop notification via `notify-send` (must be installed) |
| macOS (native) | Lime/SDL window title | SDL native dialog | Desktop notification via `osascript`; notification settings may suppress it |
| HTML5 | Browser tab (`document.title`) | Browser `alert(message)`; title ignored | Brief in-page toast, no browser notification permission; title ignored |
| Android | Activity and recent-task label; not the launcher label | SDL's native Android dialog, called through a Unicode-safe bridge | Short text `Toast`, normally at the bottom; title ignored |
| iOS | Foreground scene title on iOS 13+, plus the root controller title when available | SDL native dialog | Brief non-modal UIKit banner; title ignored |
| Flash/AIR or an unsupported warning backend | Unsupported | Unsupported | Returns `false`, never replaced with a message box |

Android's dialog must be called from the game thread, not the Android UI thread; a
UI-thread call returns `false` to avoid deadlocking. Android 11+ controls the position
of text toasts; earlier Android versions explicitly request bottom placement. On iOS a
scene/window may not exist, particularly in a legacy scene-less application, so a
queued title or banner is best effort. Linux and macOS
notifications depend on their desktop/session services. Their helpers run off the game
thread; a `true` result means queued even if the helper later fails or is missing. Desktop
non-C++ builds do not provide `NativeWarn` and return `false`.

A message box can block the game or browser until dismissed, so do not trigger one
every frame or during time-critical play. Use `NativeWarn` sparingly for small
messages, not for a stream of alerts. Multiple browser, Android and iOS warnings
replace the preceding toast/banner. On Linux and macOS, a busy helper retains only the
latest pending warning rather than building an unbounded queue.
