import backend.FramerateMath;

/**
 * Menu framerate contract: the cap rules behind `ClientPrefs.framerate`,
 * `ClientPrefs.menuFramerate` and `ClientPrefs.focusLostFramerate`.
 *
 * The stateful half (writing FlxG) lives in `backend.FramerateController` and
 * is exercised by the engine build; everything a save file can corrupt is
 * covered here. Run with:
 *
 *     bash tests/haxe/run-menu-framerate.sh
 */
class FramerateSpec
{
  static var failures:Int = 0;

  static function check(ok:Bool, label:String, ?pos:haxe.PosInfos):Void
  {
    if (ok) return;
    failures++;
    Sys.println('FAIL: ' + label + ' @' + (pos == null ? 0 : pos.lineNumber));
  }

  static function main():Void
  {
    capBands();
    clampBounds();
    clampExtremes();
    stateSelection();

    if (failures > 0)
    {
      Sys.println('FramerateSpec: $failures failure(s)');
      Sys.exit(1);
    }
    Sys.println('FramerateSpec: PASS');
  }

  /** The cap follows the Uncapped FPS option, like the options row's max. */
  static function capBands():Void
  {
    check(FramerateMath.cap(false) == FramerateMath.DEFAULT_CAP, 'the default cap is the shared band');
    check(FramerateMath.cap(true) == FramerateMath.UNCAPPED_CAP, 'uncapped lifts the cap');
    check(FramerateMath.DEFAULT_CAP == 1000, 'the shared band matches the options row');
    check(FramerateMath.UNCAPPED_CAP == 10000, 'the uncapped band matches the options row');
  }

  /** Hand-edited saves hold nothing outside the band. */
  static function clampBounds():Void
  {
    check(FramerateMath.clamp(0, false) == FramerateMath.MIN_FPS, 'zero clamps to the floor');
    check(FramerateMath.clamp(-1, false) == FramerateMath.MIN_FPS, 'negatives clamp to the floor');
    check(FramerateMath.clamp(-10000, true) == FramerateMath.MIN_FPS, 'deep negatives clamp to the floor');
    check(FramerateMath.clamp(1, false) == 1, 'the floor itself is legal');
    check(FramerateMath.clamp(60, false) == 60, 'a sane value is kept');
    check(FramerateMath.clamp(1000, false) == 1000, 'the shared cap itself is legal');
    check(FramerateMath.clamp(1001, false) == 1000, 'over the shared cap clamps');
    check(FramerateMath.clamp(10000, true) == 10000, 'the uncapped cap itself is legal');
    check(FramerateMath.clamp(10001, true) == 10000, 'over the uncapped cap clamps');
    check(FramerateMath.clamp(5000, false) == 1000, 'uncapped values need the option on');
    check(FramerateMath.clamp(5000, true) == 5000, 'uncapped values pass with the option on');
  }

  /** Huge ints never wrap around. */
  static function clampExtremes():Void
  {
    check(FramerateMath.clamp(2147483647, false) == 1000, 'Int.MAX clamps, never wraps');
    check(FramerateMath.clamp(2147483647, true) == 10000, 'Int.MAX clamps to the uncapped cap');
    check(FramerateMath.clamp(-2147483648, false) == FramerateMath.MIN_FPS, 'Int.MIN clamps to the floor');
  }

  /** Only gameplay keeps the gameplay rate. */
  static function stateSelection():Void
  {
    check(FramerateMath.stateRate(true, 144, 60) == 144, 'gameplay keeps its rate');
    check(FramerateMath.stateRate(false, 144, 60) == 60, 'menus run at the menu rate');
    check(FramerateMath.stateRate(false, 1000, 1000) == 1000, 'matching rates are a no-op');
    check(FramerateMath.stateRate(true, 60, 30) == 60, 'the menu rate never leaks into gameplay');
  }
}
