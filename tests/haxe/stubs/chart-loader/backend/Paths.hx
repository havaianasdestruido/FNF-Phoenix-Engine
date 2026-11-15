package backend;

class Paths
{
  public static var noteSkinFramesMap:Map<String, Bool> = new Map();

  public static var audioCalls:Array<Dynamic> = [];
  public static var missingPlayer:Bool = false;
  public static var missingSkinFiles:Map<String, Bool> = [];
  public static function fileExists(path:String, type:openfl.utils.AssetType):Bool return !missingSkinFiles.exists(path);
  public static function initNote(skin:String):Void noteSkinFramesMap.set(skin, true);
  public static function voices(?song:String, ?difficulty:String, ?postfix:String, ?stream:Bool = false):Dynamic
  {
    audioCalls.push({type: 'voices', postfix: postfix, stream: stream});
    return missingPlayer && postfix == 'Player' ? null : {};
  }
  public static function inst(song:String, ?difficulty:String, ?stream:Bool = false):Dynamic
  {
    audioCalls.push({type: 'inst', stream: stream});
    return {};
  }
  public static function formatToSongPath(value:String):String return value.toLowerCase().replace(' ', '-');
  public static function songEvents(song:String, difficulty:String, ?json:Bool = false):String
    return json ? 'events-$difficulty' : '$song/events-$difficulty';
  public static function json(path:String):String return 'assets/data/$path.json';
  public static function modsJson(path:String):String return path;
}
