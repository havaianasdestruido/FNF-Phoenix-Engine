import backend.ClientPrefs;
import backend.WindowMode;
import flixel.FlxG;
import lime.app.Application;
import lime.app.Window;

/**
 * Contract tests for `backend.WindowMode`: the three-way window display mode
 * (Windowed / Borderless / Fullscreen), its normalization, persistence and the
 * F11 / transparency interactions.
 *
 * `WindowMode` is deliberately Flixel/Lime-light, so this spec runs in the Haxe
 * interpreter against the stubs in `tests/haxe/stubs/window-mode`. The runner
 * executes it twice: once with no target define (the non-desktop no-op path)
 * and once with `-D desktop` (the native window behaviour).
 *
 *     bash tests/haxe/run-window-mode.sh
 */
class WindowModeSpec
{
  static function check(ok:Bool, label:String):Void
  {
    if (!ok) throw label;
  }

  static function equal<T>(actual:T, expected:T, label:String):Void
  {
    if (actual != expected) throw '$label: expected $expected, got $actual';
  }

  static function main():Void
  {
    constantsAndModes();
    normalize();
    currentAndFlags();
    resizeAndSize();

    #if desktop
    applyMode();
    setPersists();
    toggleRoundTrip();
    togglePreservesBorderless();
    leaveFullscreen();
    #end

    Sys.println('WindowMode spec passed (' + modeLabel() + ')');
  }

  static function modeLabel():String
  {
    #if desktop
    return 'desktop';
    #else
    return 'non-desktop';
    #end
  }

  /** Fresh Lime window for the tests that touch the native window. */
  static function setupWindow():Application
  {
    final app = new Application();
    app.window = new Window();
    Application.current = app;
    FlxG.stage = { window: app.window };
    FlxG.fullscreen = false;
    app.window.borderless = false;
    app.window.fullscreen = false;
    return app;
  }

  /** The mode list is the option row's value list, in display order. */
  static function constantsAndModes():Void
  {
    equal(WindowMode.MODES.length, 3, 'three modes');
    equal(WindowMode.MODES[0], WindowMode.WINDOWED, 'first mode is windowed');
    equal(WindowMode.MODES[1], WindowMode.BORDERLESS, 'second mode is borderless');
    equal(WindowMode.MODES[2], WindowMode.FULLSCREEN, 'third mode is fullscreen');
  }

  /** Accepted spellings normalize; anything unknown falls back to windowed. */
  static function normalize():Void
  {
    equal(WindowMode.normalize('Windowed'), WindowMode.WINDOWED, 'display name windowed');
    equal(WindowMode.normalize('borderless'), WindowMode.BORDERLESS, 'lowercase borderless');
    equal(WindowMode.normalize('  Fullscreen '), WindowMode.FULLSCREEN, 'trimmed fullscreen');
    equal(WindowMode.normalize('Full'), WindowMode.FULLSCREEN, 'short fullscreen alias');
    equal(WindowMode.normalize('exclusive'), WindowMode.FULLSCREEN, 'exclusive alias');
    equal(WindowMode.normalize('window'), WindowMode.WINDOWED, 'window alias');
    equal(WindowMode.normalize(null), WindowMode.WINDOWED, 'null falls back');
    equal(WindowMode.normalize(''), WindowMode.WINDOWED, 'empty falls back');
    equal(WindowMode.normalize('television'), WindowMode.WINDOWED, 'unknown falls back');
  }

  /** `current()` mirrors the preference; the flags derive from it. */
  static function currentAndFlags():Void
  {
    ClientPrefs.windowMode = WindowMode.BORDERLESS;
    equal(WindowMode.current(), WindowMode.BORDERLESS, 'current reads the pref');
    check(!WindowMode.isFullscreen(), 'borderless is not fullscreen');
    check(WindowMode.isBorderless(), 'borderless flag');

    ClientPrefs.windowMode = WindowMode.FULLSCREEN;
    check(WindowMode.isFullscreen(), 'fullscreen flag');
    check(!WindowMode.isBorderless(), 'fullscreen is not borderless');

    ClientPrefs.windowMode = 'nonsense';
    equal(WindowMode.current(), WindowMode.WINDOWED, 'invalid pref normalizes');
  }

#if desktop
  /** Applying a mode drives FlxG.fullscreen and the Lime borderless flag. */
  static function applyMode():Void
  {
    final app = setupWindow();

    WindowMode.apply(WindowMode.WINDOWED);
    equal(FlxG.fullscreen, false, 'windowed leaves fullscreen');
    equal(app.window.borderless, false, 'windowed has a frame');

    WindowMode.apply(WindowMode.BORDERLESS);
    equal(FlxG.fullscreen, false, 'borderless is not exclusive fullscreen');
    equal(app.window.borderless, true, 'borderless drops the frame');

    WindowMode.apply(WindowMode.FULLSCREEN);
    equal(FlxG.fullscreen, true, 'fullscreen sets FlxG.fullscreen');
    equal(app.window.fullscreen, true, 'fullscreen reaches the Lime window');
  }

  /** `set()` updates the preference, applies it and (by default) persists. */
  static function setPersists():Void
  {
    setupWindow();
    ClientPrefs.windowMode = WindowMode.WINDOWED;
    ClientPrefs.saveRequested = false;

    check(WindowMode.set(WindowMode.BORDERLESS), 'set applies');
    equal(ClientPrefs.windowMode, WindowMode.BORDERLESS, 'set writes the pref');
    check(ClientPrefs.saveRequested, 'set persists by default');

    ClientPrefs.saveRequested = false;
    check(WindowMode.set('Fullscreen', false), 'set without save applies');
    equal(ClientPrefs.windowMode, WindowMode.FULLSCREEN, 'set normalizes and writes');
    check(!ClientPrefs.saveRequested, 'set(save=false) does not persist');
  }

  /** F11 toggling from windowed round-trips and persists. */
  static function toggleRoundTrip():Void
  {
    setupWindow();
    ClientPrefs.windowMode = WindowMode.WINDOWED;
    ClientPrefs.saveRequested = false;

    check(WindowMode.toggleFullscreen(), 'toggle enters fullscreen');
    equal(ClientPrefs.windowMode, WindowMode.FULLSCREEN, 'toggle persists fullscreen');
    check(FlxG.fullscreen, 'toggle applied fullscreen');

    check(!WindowMode.toggleFullscreen(), 'toggle leaves fullscreen');
    equal(ClientPrefs.windowMode, WindowMode.WINDOWED, 'toggle restores windowed');
    check(!FlxG.fullscreen, 'toggle applied windowed');
  }

  /** F11 returns a borderless player to borderless, not to windowed. */
  static function togglePreservesBorderless():Void
  {
    setupWindow();
    ClientPrefs.windowMode = WindowMode.BORDERLESS;

    check(WindowMode.toggleFullscreen(), 'borderless toggle enters fullscreen');
    equal(ClientPrefs.windowMode, WindowMode.FULLSCREEN, 'borderless toggle persists fullscreen');

    check(!WindowMode.toggleFullscreen(), 'borderless toggle leaves fullscreen');
    equal(ClientPrefs.windowMode, WindowMode.BORDERLESS, 'borderless toggle restores borderless');
  }

  /** Leaving fullscreen through a windowed-only feature restores the mode. */
  static function leaveFullscreen():Void
  {
    setupWindow();
    ClientPrefs.windowMode = WindowMode.FULLSCREEN;
    FlxG.fullscreen = true;

    check(WindowMode.leaveFullscreen(), 'leaveFullscreen leaves fullscreen');
    check(!FlxG.fullscreen, 'leaveFullscreen applied windowed');
    equal(ClientPrefs.windowMode, WindowMode.WINDOWED, 'leaveFullscreen persists the restore');

    // Not fullscreen: a no-op that changes nothing.
    ClientPrefs.windowMode = WindowMode.WINDOWED;
    FlxG.fullscreen = false;
    check(!WindowMode.leaveFullscreen(), 'leaveFullscreen is a no-op when not fullscreen');
  }
#end

  /** Window size helpers; the resize path is desktop-only. */
  static function resizeAndSize():Void
  {
    FlxG.width = 1280;
    FlxG.height = 720;
    final size:Array<Int> = WindowMode.getWindowSize();
    equal(size[0], 1280, 'window size width');
    equal(size[1], 720, 'window size height');

    #if desktop
    // Desktop native targets actually resize the window and viewport.
    check(WindowMode.resize(1920, 1080), 'resize applies on desktop');
    equal(FlxG.width, 1920, 'resize updates width');
    equal(FlxG.height, 1080, 'resize updates height');
    check(!WindowMode.resize(0, 720), 'resize rejects non-positive width');
    check(!WindowMode.resize(1280, -1), 'resize rejects non-positive height');
    #else
    // No native window on this target: resize is a safe no-op.
    check(!WindowMode.resize(1920, 1080), 'resize is a no-op without a desktop window');
    #end
  }
}
