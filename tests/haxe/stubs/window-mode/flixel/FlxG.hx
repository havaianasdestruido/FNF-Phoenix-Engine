package flixel;

/**
 * Minimal stand-in for the Flixel globals `backend.WindowMode` reads.
 *
 * `fullscreen` is a property so setting it propagates to the Lime window the
 * way the real Flixel/OpenFL stack does, which is what
 * `WindowMode.isFullscreenNow()` reads back.
 */
class FlxG
{
  static var _fullscreen:Bool = false;

  public static var stage:Dynamic = null;
  public static var width:Int = 1280;
  public static var height:Int = 720;

  public static var fullscreen(get, set):Bool;

  static function get_fullscreen():Bool
    return _fullscreen;

  static function set_fullscreen(value:Bool):Bool
  {
    _fullscreen = value;
    final stage = FlxG.stage;
    if (stage != null)
    {
      final window = stage.window;
      if (window != null) window.fullscreen = value;
    }
    return value;
  }

  public static function resizeWindow(width:Int, height:Int):Void
  {
    FlxG.width = width;
    FlxG.height = height;
  }
}
