package flixel;

/** Minimal scale-mode point. */
class FlxPoint
{
  public var x:Float;
  public var y:Float;

  public function new(x:Float = 0, y:Float = 0)
  {
    this.x = x;
    this.y = y;
  }
}

/** Minimal scale mode: the only member ScreenDensity reads is `scale`. */
class ScaleMode
{
  public var scale:FlxPoint;

  public function new(x:Float = 1, y:Float = 1)
  {
    scale = new FlxPoint(x, y);
  }
}

/** Minimal window: ScreenDensity only reads `scale`. */
class FlxWindow
{
  public var scale:Float;

  public function new(scale:Float = 1)
  {
    this.scale = scale;
  }
}

/** Minimal stage: ScreenDensity only reads `window`. */
class FlxStage
{
  public var window:FlxWindow;

  public function new(windowScale:Float = 1)
  {
    window = new FlxWindow(windowScale);
  }
}

/** Settable stand-in for FlxG's globals. */
class FlxG
{
  public static var scaleMode:ScaleMode = null;
  public static var stage:FlxStage = null;

  public static function reset():Void
  {
    scaleMode = null;
    stage = null;
  }
}
