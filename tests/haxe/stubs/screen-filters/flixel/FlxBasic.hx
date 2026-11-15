package flixel;

/**
 * Marker stand-in for FlxBasic. The real class is *not* an openfl DisplayObject
 * (only `FlxSprite.flashSprite` / `FlxCamera.flashSprite` are), which is why
 * `FlxCamera` may declare its own `filters` field. The stub has to keep that
 * shape or the camera would clash with openfl's inherited property.
 */
class FlxBasic
{
  public var active:Bool = true;

  public function new() {}

  public function update(elapsed:Float):Void {}

  public function draw():Void {}
}
