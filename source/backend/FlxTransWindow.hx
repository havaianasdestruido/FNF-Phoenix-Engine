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
 *  - the shared, process-checked HWND lookup and layered state in `Windows`;
 *  - whole-window alpha on top of the color key;
 *  - click-through (`WS_EX_TRANSPARENT`);
 *  - a way to undo all of it (`clearTransparentWindow`).
 *
 * Do **not** call this class directly: use `backend.TransparentWindow`, which
 * owns the platform guard, the state, the fullscreen handling and the
 * "not supported on this platform" messages.
 */
class FlxTransWindow
{
  /**
   * The port, kept as-is: turns the game window into a layered one and makes
   * every `RGB(1, 1, 1)` pixel see-through. Windows only.
   *
   * @param   res   Unused; kept so the signature matches the port.
   * @return  Non-zero when the window style was changed.
   */
  static public function getWindowsTransparent(res:Int = 0):Int
  {
    return Windows.__setWindowTransparencyColor(0x010101) ? 1 : 0;
  }

  /**
   * Undoes `getWindowsTransparent()`: removes `WS_EX_LAYERED` (and the
   * click-through style) so the window is drawn normally again. Windows only.
   *
   * @param   res   Unused; kept so the signature matches the port.
   * @return  Non-zero when the window style was changed.
   */
  static public function getWindowsbackward(res:Int = 0):Int
  {
    return Windows.__setWindowTransparencyColor(0, false) ? 1 : 0;
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
  static public function setTransparentWindow(keyR:Int, keyG:Int, keyB:Int, alpha:Float, res:Int = 0):Int
  {
    return (Windows.__setWindowTransparencyAlpha(alpha)
      && Windows.__setWindowTransparencyColor((keyR << 16) | (keyG << 8) | keyB)) ? 1 : 0;
  }

  /**
   * Applies a whole-window alpha without any color key (layered window,
   * `LWA_ALPHA` only). Windows only.
   *
   * @param   alpha  Whole-window opacity, `0.0` (invisible) to `1.0` (opaque).
   * @param   res    Unused; kept for parity with the ported functions.
   * @return  Non-zero on success.
   */
  static public function setAlphaWindow(alpha:Float, res:Int = 0):Int
  {
    return Windows.__setWindowTransparencyAlpha(alpha) ? 1 : 0;
  }

  /**
   * Removes the layered/click-through styles, restoring a normal opaque window.
   * Windows only.
   *
   * @return  Non-zero on success.
   */
  static public function clearTransparentWindow(res:Int = 0):Int
  {
    return Windows.resetWindowTransparency() ? 1 : 0;
  }

  /**
   * Lets the mouse pass through the window (desktop-pet style overlays).
   * Windows only.
   *
   * @param   enabled   `true` to ignore mouse input, `false` to receive it.
   * @return  Non-zero on success.
   */
  static public function setClickThrough(enabled:Bool, res:Int = 0):Int
  {
    return Windows.setWindowClickThrough(enabled) ? 1 : 0;
  }
}
