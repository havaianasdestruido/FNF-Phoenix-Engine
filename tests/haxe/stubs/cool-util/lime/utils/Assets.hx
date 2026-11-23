package lime.utils;

/**
 * Minimal Assets stand-in: exists()/getText() answer from `scriptedText`.
 * Null means "asset missing".
 */
class Assets
{
  /** Scripted asset content; null means the asset does not exist. */
  public static var scriptedText:Null<String> = null;

  /** Scripted existence checks: when `scriptedExists` is set it wins. */
  public static var scriptedExists:Null<Bool> = null;

  /** Returns the scripted existence flag (defaults to scriptedText != null). */
  public static function exists(path:String):Bool
    return scriptedExists != null ? scriptedExists : scriptedText != null;

  /** Returns the scripted text, or null when unset. */
  public static function getText(path:String):String
    return scriptedText;

  /** Clears the scripted asset. */
  public static function reset():Void
  {
    scriptedText = null;
    scriptedExists = null;
  }
}
