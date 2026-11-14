package play;

/** Only the lifecycle flags read by PlayStateHaptics. */
class PlayState
{
  public var paused:Bool = false;
  public var endingSong:Bool = false;
  public var isDead:Bool = false;
  public var inCutscene:Bool = false;
  public var transitioning:Bool = false;
  public var ffmpegMode:Bool = false;
  public var subState:Dynamic = null;

  public function new() {}
}
