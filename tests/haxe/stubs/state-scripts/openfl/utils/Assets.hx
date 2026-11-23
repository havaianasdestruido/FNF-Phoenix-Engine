package openfl.utils;

/** Empty asset library: nothing resolves, so the sys filesystem decides. */
class Assets
{
  public static function exists(path:String):Bool
    return false;
}
