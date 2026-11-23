package flixel;

/** Minimal save-game stand-in: records flush() calls, holds an open data bag. */
class FlxSave
{
  public var data:Dynamic = {};
  public var flushCount:Int = 0;

  public function new() {}

  public function flush():Void
  {
    flushCount++;
  }
}

/** Minimal FlxG: only the save surface that backend/Highscore.hx uses. */
class FlxG
{
  public static var save:FlxSave = new FlxSave();
}
