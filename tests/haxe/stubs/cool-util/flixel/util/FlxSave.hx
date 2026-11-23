package flixel.util;

/**
 * Minimal FlxSave stand-in. CoolUtil reaches into `validate` through
 * `@:access`; returning the input unchanged keeps getSavePath deterministic.
 */
class FlxSave
{
  /** Pass-through so specs can assert on the company/file path directly. */
  @:allow(backend.CoolUtil)
  private static function validate(file:String):String
    return file == null ? '' : StringTools.trim(file);
}
