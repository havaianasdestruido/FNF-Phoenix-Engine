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
| `stdfire.NativeTitleRename(title)` | Set the running window, browser tab or mobile activity/scene title. Pass `nil` / `None` / `null` to conditionally restore the previous title. |
| `stdfire.NativeMSGBox(message, title?)` | Show a **modal** native message box. The optional title defaults to `Phoenix Engine`; browsers ignore it. |
| `stdfire.NativeWarn(message, title?)` | Show a short **non-modal** warning. The optional title defaults to `Phoenix Engine` where supported. |

All three return a boolean. `true` means the request was accepted or queued, not that
the OS or browser actually displayed it; `false` means invalid input, no suitable
window/platform, or a rejected request. In particular, Lime's native dialog API
discards SDL's display status, so even a returned `true` cannot confirm the dialog
appeared. Android's dialog reports `false` for a rejected activity or UI-thread
call, or a non-OK dialog result. A title reset with no prior stdfire title is a
successful no-op. A null message is invalid; warnings must also contain non-whitespace
text. Unicode text is supported; embedded NUL characters are rejected rather than
silently truncating text on native platforms.

`stdfire` **complements** the engine's existing `Application` calls; it does not
intercept or replace them. A title change applies immediately (or is queued on mobile),
but a later engine, `META_HORROR`, or other mod title update can overwrite it. A mod
can set the title again when appropriate.

Title changes are global to the running game, not private to a script. Passing
`nil` / `None` / `null` restores the title observed before the current sequence of
stdfire changes **only if** the same window/tab still shows the last stdfire title.
If another update changed the title, or the window was replaced, reset leaves that
new title alone. While a stdfire title is active, reset returns `false` if the current
title cannot be observed, or if it still matches but the previous title is unknown.
Two updates to the exact same text cannot be distinguished without intercepting engine
writes. Coordinate if several scripts change or reset the title.
Neither mobile implementation changes the installed app's launcher name.

```lua
-- mods/MyMod/scripts/notice.lua
function onCreatePost()
    stdfire.NativeTitleRename('My mod')
    stdfire.NativeWarn('Good luck!')
end

function onDestroy()
    stdfire.NativeTitleRename(nil) -- restore the previous title if it is still ours
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

## Self-test on this device

**Options → Secret Debug Menu → stdfire Self-Test** opens a page that calls every function
above on the running build. Each row reports `PASS`, `FAIL`, `SKIP` or `READY`, with the
exact result underneath the selected row.

- Opening the page runs every check that shows nothing: the interpreter namespace, the
  title rename (which always restores the title it found), and the null/blank/NUL
  rejections.
- The two rows that display something real stay `READY` until you select them and press
  `ACCEPT`, or press `R` to run everything. The message box is modal, so it blocks the
  game until dismissed.
- `SKIP` means this build has no backend for that function — a non-C++ desktop build has
  no `NativeWarn`, and Flash/AIR has neither — so the documented `false` is reported as a
  skip instead of a failure.
- `PASS` on an interactive row means the request was accepted, not that the OS drew it;
  check the dialog or toast on screen.

The same checks run headless in `tests/haxe/run-stdfire.sh` (`StdFireSelfTestSpec`), and
the page never writes to the save file.
