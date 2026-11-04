package psychlua.callbacks;

import backend.MetaHorror;
import psychlua.FunkinLua;
import psychlua.LuaUtils;

// 4th-wall-breaking ("META_HORROR") system effects, exposed to Lua/Python/HScript.
// Part of the issue #94 port; behavior and platform support are documented in
// docs/META_HORROR.md. Every function compiles on all targets but only takes
// effect on `-DMETA_HORROR` builds with platform support, warning otherwise.
class MetaHorrorCallbacks
{
  public static function register(funk:FunkinLua):Void {
    @:privateAccess {

    FunkinLua.registerFunction("isRecording", function():Bool {
      #if META_HORROR
      return MetaHorror.isRecording();
      #else
      metaHorrorWarning(funk, 'isRecording');
      return false;
      #end
    });

    FunkinLua.registerFunction("killWallpaperApps", function() {
      #if META_HORROR
      MetaHorror.killWallpaperApps();
      #else
      metaHorrorWarning(funk, 'killWallpaperApps');
      #end
    });

    FunkinLua.registerFunction("setWallpaper", function(path:String, ?absolute:Bool = false):Bool {
      #if META_HORROR
      return MetaHorror.setWallpaper(path, absolute);
      #else
      metaHorrorWarning(funk, 'setWallpaper');
      return false;
      #end
    });

    FunkinLua.registerFunction("restoreWallpaper", function():Bool {
      #if META_HORROR
      return MetaHorror.restoreWallpaper();
      #else
      metaHorrorWarning(funk, 'restoreWallpaper');
      return false;
      #end
    });

    FunkinLua.registerFunction("hideTaskbar", function():Bool {
      #if META_HORROR
      return MetaHorror.hideTaskbar();
      #else
      metaHorrorWarning(funk, 'hideTaskbar');
      return false;
      #end
    });

    FunkinLua.registerFunction("restoreTaskbar", function() {
      #if META_HORROR
      MetaHorror.restoreTaskbar();
      #else
      metaHorrorWarning(funk, 'restoreTaskbar');
      #end
    });

    FunkinLua.registerFunction("hideAllWindows", function():Int {
      #if META_HORROR
      return MetaHorror.hideAllWindows();
      #else
      metaHorrorWarning(funk, 'hideAllWindows');
      return 0;
      #end
    });

    FunkinLua.registerFunction("restoreAllWindows", function():Int {
      #if META_HORROR
      return MetaHorror.restoreAllWindows();
      #else
      metaHorrorWarning(funk, 'restoreAllWindows');
      return 0;
      #end
    });

    FunkinLua.registerFunction("removeWindowIcon", function():Bool {
      #if META_HORROR
      return MetaHorror.removeWindowIcon();
      #else
      metaHorrorWarning(funk, 'removeWindowIcon');
      return false;
      #end
    });

    // Namespaced: `WindowCallbacks` already owns the script-side
    // `setWindowAlpha` (the transparent-window feature) and this class is
    // registered after it, so registering the same name here would silently
    // replace the working implementation with a no-op on normal builds.
    FunkinLua.registerFunction("setMetaWindowAlpha", function(alpha:Float):Bool {
      #if META_HORROR
      return MetaHorror.setWindowAlpha(alpha);
      #else
      metaHorrorWarning(funk, 'setMetaWindowAlpha');
      return false;
      #end
    });

    FunkinLua.registerFunction("setMetaWindowColorKey", function(color:Int):Bool {
      #if META_HORROR
      return MetaHorror.setWindowColorKey(color);
      #else
      metaHorrorWarning(funk, 'setMetaWindowColorKey');
      return false;
      #end
    });

    // Restores the window style after the two effects above (the
    // transparent-window feature has `applyWindowTransparency` instead).
    FunkinLua.registerFunction("resetMetaWindowEffects", function():Bool {
      #if META_HORROR
      return MetaHorror.resetWindowEffects();
      #else
      metaHorrorWarning(funk, 'resetMetaWindowEffects');
      return false;
      #end
    });

    FunkinLua.registerFunction("setSysVolume", function(percentage:Int):Bool {
      #if META_HORROR
      return MetaHorror.setSysAudioVolume(percentage);
      #else
      metaHorrorWarning(funk, 'setSysVolume');
      return false;
      #end
    });

    FunkinLua.registerFunction("getSysVolume", function():Int {
      #if META_HORROR
      return MetaHorror.getSysAudioVolume();
      #else
      metaHorrorWarning(funk, 'getSysVolume');
      return -1;
      #end
    });

    FunkinLua.registerFunction("setSysMute", function(mute:Bool):Bool {
      #if META_HORROR
      return MetaHorror.setSysAudioMute(mute);
      #else
      metaHorrorWarning(funk, 'setSysMute');
      return false;
      #end
    });

    FunkinLua.registerFunction("getSysMute", function():Bool {
      #if META_HORROR
      return MetaHorror.getSysAudioMute();
      #else
      metaHorrorWarning(funk, 'getSysMute');
      return false;
      #end
    });

    FunkinLua.registerFunction("moveMousePos", function(x:Float, y:Float):Bool {
      #if META_HORROR
      return MetaHorror.moveMousePos(x, y);
      #else
      metaHorrorWarning(funk, 'moveMousePos');
      return false;
      #end
    });

    FunkinLua.registerFunction("typeText", function(text:String, ?delay:Float = 0.05) {
      #if META_HORROR
      MetaHorror.typeText(text, delay);
      #else
      metaHorrorWarning(funk, 'typeText');
      #end
    });

    FunkinLua.registerFunction("openFile", function(path:String):Bool {
      #if META_HORROR
      return MetaHorror.openFile(path);
      #else
      metaHorrorWarning(funk, 'openFile');
      return false;
      #end
    });

    FunkinLua.registerFunction("duplicateImage", function(imageFile:String, finalFileName:String, ?fileType:String = 'png', ?location:String):String {
      #if META_HORROR
      return MetaHorror.duplicateImage(imageFile, finalFileName, fileType, location);
      #else
      metaHorrorWarning(funk, 'duplicateImage');
      return null;
      #end
    });

    FunkinLua.registerFunction("getSystemRAM", function():Int {
      #if META_HORROR
      return MetaHorror.getSystemRAM();
      #else
      metaHorrorWarning(funk, 'getSystemRAM');
      return 0;
      #end
    });

    // ------------------------------------------------------------------
    // The player: "the character says your name"
    // ------------------------------------------------------------------

    // OS account name, or "player" when it cannot be read.
    FunkinLua.registerFunction("getDesktopUsername", function():String {
      #if META_HORROR
      return MetaHorror.getDesktopUsername();
      #else
      metaHorrorWarning(funk, 'getDesktopUsername');
      return 'player';
      #end
    });

    // Seconds since the machine booted (0 when unknown).
    FunkinLua.registerFunction("getSystemUptime", function():Int {
      #if META_HORROR
      return MetaHorror.getSystemUptime();
      #else
      metaHorrorWarning(funk, 'getSystemUptime');
      return 0;
      #end
    });

    // The player's local clock hour, 0-23.
    FunkinLua.registerFunction("getLocalHour", function():Int {
      #if META_HORROR
      return MetaHorror.getLocalHour();
      #else
      metaHorrorWarning(funk, 'getLocalHour');
      return 0;
      #end
    });

    // The player's local time as "HH:MM".
    FunkinLua.registerFunction("getLocalTimeString", function():String {
      #if META_HORROR
      return MetaHorror.getLocalTimeString();
      #else
      metaHorrorWarning(funk, 'getLocalTimeString');
      return '00:00';
      #end
    });

    // True inside the [fromHour, toHour) window; default 0-5 ("late night").
    FunkinLua.registerFunction("isLateNight", function(?fromHour:Int = 0, ?toHour:Int = 5):Bool {
      #if META_HORROR
      return MetaHorror.isLateNight(fromHour, toHour);
      #else
      metaHorrorWarning(funk, 'isLateNight');
      return false;
      #end
    });

    // 1 on the first ever launch, then 2, 3, ... (persisted across restarts).
    FunkinLua.registerFunction("getLaunchCount", function():Int {
      #if META_HORROR
      return MetaHorror.getLaunchCount();
      #else
      metaHorrorWarning(funk, 'getLaunchCount');
      return 0;
      #end
    });

    // ------------------------------------------------------------------
    // Persistent values ("the game remembers you")
    // ------------------------------------------------------------------

    FunkinLua.registerFunction("getPersistentValue", function(key:String, ?defaultValue:Float = 0):Float {
      #if META_HORROR
      return MetaHorror.getPersistentValue(key, defaultValue);
      #else
      metaHorrorWarning(funk, 'getPersistentValue');
      return defaultValue;
      #end
    });

    FunkinLua.registerFunction("setPersistentValue", function(key:String, value:Float):Bool {
      #if META_HORROR
      return MetaHorror.setPersistentValue(key, value);
      #else
      metaHorrorWarning(funk, 'setPersistentValue');
      return false;
      #end
    });

    FunkinLua.registerFunction("hasPersistentValue", function(key:String):Bool {
      #if META_HORROR
      return MetaHorror.hasPersistentValue(key);
      #else
      metaHorrorWarning(funk, 'hasPersistentValue');
      return false;
      #end
    });

    FunkinLua.registerFunction("addPersistentValue", function(key:String, ?amount:Float = 1):Float {
      #if META_HORROR
      return MetaHorror.addPersistentValue(key, amount);
      #else
      metaHorrorWarning(funk, 'addPersistentValue');
      return 0;
      #end
    });

    FunkinLua.registerFunction("clearPersistentValues", function():Bool {
      #if META_HORROR
      return MetaHorror.clearPersistentValues();
      #else
      metaHorrorWarning(funk, 'clearPersistentValues');
      return false;
      #end
    });

    // ------------------------------------------------------------------
    // Clipboard
    // ------------------------------------------------------------------

    FunkinLua.registerFunction("getClipboardText", function():String {
      #if META_HORROR
      return MetaHorror.getClipboardText();
      #else
      metaHorrorWarning(funk, 'getClipboardText');
      return '';
      #end
    });

    FunkinLua.registerFunction("setClipboardText", function(text:String):Bool {
      #if META_HORROR
      return MetaHorror.setClipboardText(text);
      #else
      metaHorrorWarning(funk, 'setClipboardText');
      return false;
      #end
    });

    // ------------------------------------------------------------------
    // Window title & focus games
    // ------------------------------------------------------------------

    FunkinLua.registerFunction("setWindowTitle", function(title:String):Bool {
      #if META_HORROR
      return MetaHorror.setWindowTitle(title);
      #else
      metaHorrorWarning(funk, 'setWindowTitle');
      return false;
      #end
    });

    FunkinLua.registerFunction("restoreWindowTitle", function():Bool {
      #if META_HORROR
      return MetaHorror.restoreWindowTitle();
      #else
      metaHorrorWarning(funk, 'restoreWindowTitle');
      return false;
      #end
    });

    FunkinLua.registerFunction("setAlwaysOnTop", function(enable:Bool = true):Bool {
      #if META_HORROR
      return MetaHorror.setAlwaysOnTop(enable);
      #else
      metaHorrorWarning(funk, 'setAlwaysOnTop');
      return false;
      #end
    });

    FunkinLua.registerFunction("isAlwaysOnTop", function():Bool {
      #if META_HORROR
      return MetaHorror.isAlwaysOnTop();
      #else
      metaHorrorWarning(funk, 'isAlwaysOnTop');
      return false;
      #end
    });

    FunkinLua.registerFunction("flashTaskbar", function(?times:Int = 3):Bool {
      #if META_HORROR
      return MetaHorror.flashTaskbar(times);
      #else
      metaHorrorWarning(funk, 'flashTaskbar');
      return false;
      #end
    });

    FunkinLua.registerFunction("stopTaskbarFlash", function() {
      #if META_HORROR
      MetaHorror.stopTaskbarFlash();
      #else
      metaHorrorWarning(funk, 'stopTaskbarFlash');
      #end
    });

    // ------------------------------------------------------------------
    // Looking at the desktop
    // ------------------------------------------------------------------

    // Titles of the other visible windows (never their contents).
    FunkinLua.registerFunction("getOpenWindowTitles", function():Array<String> {
      #if META_HORROR
      return MetaHorror.getOpenWindowTitles();
      #else
      metaHorrorWarning(funk, 'getOpenWindowTitles');
      return [];
      #end
    });

    // Screenshots the whole desktop to <temp>/phoenix_horror/<name>.png.
    FunkinLua.registerFunction("captureDesktop", function(?fileName:String = 'desktop', ?location:String):String {
      #if META_HORROR
      return MetaHorror.captureDesktop(fileName, location);
      #else
      metaHorrorWarning(funk, 'captureDesktop');
      return null;
      #end
    });

    // ------------------------------------------------------------------
    // Cleanup
    // ------------------------------------------------------------------

    // Undoes every effect at once; call it from onSongEnd/onGameOver.
    FunkinLua.registerFunction("restoreAllMetaEffects", function() {
      #if META_HORROR
      MetaHorror.restoreAll();
      #else
      metaHorrorWarning(funk, 'restoreAllMetaEffects');
      #end
    });

    }
  }

  /**
   * Tells the script author why the call did nothing (shown even without
   * luaDebugMode, so a mod is never silently broken on a standard build).
   * A no-op on META_HORROR builds, where the real implementations run.
   */
  static function metaHorrorWarning(funk:FunkinLua, fn:String):Void {
    #if !META_HORROR
    LuaUtils.luaTrace(funk.lua, '$fn: 4th-wall-breaking effects require a -DMETA_HORROR build of Phoenix Engine.', true, false, FlxColor.ORANGE);
    #end
  }
}
