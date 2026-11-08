package play.objects;

/**
 * Consecutive-miss popup state, independent of score/accuracy accounting.
 * Kept renderer-free so its reset and digit/color rules can be tested directly.
 */
class MissCounter
{
  public static inline var RED:Int = 0xFFFF0000;
  public static inline var WHITE:Int = 0xFFFFFFFF;

  public var count(default, null):Int = 0;

  public function new() {}

  /** Adds one missed note (a chord calls this once per missed note). */
  public function miss():Int
  {
    return ++count;
  }

  /** A successful head hit ends the streak; sustain ticks do not. */
  public function hit():Void
  {
    count = 0;
  }

  public function reset():Void
  {
    count = 0;
  }

  /** Reuses the supplied digit array; "neg" uses the existing numneg asset. */
  public static function digits(value:Float, out:Array<Dynamic>):Array<Dynamic>
  {
    while (out.length > 0)
      out.pop();

    var remaining:Float = Math.abs(value);
    final last:Float = remaining % 10;
    while (remaining >= 10)
    {
      out.unshift(Math.ffloor(remaining / 10) % 10);
      remaining = Math.ffloor(remaining / 10);
    }
    out.push(last);
    if (value < 0)
      out.unshift('neg');
    return out;
  }

  /** Negative combos stay red even when a recycled popup is used for a hit. */
  public static function color(value:Float, enabled:Bool, legacyMiss:Bool = false):Int
  {
    if (enabled && value < 0)
      return RED;
    return !enabled && legacyMiss ? 0xFFCC4242 : WHITE;
  }
}
