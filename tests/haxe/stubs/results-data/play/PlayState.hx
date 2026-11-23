package play;

/** Minimal stand-in carrying the fields ResultsData.fromPlayState reads. */
class PlayState
{
  public static var storyDifficulty:Int = 1;

  public function new() {}

  public var songScore:Float = 0;
  public var totalPlayed:Int = 0;
  public var totalNotesHit:Float = 0;
  public var perfects:Int = 0;
  public var sicks:Int = 0;
  public var goods:Int = 0;
  public var bads:Int = 0;
  public var poorRatings:Int = 0;
  public var songMisses:Float = 0;
  public var maxCombo:Float = 0;
  public var maxNPS:Float = 0;
  public var fcStrings:Array<String> = [];
  public var ratingFC:String = 'No Play';
  public var hitOffsets:Array<Float> = [];
}
