package play;

class PlayState
{
  public static var startOnTime:Float = 0;

  public var startingSong:Bool = false;
  public var startedCountdown:Bool = true;
  public var paused:Bool = false;
  public var endingSong:Bool = false;
  public var isDead:Bool = false;
  public var transitioning:Bool = false;
  public var inCutscene:Bool = false;
  public var ffmpegMode:Bool = false;
  public var finishTimer:Dynamic = null;
  public var playbackRate:Float = 1;
  public var curBeat:Int = 0;
  public var lastMetronomeBeat:Int = -1;
  public var metronomeResumeTime:Null<Float> = null;

  public function new() {}
}
