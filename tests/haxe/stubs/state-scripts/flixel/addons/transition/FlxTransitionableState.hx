package flixel.addons.transition;

/** Flag-only stand-in: the transition system never runs in the interpreter. */
class FlxTransitionableState
{
  public static var skipNextTransIn:Bool = false;
  public static var skipNextTransOut:Bool = false;

  public static function reset():Void
  {
    skipNextTransIn = false;
    skipNextTransOut = false;
  }
}
