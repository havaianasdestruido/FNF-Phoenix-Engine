import backend.VolumeCurve;

/**
 * Contract for `backend.VolumeCurve`, the mapping shared by the sound tray
 * (`objects.CustomSoundTray`) and Options -> Audio -> Master Volume.
 *
 * The module is Flixel-free on purpose, so this runs in the Haxe interpreter
 * with nothing but the compiler:
 *
 *     bash tests/haxe/run-volume-curve.sh
 *
 * The numbers pinned here are the ones the tray has always drawn: ten bars,
 * half the bars is `FlxG.sound.volume` ~= 0.03, and the quietest step is 0.001.
 * If the curve changes, the row and the `+`/`-` keys change together — that is
 * the whole point of the module, so a change here has to be deliberate.
 */
class VolumeCurveSpec
{
  static function main():Void
  {
    testEndpoints();
    testTrayHalfway();
    testRoundTrip();
    testTraySteps();
    testSteps();
    testClamping();

    trace('VolumeCurveSpec passed');
  }

  /** 0% is silence and 100% is full volume, whatever Flixel's setter clamps. */
  static function testEndpoints():Void
  {
    close(VolumeCurve.toVolume(1), 1, '100% is full volume');
    close(VolumeCurve.toVolume(0), 0, '0% is real silence, not the tray floor');
    close(VolumeCurve.toPercent(1), 1, 'full volume reads as 100%');
    close(VolumeCurve.toPercent(0), 0, 'silence reads as 0%');
  }

  /** Half the tray must be ~0.03, exactly as `logToLinear`/`linearToLog` did. */
  static function testTrayHalfway():Void
  {
    // sqrt(0.001): the geometric middle of the old curve.
    close(VolumeCurve.toVolume(0.5), 0.0316227766, 'half the slider is about 0.03', 1e-6);
    close(VolumeCurve.toPercent(0.0316227766), 0.5, 'a volume of ~0.03 is half the slider', 1e-6);

    // 25% / 75% sit on the same line, not on a straight volume split.
    close(VolumeCurve.toVolume(0.25), 0.0056234132, 'quarter of the slider', 1e-6);
    close(VolumeCurve.toVolume(0.75), 0.1778279410, 'three quarters of the slider', 1e-6);
    check(VolumeCurve.toVolume(0.5) < 0.05, 'the curve is logarithmic, not linear');
    // The other direction: a volume of 0.5 is near the top of the slider, which
    // is why a "half volume" number on a linear row would sound almost the same
    // as full volume.
    check(VolumeCurve.toPercent(0.5) > 0.85, 'linear 0.5 is high on the logarithmic slider');
  }

  /** The row and the tray convert in both directions without drifting. */
  static function testRoundTrip():Void
  {
    close(VolumeCurve.toPercent(VolumeCurve.toVolume(0)), 0, 'round trip at 0%', 1e-9);
    close(VolumeCurve.toPercent(VolumeCurve.toVolume(1)), 1, 'round trip at 100%', 1e-9);
    for (percent in [0.01, 0.05, 0.1, 0.2, 0.33, 0.5, 0.66, 0.75, 0.9, 0.99])
      close(VolumeCurve.toPercent(VolumeCurve.toVolume(percent)), percent, 'round trip at $percent', 1e-9);
  }

  /** The tray lights one bar per 10% of the slider. */
  static function testTraySteps():Void
  {
    equal(VolumeCurve.traySteps(1), 10, 'full volume fills the tray');
    equal(VolumeCurve.traySteps(0), 0, 'silence empties the tray');
    equal(VolumeCurve.traySteps(VolumeCurve.toVolume(0.5)), 5, 'half the slider is half the bars');
    equal(VolumeCurve.traySteps(0.5), 9, 'a linear half volume is 9 bars, not 5');
    equal(VolumeCurve.traySteps(VolumeCurve.toVolume(0.57)), 6, 'a position maps back to its bar');
    equal(VolumeCurve.traySteps(VolumeCurve.MIN_VOLUME), 0, 'the tray floor draws no bar');
    equal(VolumeCurve.traySteps(2), 10, 'out of range values stay inside the tray');
  }

  /** `+`/`-` steps use the same curve but stop at the tray floor. */
  static function testSteps():Void
  {
    // One 0.1 step from full volume: 100% -> 90% of the slider.
    final down:Float = VolumeCurve.steppedVolume(1, -0.1);
    close(VolumeCurve.toPercent(down), 0.9, 'a step down moves 10% of the slider', 1e-9);
    close(VolumeCurve.steppedVolume(VolumeCurve.MIN_VOLUME, 0.1), VolumeCurve.toVolume(0.1), 'a step up leaves the floor', 1e-9);

    // The floor keeps the tray's auto-hide timer running (it only counts down
    // while the volume is above 0), which is why the keys never reach silence.
    close(VolumeCurve.steppedVolume(VolumeCurve.MIN_VOLUME, -0.1), VolumeCurve.MIN_VOLUME, 'the keys stop at the tray floor', 1e-12);
    close(VolumeCurve.steppedVolume(0.0005, -0.1), VolumeCurve.MIN_VOLUME, 'a volume below the floor stays on it', 1e-12);
    close(VolumeCurve.steppedVolume(0, 0.1), VolumeCurve.toVolume(0.1), 'a row that reached 0% is recoverable with a key', 1e-9);
  }

  /** Saved files and hand-edited values can be anything; the row must not crash. */
  static function testClamping():Void
  {
    close(VolumeCurve.toVolume(-1), 0, 'negative percentages are silent');
    close(VolumeCurve.toVolume(4), 1, 'percentages above 100% are full volume');
    close(VolumeCurve.toPercent(-1), 0, 'negative volumes are silent');
    close(VolumeCurve.toPercent(9), 1, 'volumes above 1 are full volume');
    close(VolumeCurve.toPercent(Math.NaN), 0, 'NaN reads as 0%');
    close(VolumeCurve.toVolume(Math.NaN), 0, 'NaN writes real silence');
    close(VolumeCurve.toPercent(Math.POSITIVE_INFINITY), 1, 'infinity is full volume');
    close(VolumeCurve.toVolume(Math.NEGATIVE_INFINITY), 0, 'negative infinity is silence');
  }

  static function close(actual:Float, expected:Float, ?label:String = '', ?epsilon:Float = 0.0001):Void
  {
    if (Math.isNaN(actual)) throw '$label: got NaN, expected $expected';
    if (Math.abs(actual - expected) > epsilon)
      throw '$label: expected $expected, got $actual (tolerance $epsilon)';
  }

  static function equal<T>(actual:T, expected:T, label:String):Void
  {
    if (actual != expected) throw '$label: expected $expected, got $actual';
  }

  static function check(ok:Bool, label:String):Void
  {
    if (!ok) throw label;
  }
}
