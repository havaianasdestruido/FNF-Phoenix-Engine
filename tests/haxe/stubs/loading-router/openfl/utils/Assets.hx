package openfl.utils;
class AssetCache
{
  public var loaded:Bool = false;
  public function new() {}
  public function hasSound(id:String):Bool return loaded;
}
class Assets
{
  public static var cache:AssetCache = new AssetCache();
  public static var libraries:Bool = false;
  public static function getLibrary(id:String):Dynamic return libraries ? {} : null;
}
