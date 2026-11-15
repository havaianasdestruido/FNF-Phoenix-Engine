package backend;
class Paths
{
  public static var files:Map<String, String> = [];
  public static var missingSkinFiles:Map<String, Bool> = [];
  public static var atlasCalls:Int = 0;
  public static function fileExists(path:String, type:openfl.utils.AssetType):Bool return !missingSkinFiles.exists(path);
  public static function characterFileText(name:String, fallback:String):String
  {
    final found = files.get('characters/' + name + '.json');
    return found != null ? found : files.get('characters/' + fallback + '.json');
  }
  public static function getPreloadPath(key:String):String return key;
  public static function modFolders(key:String):String return key;
  public static function getMultiAtlas(keys:Array<String>):flixel.graphics.frames.FlxAtlasFrames
  {
    atlasCalls++;
    throw 'metadata-only characters must not load atlases';
  }
  public static function formatToSongPath(key:String):String return key;
}
