package backend;

class Paths
{
  public static function formatToSongPath(value:String):String return value.toLowerCase().replace(' ', '-');
  public static function json(path:String):String return 'assets/data/$path.json';
  public static function modsJson(path:String):String return 'mods/data/$path.json';
}
