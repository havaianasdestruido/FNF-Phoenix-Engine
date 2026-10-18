package backend;

/**
 * Native transparent-window glue. **Windows (C++/hxcpp) only** — every function
 * here is compiled to an empty stub anywhere else, so they are always safe to
 * call but simply do nothing off Windows.
 *
 * Ported from `FlxTransWindow.hx` of **psych-engine-modified-build** by
 * *notmagniill* (https://github.com/notmagniill/psych-engine-modified-build/blob/stable/source/backend/FlxTransWindow.hx),
 * then extended for Phoenix Engine with:
 *
 *  - an `HWND` lookup that cannot hit another process' window (the port called
 *    `GetActiveWindow()` blindly, see TODO.md §"WINDOWS / LOW-LEVEL WINDOW
 *    MANAGEMENT" #7);
 *  - whole-window alpha on top of the color key;
 *  - click-through (`WS_EX_TRANSPARENT`);
 *  - a way to undo all of it (`clearTransparentWindow`).
 *
 * Do **not** call this class directly: use `backend.TransparentWindow`, which
 * owns the platform guard, the state, the fullscreen handling and the
 * "not supported on this platform" messages.
 */
#if (cpp && windows)
@:cppFileCode('
#include <windows.h>
#include <winuser.h>

/**
 * Locates the window that actually belongs to this game.
 *
 * The port used GetActiveWindow() on its own, which returns the HWND of
 * whatever window has the focus — including a window owned by another process
 * when the game is unfocused. Prefer the active window, then the foreground
 * window, then the Lime/SDL window class ("SDL_app"), and refuse anything that
 * is not ours.
 */
static HWND phoenixFindGameWindow()
{
  HWND hWnd = GetActiveWindow();
  DWORD pid = 0;

  if (hWnd != NULL) GetWindowThreadProcessId(hWnd, &pid);

  if (hWnd == NULL || pid != GetCurrentProcessId())
  {
    hWnd = GetForegroundWindow();
    pid = 0;
    if (hWnd != NULL) GetWindowThreadProcessId(hWnd, &pid);
  }

  if (hWnd == NULL || pid != GetCurrentProcessId()) hWnd = FindWindowA("SDL_app", NULL);

  return hWnd;
}
')
#end
class FlxTransWindow
{
  /**
   * The port, kept as-is: turns the game window into a layered one and makes
   * every `RGB(1, 1, 1)` pixel see-through. Windows only.
   *
   * @param   res   Unused; kept so the signature matches the port.
   * @return  Non-zero when the window style was changed.
   */
  #if (cpp && windows)
  @:functionCode('
        HWND hWnd = phoenixFindGameWindow();
        if (hWnd == NULL) return 0;

        res = SetWindowLong(hWnd, GWL_EXSTYLE, GetWindowLong(hWnd, GWL_EXSTYLE) | WS_EX_LAYERED);
        if (res) SetLayeredWindowAttributes(hWnd, RGB(1, 1, 1), 0, LWA_COLORKEY);
        return res;
    ')
  #end
  static public function getWindowsTransparent(res:Int = 0):Int
  {
    return res;
  }

  /**
   * Undoes `getWindowsTransparent()`: removes `WS_EX_LAYERED` (and the
   * click-through style) so the window is drawn normally again. Windows only.
   *
   * @param   res   Unused; kept so the signature matches the port.
   * @return  Non-zero when the window style was changed.
   */
  #if (cpp && windows)
  @:functionCode('
        HWND hWnd = phoenixFindGameWindow();
        if (hWnd == NULL) return 0;

        LONG style = GetWindowLong(hWnd, GWL_EXSTYLE);
        LONG plain = style & ~WS_EX_LAYERED & ~WS_EX_TRANSPARENT;

        if (plain != style)
        {
          SetLastError(0);
          if (SetWindowLong(hWnd, GWL_EXSTYLE, plain) == 0 && GetLastError() != 0) return 0;
          RedrawWindow(hWnd, NULL, NULL, RDW_ERASE | RDW_INVALIDATE | RDW_FRAME | RDW_ALLCHILDREN);
        }
        res = 1;
        return res;
    ')
  #end
  static public function getWindowsbackward(res:Int = 0):Int
  {
    return res;
  }

  /**
   * Makes the window layered and applies the color key **and** the
   * whole-window alpha in one call. Windows only.
   *
   * Both attributes have to be set together: `SetLayeredWindowAttributes()`
   * replaces the previous attribute, so asking for `LWA_COLORKEY` alone would
   * silently drop the alpha (and the other way round).
   *
   * @param   keyR   Red channel of the color that renders see-through (0-255).
   * @param   keyG   Green channel of the color that renders see-through (0-255).
   * @param   keyB   Blue channel of the color that renders see-through (0-255).
   * @param   alpha  Whole-window opacity, `0.0` (invisible) to `1.0` (opaque).
   * @param   res    Unused; kept for parity with the ported functions.
   * @return  Non-zero on success.
   */
  #if (cpp && windows)
  @:functionCode('
        HWND hWnd = phoenixFindGameWindow();
        if (hWnd == NULL) return 0;

        int opacity = (int)(alpha * 255.0f);
        if (opacity < 0) opacity = 0;
        if (opacity > 255) opacity = 255;

        LONG style = GetWindowLong(hWnd, GWL_EXSTYLE);
        LONG layered = style | WS_EX_LAYERED;

        if (layered != style)
        {
          SetLastError(0);
          if (SetWindowLong(hWnd, GWL_EXSTYLE, layered) == 0 && GetLastError() != 0) return 0;
        }

        res = SetLayeredWindowAttributes(hWnd, RGB(keyR, keyG, keyB), (BYTE)opacity, LWA_COLORKEY | LWA_ALPHA) ? 1 : 0;
        InvalidateRect(hWnd, NULL, TRUE);
        UpdateWindow(hWnd);
        return res;
    ')
  #end
  static public function setTransparentWindow(keyR:Int, keyG:Int, keyB:Int, alpha:Float, res:Int = 0):Int
  {
    return res;
  }

  /**
   * Applies a whole-window alpha without any color key (layered window,
   * `LWA_ALPHA` only). Windows only.
   *
   * @param   alpha  Whole-window opacity, `0.0` (invisible) to `1.0` (opaque).
   * @param   res    Unused; kept for parity with the ported functions.
   * @return  Non-zero on success.
   */
  #if (cpp && windows)
  @:functionCode('
        HWND hWnd = phoenixFindGameWindow();
        if (hWnd == NULL) return 0;

        int opacity = (int)(alpha * 255.0f);
        if (opacity < 0) opacity = 0;
        if (opacity > 255) opacity = 255;

        LONG style = GetWindowLong(hWnd, GWL_EXSTYLE);
        LONG layered = style | WS_EX_LAYERED;

        if (layered != style)
        {
          SetLastError(0);
          if (SetWindowLong(hWnd, GWL_EXSTYLE, layered) == 0 && GetLastError() != 0) return 0;
        }

        res = SetLayeredWindowAttributes(hWnd, 0, (BYTE)opacity, LWA_ALPHA) ? 1 : 0;
        InvalidateRect(hWnd, NULL, TRUE);
        UpdateWindow(hWnd);
        return res;
    ')
  #end
  static public function setAlphaWindow(alpha:Float, res:Int = 0):Int
  {
    return res;
  }

  /**
   * Removes the layered/click-through styles, restoring a normal opaque window.
   * Windows only.
   *
   * @return  Non-zero on success.
   */
  #if (cpp && windows)
  @:functionCode('
        HWND hWnd = phoenixFindGameWindow();
        if (hWnd == NULL) return 0;

        LONG style = GetWindowLong(hWnd, GWL_EXSTYLE);
        LONG plain = style & ~WS_EX_LAYERED & ~WS_EX_TRANSPARENT;

        if (plain != style)
        {
          SetLastError(0);
          if (SetWindowLong(hWnd, GWL_EXSTYLE, plain) == 0 && GetLastError() != 0) return 0;
        }

        RedrawWindow(hWnd, NULL, NULL, RDW_ERASE | RDW_INVALIDATE | RDW_FRAME | RDW_ALLCHILDREN);
        res = 1;
        return res;
    ')
  #end
  static public function clearTransparentWindow(res:Int = 0):Int
  {
    return res;
  }

  /**
   * Lets the mouse pass through the window (desktop-pet style overlays).
   * Windows only.
   *
   * @param   enabled   `true` to ignore mouse input, `false` to receive it.
   * @return  Non-zero on success.
   */
  #if (cpp && windows)
  @:functionCode('
        HWND hWnd = phoenixFindGameWindow();
        if (hWnd == NULL) return 0;

        LONG style = GetWindowLong(hWnd, GWL_EXSTYLE);
        LONG next = enabled ? (style | WS_EX_TRANSPARENT) : (style & ~WS_EX_TRANSPARENT);

        if (next == style) return 1;

        SetLastError(0);
        if (SetWindowLong(hWnd, GWL_EXSTYLE, next) == 0 && GetLastError() != 0) return 0;

        RedrawWindow(hWnd, NULL, NULL, RDW_ERASE | RDW_INVALIDATE | RDW_FRAME | RDW_ALLCHILDREN);
        res = 1;
        return res;
    ')
  #end
  static public function setClickThrough(enabled:Bool, res:Int = 0):Int
  {
    return res;
  }
}
