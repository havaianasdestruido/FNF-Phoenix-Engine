package play;
import flixel.text.FlxText;
import play.helpers.PlayStateAdaptivePerformance;
class PlayState
{
  public var adaptivePerformance:PlayStateAdaptivePerformance;
  public var startedCountdown:Bool = true;
  public var startingSong:Bool = false;
  public var endingSong:Bool = false;
  public var inCutscene:Bool = false;
  public var paused:Bool = false;
  public var isDead:Bool = false;
  public var transitioning:Bool = false;
  public var finishTimer:Dynamic = null;
  public var subState:Dynamic = null;
  public var ffmpegMode:Bool = false;
  public var camOther:Dynamic = {};
  public var grpNoteSplashes:MockGroup<MockSprite> = new MockGroup();
  public var grpHoldSplashes:MockGroup<MockSprite> = new MockGroup();
  public var popUpGroup:MockGroup<MockPopup> = new MockGroup();
  public var timingGroup:MockGroup<MockSprite> = new MockGroup();
  public var judgeTxt:MockJudge = new MockJudge();
  public var added:Array<FlxText> = [];
  public var songScore:Int = 1234;
  public var health:Float = 1;
  public function new() {}
  public function add(text:FlxText):FlxText { added.push(text); return text; }
}
class MockGroup<T>
{
  public var members:Array<T> = [];
  public function new() {}
}
class MockSprite
{
  public var exists:Bool = true;
  public var kills:Int = 0;
  public function new() {}
  public function kill():Void { exists = false; kills++; }
}
class MockPopup extends MockSprite
{
  public var isRatingPopup:Bool;
  public function new(isRating:Bool) { super(); isRatingPopup = isRating; }
}
class MockJudge
{
  public var visible:Bool = true;
  public var scale:Dynamic = {};
  public function new() {}
}
