package backend;
class Paths
{
  public static var files:Map<String, String> = [];
  public static var reads:Array<String> = [];
  public static function characterFileText(name:String, fallback:String):String
  {
    final path = 'characters/' + name + '.json';
    reads.push(path);
    if (files.exists(path)) return files.get(path);
    final fallbackPath = 'characters/' + fallback + '.json';
    reads.push(fallbackPath);
    return files.get(fallbackPath);
  }
}
