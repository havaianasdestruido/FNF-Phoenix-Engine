package play;
class PlayState extends flixel.FlxState
{
  public static var SONG:Dynamic = null;
  public static var count:Int = 0;
  public var marker:String;
  public function new(marker:String = '') { super(); this.marker = marker; count++; }
}
