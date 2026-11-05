package psychlua.pystdlib;

import backend.MetaHorror;
import psychlua.PythonScript;

/**
 * 4th-wall-breaking ("META_HORROR") system effects for Python (Hython) mods.
 *
 * Mirror of `psychlua.callbacks.MetaHorrorCallbacks` — keep the function names
 * and the argument order in sync (#87). Everything compiles on every target:
 * on builds without `-DMETA_HORROR`, or on platforms where an effect does not
 * exist, each function returns its failure value and prints the reason to the
 * debug text instead of doing nothing silently.
 *
 * These effects are deliberately intrusive. A mod that uses them must warn the
 * player up front; see docs/META_HORROR.md.
 */
class PyMetaHorrorLib
{
  public static function register(py:PythonScript):Void
  {
    @:privateAccess {

    // ------------------------------------------------------------------
    // Detecting streamers
    // ------------------------------------------------------------------

    // Fails open (true) when the process list cannot be read.
    PythonScript.registerFunction("isRecording", function():Bool {
      #if META_HORROR
      return MetaHorror.isRecording();
      #else
      pyMetaHorrorWarning(py, 'isRecording');
      return false;
      #end
    });

    // ------------------------------------------------------------------
    // Wallpaper
    // ------------------------------------------------------------------

    PythonScript.registerFunction("killWallpaperApps", function() {
      #if META_HORROR
      MetaHorror.killWallpaperApps();
      #else
      pyMetaHorrorWarning(py, 'killWallpaperApps');
      #end
    });

    PythonScript.registerFunction("setWallpaper", function(path:String, ?absolute:Bool = false):Bool {
      #if META_HORROR
      return MetaHorror.setWallpaper(path, absolute);
      #else
      pyMetaHorrorWarning(py, 'setWallpaper');
      return false;
      #end
    });

    PythonScript.registerFunction("restoreWallpaper", function():Bool {
      #if META_HORROR
      return MetaHorror.restoreWallpaper();
      #else
      pyMetaHorrorWarning(py, 'restoreWallpaper');
      return false;
      #end
    });

    // ------------------------------------------------------------------
    // Taskbar & other windows
    // ------------------------------------------------------------------

    PythonScript.registerFunction("hideTaskbar", function():Bool {
      #if META_HORROR
      return MetaHorror.hideTaskbar();
      #else
      pyMetaHorrorWarning(py, 'hideTaskbar');
      return false;
      #end
    });

    PythonScript.registerFunction("restoreTaskbar", function() {
      #if META_HORROR
      MetaHorror.restoreTaskbar();
      #else
      pyMetaHorrorWarning(py, 'restoreTaskbar');
      #end
    });

    PythonScript.registerFunction("hideAllWindows", function():Int {
      #if META_HORROR
      return MetaHorror.hideAllWindows();
      #else
      pyMetaHorrorWarning(py, 'hideAllWindows');
      return 0;
      #end
    });

    PythonScript.registerFunction("restoreAllWindows", function():Int {
      #if META_HORROR
      return MetaHorror.restoreAllWindows();
      #else
      pyMetaHorrorWarning(py, 'restoreAllWindows');
      return 0;
      #end
    });

    // ------------------------------------------------------------------
    // The game window
    // ------------------------------------------------------------------

    PythonScript.registerFunction("removeWindowIcon", function():Bool {
      #if META_HORROR
      return MetaHorror.removeWindowIcon();
      #else
      pyMetaHorrorWarning(py, 'removeWindowIcon');
      return false;
      #end
    });

    // Namespaced like the Lua bridge: `PyWindowLib` owns the script-side
    // `setWindowAlpha`/`setWindowTransparencyColor` pair.
    PythonScript.registerFunction("setMetaWindowAlpha", function(alpha:Float):Bool {
      #if META_HORROR
      return MetaHorror.setWindowAlpha(alpha);
      #else
      pyMetaHorrorWarning(py, 'setMetaWindowAlpha');
      return false;
      #end
    });

    PythonScript.registerFunction("setMetaWindowColorKey", function(color:Int):Bool {
      #if META_HORROR
      return MetaHorror.setWindowColorKey(color);
      #else
      pyMetaHorrorWarning(py, 'setMetaWindowColorKey');
      return false;
      #end
    });

    PythonScript.registerFunction("resetMetaWindowEffects", function():Bool {
      #if META_HORROR
      return MetaHorror.resetWindowEffects();
      #else
      pyMetaHorrorWarning(py, 'resetMetaWindowEffects');
      return false;
      #end
    });

    // ------------------------------------------------------------------
    // System volume, mouse & keyboard
    // ------------------------------------------------------------------

    PythonScript.registerFunction("setSysVolume", function(percentage:Int):Bool {
      #if META_HORROR
      return MetaHorror.setSysAudioVolume(percentage);
      #else
      pyMetaHorrorWarning(py, 'setSysVolume');
      return false;
      #end
    });

    PythonScript.registerFunction("getSysVolume", function():Int {
      #if META_HORROR
      return MetaHorror.getSysAudioVolume();
      #else
      pyMetaHorrorWarning(py, 'getSysVolume');
      return -1;
      #end
    });

    PythonScript.registerFunction("setSysMute", function(mute:Bool):Bool {
      #if META_HORROR
      return MetaHorror.setSysAudioMute(mute);
      #else
      pyMetaHorrorWarning(py, 'setSysMute');
      return false;
      #end
    });

    PythonScript.registerFunction("getSysMute", function():Bool {
      #if META_HORROR
      return MetaHorror.getSysAudioMute();
      #else
      pyMetaHorrorWarning(py, 'getSysMute');
      return false;
      #end
    });

    PythonScript.registerFunction("moveMousePos", function(x:Float, y:Float):Bool {
      #if META_HORROR
      return MetaHorror.moveMousePos(x, y);
      #else
      pyMetaHorrorWarning(py, 'moveMousePos');
      return false;
      #end
    });

    PythonScript.registerFunction("typeText", function(text:String, ?delay:Float = 0.05) {
      #if META_HORROR
      MetaHorror.typeText(text, delay);
      #else
      pyMetaHorrorWarning(py, 'typeText');
      #end
    });

    // ------------------------------------------------------------------
    // Files & info
    // ------------------------------------------------------------------

    PythonScript.registerFunction("openFile", function(path:String):Bool {
      #if META_HORROR
      return MetaHorror.openFile(path);
      #else
      pyMetaHorrorWarning(py, 'openFile');
      return false;
      #end
    });

    PythonScript.registerFunction("duplicateImage", function(imageFile:String, finalFileName:String, ?fileType:String = 'png', ?location:String):String {
      #if META_HORROR
      return MetaHorror.duplicateImage(imageFile, finalFileName, fileType, location);
      #else
      pyMetaHorrorWarning(py, 'duplicateImage');
      return null;
      #end
    });

    PythonScript.registerFunction("getSystemRAM", function():Int {
      #if META_HORROR
      return MetaHorror.getSystemRAM();
      #else
      pyMetaHorrorWarning(py, 'getSystemRAM');
      return 0;
      #end
    });

    // ------------------------------------------------------------------
    // The player: "the character says your name"
    // ------------------------------------------------------------------

    PythonScript.registerFunction("getDesktopUsername", function():String {
      #if META_HORROR
      return MetaHorror.getDesktopUsername();
      #else
      pyMetaHorrorWarning(py, 'getDesktopUsername');
      return 'player';
      #end
    });

    PythonScript.registerFunction("getSystemUptime", function():Int {
      #if META_HORROR
      return MetaHorror.getSystemUptime();
      #else
      pyMetaHorrorWarning(py, 'getSystemUptime');
      return 0;
      #end
    });

    PythonScript.registerFunction("getLocalHour", function():Int {
      #if META_HORROR
      return MetaHorror.getLocalHour();
      #else
      pyMetaHorrorWarning(py, 'getLocalHour');
      return 0;
      #end
    });

    PythonScript.registerFunction("getLocalTimeString", function():String {
      #if META_HORROR
      return MetaHorror.getLocalTimeString();
      #else
      pyMetaHorrorWarning(py, 'getLocalTimeString');
      return '00:00';
      #end
    });

    PythonScript.registerFunction("isLateNight", function(?fromHour:Int = 0, ?toHour:Int = 5):Bool {
      #if META_HORROR
      return MetaHorror.isLateNight(fromHour, toHour);
      #else
      pyMetaHorrorWarning(py, 'isLateNight');
      return false;
      #end
    });

    PythonScript.registerFunction("getLaunchCount", function():Int {
      #if META_HORROR
      return MetaHorror.getLaunchCount();
      #else
      pyMetaHorrorWarning(py, 'getLaunchCount');
      return 0;
      #end
    });

    // ------------------------------------------------------------------
    // Persistent values ("the game remembers you")
    // ------------------------------------------------------------------

    PythonScript.registerFunction("getPersistentValue", function(key:String, ?defaultValue:Float = 0):Float {
      #if META_HORROR
      return MetaHorror.getPersistentValue(key, defaultValue);
      #else
      pyMetaHorrorWarning(py, 'getPersistentValue');
      return defaultValue;
      #end
    });

    PythonScript.registerFunction("setPersistentValue", function(key:String, value:Float):Bool {
      #if META_HORROR
      return MetaHorror.setPersistentValue(key, value);
      #else
      pyMetaHorrorWarning(py, 'setPersistentValue');
      return false;
      #end
    });

    PythonScript.registerFunction("hasPersistentValue", function(key:String):Bool {
      #if META_HORROR
      return MetaHorror.hasPersistentValue(key);
      #else
      pyMetaHorrorWarning(py, 'hasPersistentValue');
      return false;
      #end
    });

    PythonScript.registerFunction("addPersistentValue", function(key:String, ?amount:Float = 1):Float {
      #if META_HORROR
      return MetaHorror.addPersistentValue(key, amount);
      #else
      pyMetaHorrorWarning(py, 'addPersistentValue');
      return 0;
      #end
    });

    PythonScript.registerFunction("clearPersistentValues", function():Bool {
      #if META_HORROR
      return MetaHorror.clearPersistentValues();
      #else
      pyMetaHorrorWarning(py, 'clearPersistentValues');
      return false;
      #end
    });

    // ------------------------------------------------------------------
    // Clipboard
    // ------------------------------------------------------------------

    PythonScript.registerFunction("getClipboardText", function():String {
      #if META_HORROR
      return MetaHorror.getClipboardText();
      #else
      pyMetaHorrorWarning(py, 'getClipboardText');
      return '';
      #end
    });

    PythonScript.registerFunction("setClipboardText", function(text:String):Bool {
      #if META_HORROR
      return MetaHorror.setClipboardText(text);
      #else
      pyMetaHorrorWarning(py, 'setClipboardText');
      return false;
      #end
    });

    // ------------------------------------------------------------------
    // Window title & focus games
    // ------------------------------------------------------------------

    PythonScript.registerFunction("setWindowTitle", function(title:String):Bool {
      #if META_HORROR
      return MetaHorror.setWindowTitle(title);
      #else
      pyMetaHorrorWarning(py, 'setWindowTitle');
      return false;
      #end
    });

    PythonScript.registerFunction("restoreWindowTitle", function():Bool {
      #if META_HORROR
      return MetaHorror.restoreWindowTitle();
      #else
      pyMetaHorrorWarning(py, 'restoreWindowTitle');
      return false;
      #end
    });

    PythonScript.registerFunction("setAlwaysOnTop", function(enable:Bool = true):Bool {
      #if META_HORROR
      return MetaHorror.setAlwaysOnTop(enable);
      #else
      pyMetaHorrorWarning(py, 'setAlwaysOnTop');
      return false;
      #end
    });

    PythonScript.registerFunction("isAlwaysOnTop", function():Bool {
      #if META_HORROR
      return MetaHorror.isAlwaysOnTop();
      #else
      pyMetaHorrorWarning(py, 'isAlwaysOnTop');
      return false;
      #end
    });

    PythonScript.registerFunction("flashTaskbar", function(?times:Int = 3):Bool {
      #if META_HORROR
      return MetaHorror.flashTaskbar(times);
      #else
      pyMetaHorrorWarning(py, 'flashTaskbar');
      return false;
      #end
    });

    PythonScript.registerFunction("stopTaskbarFlash", function() {
      #if META_HORROR
      MetaHorror.stopTaskbarFlash();
      #else
      pyMetaHorrorWarning(py, 'stopTaskbarFlash');
      #end
    });

    // ------------------------------------------------------------------
    // Looking at the desktop
    // ------------------------------------------------------------------

    PythonScript.registerFunction("getOpenWindowTitles", function():Array<String> {
      #if META_HORROR
      return MetaHorror.getOpenWindowTitles();
      #else
      pyMetaHorrorWarning(py, 'getOpenWindowTitles');
      return [];
      #end
    });

    PythonScript.registerFunction("captureDesktop", function(?fileName:String = 'desktop', ?location:String):String {
      #if META_HORROR
      return MetaHorror.captureDesktop(fileName, location);
      #else
      pyMetaHorrorWarning(py, 'captureDesktop');
      return null;
      #end
    });

    // ------------------------------------------------------------------
    // Cleanup
    // ------------------------------------------------------------------

    PythonScript.registerFunction("restoreAllMetaEffects", function() {
      #if META_HORROR
      MetaHorror.restoreAll();
      #else
      pyMetaHorrorWarning(py, 'restoreAllMetaEffects');
      #end
    });

    }
  }

  /**
   * Tells the script author why the call did nothing, so a mod is never
   * silently broken on a standard build.
   */
  static function pyMetaHorrorWarning(py:PythonScript, fn:String):Void {
    #if !META_HORROR
    py.pyTrace('$fn: 4th-wall-breaking effects require a -DMETA_HORROR build of Phoenix Engine.', true, false, FlxColor.ORANGE);
    #end
  }
}
