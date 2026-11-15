package play;

/**
 * Stand-in for the two `PlayState` members `shaders.EffectTicker` uses: the
 * static `instance` it checks to know whether a song is live, and the
 * `shaderUpdates` list every time-driven effect in the engine pushes onto.
 *
 * The real state also never nulls `instance` in `destroy()`, which is exactly why
 * the ticker compares `FlxG.state` against it instead of trusting it alone; the
 * spec reproduces both situations.
 */
class PlayState
{
  public static var instance:PlayState = null;

  public var shaderUpdates:Array<Float->Void> = [];

  public function new() {}
}
