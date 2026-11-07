# Windows desktop integration

The `Windows` class exposes native desktop operations to Haxe. All setters
return `true` only when the native request succeeds. Other targets return
`false` without changing the game. These operations never change game graphics.

`Windows` is a root typedef for `backend.Windows`, the implementation class.
The split keeps hxcpp's generated `include/backend/Windows.h` away from the
case-insensitive `windows.h` filename in the Windows SDK.

## Window ownership

Native operations resolve the current Lime window by its title, SDL window
class, and owning process. Foreign foreground windows are rejected. If multiple
windows in this process match an empty title, the lookup fails rather than
guessing. Cached handles are revalidated after frame recreation.

## Transparency

- `Windows.__setWindowTransparencyAlpha(alpha)` accepts opacity from `0.0` to
  `1.0` (out-of-range values are clamped).
- `Windows.__setWindowTransparencyColor(0xRRGGBB, enabled)` enables/disables a
  color key. Paint the game background the same color to see the desktop.
- `PlatformUtil.setWindowOpacity(alpha)` is the platform utility entry point.
- `Windows.setWindowClickThrough(enabled)` controls mouse passthrough.
- `Windows.resetWindowTransparency()` removes Phoenix's layered effects without
  overwriting unrelated extended window styles.

Alpha and color key are stored together and passed to
`SetLayeredWindowAttributes` in one request, so changing one does not drop the
other. Click-through retains an opaque alpha attribute when needed. The native
layer uses pointer-sized `SetWindowLongPtrW` on both 32-bit and 64-bit builds.

Phoenix's pinned SDL registers `SDL_app` with `CS_OWNDC`. Win32 explicitly
forbids combining `CS_OWNDC` or `CS_CLASSDC` with `WS_EX_LAYERED`, so the native
backend temporarily clears only those incompatible class bits before setting
the layered style. SDL has already retained its window HDC at that point. All
other class bits are preserved, and the original class style is restored after
the last layered effect is removed or if applying the effect fails. Removing
layering also performs the documented client/non-client repaint with
`RDW_ERASE | RDW_INVALIDATE | RDW_FRAME | RDW_ALLCHILDREN | RDW_UPDATENOW`.

References: Microsoft documents the class-style restriction in
[SetWindowLong](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setwindowlonga)
and [Extended Window Styles](https://learn.microsoft.com/en-us/windows/win32/winmsg/extended-window-styles),
and the required removal/repaint sequence in
[Using Layered Windows](https://learn.microsoft.com/en-us/windows/win32/winmsg/using-windows#using-layered-windows).

Mods should prefer `backend.TransparentWindow` and the existing symmetric
Lua/Python `setWindowAlpha` / `setWindowTransparent` callbacks: that API also
suspends effects in fullscreen and restores them when windowed. The legacy
`FlxTransWindow`, `PlatformUtil.getWindowsTransparent/getWindowsBackward`, and
META_HORROR window effects share this native state rather than competing with it.

## Validation

`bash tests/native/run.sh` runs the native state/ownership tests with a Win32
test double. Set `PHOENIX_WINDOWS_CXX` to a Windows-targeting C++ compiler to
additionally check the header against the real Windows SDK. Visual DWM effects
and notification presentation still require a real Windows desktop session.

## Dark frame

`Windows.setDarkMode(enabled)` and `system.Window.setDarkMode(enabled)` request
`DWMWA_USE_IMMERSIVE_DARK_MODE` (attribute 20), falling back to attribute 19 on
older Windows 10 builds. This changes only the DWM title bar/frame, not Flixel
graphics. An unsupported OS version returns false. The legacy
`backend.WindowColorMode` cache is updated only after a successful request.

## Border and title colors

`Windows.setWindowBorderColor([r, g, b], setHeader, setBorder)` uses DWM
attributes 35 (caption) and 34 (border).
`Windows.setWindowTitleColor([r, g, b])` uses attribute 36 (title text).
Channels must be integers from 0 to 255; invalid input returns false before
touching the window. These attributes require Windows 11; older versions return
false. `resetWindowFrameColors()` restores all three system defaults. The legacy
`WindowBackend` and `WindowColorMode` APIs delegate to the same implementation.

## Native Close command

`Windows.setCloseButtonEnabled(false)` grays out the system-menu Close command
and normally disables Alt+F4 as well; `true` restores it. This is a temporary UI
effect, not a security boundary (the OS or a task manager can still end the
process). Callers should restore Close in cleanup/finally paths. The operation
uses `GetSystemMenu` and `EnableMenuItem(SC_CLOSE)` on the validated game HWND.

## Legacy DWM blur

`Windows.setWindowBlur(enabled)` (compatibility alias `Windows.test(enabled)`)
calls `DwmEnableBlurBehindWindow` with `DWM_BB_ENABLE`. This is the legacy Aero
blur API: Windows 10/11 may return success without producing a visible effect.
It is not a substitute for a Flixel shader or Windows 11 Mica/Acrylic. Disable
it explicitly when the effect is no longer needed.

## Windows 11 corners

Build with `-DNO_W11_CORNERS` to request square corners during `Main.setupGame()`.
Without the flag the OS default is preserved. `Windows.setSquareCorners(true)`
and `setSquareCorners(false)` can also change the preference at runtime. This
uses DWM attribute 33 (`DWMWA_WINDOW_CORNER_PREFERENCE`), so older Windows
versions reject it harmlessly. Fullscreen/borderless windows have no visible
frame corners to round.

## Lime frame refresh

`system.Window.darkMode(enabled)` applies the DWM mode and then refreshes the
frame through Lime. `system.Window.redrawFrame()` temporarily flips
`window.borderless` and restores the original value, including on exceptions.
It skips fullscreen windows and never changes the user's fullscreen or border
preference permanently. `WindowColorMode.redrawWindowHeader()` delegates here.
Windows 11 usually does not need this workaround; Windows 10 may need it to
repaint the caption after a mode change.

## Native dialogs

- `Windows.alert(message, title)` shows an owned Unicode information box.
- `Dialog.showYesNoWindows(message, title)` returns true only for `IDYES`; No,
  dismissal, failure, and unsupported targets return false.
- `CoolUtil.sendMsgBox(message, title)` uses the Windows backend on Windows and
  the existing Lime popup elsewhere (returning false because Lime has no result).
- `PlatformUtil.sendFakeMsgBox` retains its crash-reporting role but now uses
  the same UTF-8-to-UTF-16 conversion and owned error dialog on Windows.

Dialogs are modal and block the game thread until dismissed. Do not call them
from per-frame callbacks. Text is data, never shell syntax; no PowerShell or
`cmd.exe` is launched. Linux/macOS crash-dialog fallback is unchanged.

## Notification-area messages

`Windows.sendWindowsNotification(title, message)` and
`PlatformUtil.sendNotification(title, message)` use a Unicode
`NOTIFYICONDATAW` and `Shell_NotifyIconW`. The first accepted request adds one
icon; later requests modify it. Empty text is rejected. Fixed shell buffers are
bounded without splitting surrogate pairs. `Main.onExit` removes the icon;
`Windows.removeWindowsNotification()` is also available for explicit cleanup.

The chart event `Send Windows Notification` uses this native path instead of
constructing a PowerShell command. Chart text cannot become shell syntax.
Windows may present the balloon as a toast, suppress it under Focus Assist, or
reject it when no shell is available. A true result means the shell accepted
the request, not that the player necessarily saw it. Wine is not special-cased;
the shell API's actual result is respected.
