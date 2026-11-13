package play;

class PlayState
{
  public static var instance:PlayState;
  public var ratingsData:Dynamic = [];
  public var perfects:Int = 0;
  public var sicks:Int = 0;
  public var goods:Int = 0;
  public var bads:Int = 0;
  public var poorRatings:Int = 0;
}
