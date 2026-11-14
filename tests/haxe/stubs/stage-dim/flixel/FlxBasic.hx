package flixel;

/** The `FlxBasic` surface the stage-dim overlay and its spec rely on. */
class FlxBasic
{
  public var exists:Bool = true;
  public var visible:Bool = true;
  public var active:Bool = true;
  /** Members are appended in draw order; the overlay must stay last. */
  public var container:Dynamic = null;

  public function new() {}

  public function draw():Void {}
}
