package backend;

class Paths
{
  public static var noteSkinFramesMap:Map<String, Bool> = new Map();

  public static function initNote(skin:String):Void noteSkinFramesMap.set(skin, true);
  public static function voices(?song:String, ?difficulty:String, ?postfix:String):Dynamic return null;
  public static function inst(song:String, ?difficulty:String):Dynamic return null;
  public static function formatToSongPath(value:String):String return value.toLowerCase().replace(' ', '-');
  public static function songEvents(song:String, difficulty:String, ?json:Bool = false):String return '$song/events-$difficulty';
  public static function json(path:String):String return path;
  public static function modsJson(path:String):String return path;
}
