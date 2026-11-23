package play;

class PlayState
{
  public function new() {}

  public static var instance:PlayState;
  // Difficulty index read by CoolUtil.getDifficultyFilePath/difficultyString.
  public static var storyDifficulty:Int = 1;
  public var ratingsData:Dynamic = [];
  public var perfects:Int = 0;
  public var sicks:Int = 0;
  public var goods:Int = 0;
  public var bads:Int = 0;
  public var poorRatings:Int = 0;
}
