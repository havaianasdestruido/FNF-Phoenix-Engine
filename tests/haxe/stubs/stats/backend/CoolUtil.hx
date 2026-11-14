package backend;

class CoolUtil
{
  public static function formatToSongPath(path:String):String
    return path.toLowerCase();

  public static function floorDecimal(value:Float, decimals:Int):Float
  {
    if (decimals < 1) return Math.floor(value);
    var mult:Float = 1;
    for (_ in 0...decimals) mult *= 10;
    return Math.floor(value * mult) / mult;
  }
}
