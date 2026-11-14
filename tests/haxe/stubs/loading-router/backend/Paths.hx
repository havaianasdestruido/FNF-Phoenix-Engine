package backend;
class Paths
{
  public static var probes:Int = 0;
  public static function inst(song:String):Dynamic { probes++; return 'inst'; }
  public static function voices(song:String):Dynamic { probes++; return 'voices'; }
}
