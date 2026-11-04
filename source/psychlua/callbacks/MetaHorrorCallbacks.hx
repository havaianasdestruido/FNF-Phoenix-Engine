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

    FunkinLua.registerFunction("setWindowAlpha", function(alpha:Float):Bool {
      #if META_HORROR
      return MetaHorror.setWindowAlpha(alpha);
      #else
      metaHorrorWarning(funk, 'setWindowAlpha');
      return false;
      #end
    });

    FunkinLua.registerFunction("setWindowColorKey", function(color:Int):Bool {
      #if META_HORROR
      return MetaHorror.setWindowColorKey(color);
      #else
      metaHorrorWarning(funk, 'setWindowColorKey');
      return false;
      #end
    });

    FunkinLua.registerFunction("resetWindowEffects", function():Bool {
      #if META_HORROR
      return MetaHorror.resetWindowEffects();
      #else
      metaHorrorWarning(funk, 'resetWindowEffects');
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
