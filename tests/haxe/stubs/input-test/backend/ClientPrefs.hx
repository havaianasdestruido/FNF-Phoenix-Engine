package backend;

import flixel.input.keyboard.FlxKey;

/** The preferences the page and the production helpers beside it read. Same names, same types. */
class ClientPrefs
{
  public static var globalAntialiasing:Bool = true;
  public static var androidTVNavigation:Bool = false;
  public static var uiScalePercent:Int = 100;
  public static var keyBinds:Map<String, Array<FlxKey>> = defaultKeyBinds();

  /** The engine's default Back binds (source/backend/ClientPrefs.hx). */
  public static function defaultKeyBinds():Map<String, Array<FlxKey>>
    return ['back' => [BACKSPACE, ESCAPE]];
}
