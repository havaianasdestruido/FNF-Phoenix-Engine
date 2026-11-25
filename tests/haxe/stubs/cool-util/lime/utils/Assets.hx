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

  /** Per-path scripted text map for multi-library lookup assertions. */
  public static var scriptedMap:Map<String, String> = null;

  /** Returns the scripted existence flag (defaults to scriptedMap / scriptedText != null). */
  public static function exists(path:String):Bool
  {
    if (scriptedMap != null)
      return scriptedMap.exists(path);
    return scriptedExists != null ? scriptedExists : scriptedText != null;
  }

  /** Returns the scripted text, or null when unset. */
  public static function getText(path:String):String
  {
    if (scriptedMap != null)
      return scriptedMap.get(path);
    return scriptedText;
  }

  /** Clears the scripted asset. */
  public static function reset():Void
  {
    scriptedText = null;
    scriptedExists = null;
    scriptedMap = null;
  }
}
