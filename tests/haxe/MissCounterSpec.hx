import play.objects.MissCounter;

/** Renderer-free tests for Doido's consecutive-miss popup contract. */
class MissCounterSpec
{
  static function equal<T>(actual:T, expected:T, label:String):Void
  {
    if (actual != expected) throw '$label: expected $expected, got $actual';
  }

  static function main():Void
  {
    final counter = new MissCounter();
    equal(counter.count, 0, 'new song');
    equal(counter.miss(), 1, 'first miss');
    equal(counter.miss(), 2, 'second miss');
    equal(counter.miss(), 3, 'chord/sustain miss');
    counter.hit();
    equal(counter.count, 0, 'head hit resets streak');
    equal(counter.miss(), 1, 'new streak');
    counter.reset();
    equal(counter.count, 0, 'retry resets streak');

    final digits:Array<Dynamic> = [];
    equal(MissCounter.digits(-1, digits).join(','), 'neg,1', 'minus one');
    equal(MissCounter.digits(-123, digits).join(','), 'neg,1,2,3', 'multi-digit miss');
    equal(MissCounter.digits(405, digits).join(','), '4,0,5', 'hit digits');
    equal(MissCounter.digits(0, digits).join(','), '0', 'zero');
    final reused = digits;
    MissCounter.digits(-2, digits);
    equal(digits == reused, true, 'digit buffer reused');
    equal(digits.join(','), 'neg,2', 'no stale digits');

    equal(MissCounter.color(-3, true), MissCounter.RED, 'miss stays red');
    equal(MissCounter.color(1, true), MissCounter.WHITE, 'recycled hit clears red');
    equal(MissCounter.color(-3, false, true), 0xFFCC4242, 'legacy miss tint');
    equal(MissCounter.color(1, false), MissCounter.WHITE, 'legacy hit');
    Sys.println('MissCounterSpec: PASS');
  }
}
