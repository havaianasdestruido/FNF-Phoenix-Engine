package flixel;

/** The state surface the page overrides or calls, with what the spec needs to see. */
class FlxState
{
  public var persistentUpdate:Bool = false;

  /** Everything the page added, in draw order. */
  public var members:Array<FlxSprite> = [];

  public var created:Bool = false;
  public var destroyed:Bool = false;

  public function new() {}

  public function add(sprite:FlxSprite):FlxSprite
  {
    members.push(sprite);
    return sprite;
  }

  public function create():Void
    created = true;

  public function update(elapsed:Float):Void {}

  public function destroy():Void
    destroyed = true;

  public function onResize(width:Int, height:Int):Void {}

  public function onFocusLost():Void {}

  public function onFocus():Void {}
}
