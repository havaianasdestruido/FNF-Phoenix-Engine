package flixel.text;

import flixel.util.FlxColor;

/**
 * Border style enum declared at module level, mirroring Flixel, where
 * `import flixel.text.FlxText;` brings these values into scope.
 */
enum FlxTextBorderStyle
{
  NONE;
  SHADOW;
  OUTLINE;
  OUTLINE_FAST;
}

/**
 * Minimal FlxText stand-in: just enough state for CoolUtil.setTextBorderFromString
 * (and any spec that wants to assert on it).
 */
class FlxText
{
  public var text:String;
  public var x:Float;
  public var y:Float;
  public var width:Float;
  public var size:Int;
  public var color:FlxColor = 0xFFFFFFFF;
  public var borderStyle:FlxTextBorderStyle = FlxTextBorderStyle.NONE;
  public var borderSize:Float = 1;
  public var borderColor:FlxColor = 0xFF000000;

  public function new(x:Float, y:Float, width:Float, text:String, size:Int = 8)
  {
    this.x = x;
    this.y = y;
    this.width = width;
    this.text = text;
    this.size = size;
  }

  /** No-op destroy for API compatibility. */
  public function destroy():Void {}
}
