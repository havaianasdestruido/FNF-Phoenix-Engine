import backend.ClientPrefs;
import backend.LoadingDialLogic;
import flixel.FlxG;
import flixel.addons.display.FlxPieDial;
import objects.LoadingPieDial;

/**
 * Contract for the bottom-left `FlxPieDial` loading indicator:
 * color normalization, bottom-left corner anchoring across viewport sizes,
 * frame-0 full-circle flash protection, count-to-progress mapping, and
 * `objects.LoadingPieDial` wiring.
 */
class LoadingDialSpec
{
  static var failures:Int = 0;

  static function check(ok:Bool, label:String, ?pos:haxe.PosInfos):Void
  {
    if (ok) return;
    failures++;
    trace('FAIL: ' + label + ' @' + (pos == null ? 0 : pos.lineNumber));
  }

  static function near(actual:Float, expected:Float, label:String):Void
  {
    check(Math.abs(actual - expected) < 0.0001, '$label (expected $expected, got $actual)');
  }

  static function main():Void
  {
    testColors();
    testPositioning();
    testDialAmount();
    testProgressFromCounts();
    testWidget();

    if (failures > 0)
      throw 'LoadingDialSpec: $failures failure(s)';
    trace('LoadingDialSpec: PASS');
  }

  static function testColors():Void
  {
    final names:Array<String> = LoadingDialLogic.colorNames();
    check(names.length >= 2, 'at least two color presets exist');
    check(names[0] == LoadingDialLogic.DEFAULT_COLOR, 'default color leads the preset list');

    check(LoadingDialLogic.normalizeColor(null) == LoadingDialLogic.DEFAULT_COLOR, 'null falls back to default color');
    check(LoadingDialLogic.normalizeColor('  unknown  ') == LoadingDialLogic.DEFAULT_COLOR, 'unknown preset falls back to default');
    check(LoadingDialLogic.normalizeColor('  wHiTe ') == 'White', 'preset normalization trims and ignores case');
    check(LoadingDialLogic.colorValue('Pink') == 0xFFFF16D2, 'pink preset matches Phoenix loading accent');
    check(LoadingDialLogic.colorValue('cyan') == 0xFF00E5FF, 'cyan preset resolves case-insensitively');
    check(LoadingDialLogic.colorValue('garbage') == 0xFFFF16D2, 'invalid color falls back to pink');
  }

  static function testPositioning():Void
  {
    final diameter:Float = LoadingDialLogic.RADIUS * 2;
    final stdPos = LoadingDialLogic.position(1280, 720, diameter, diameter);
    near(stdPos.x, LoadingDialLogic.MARGIN, 'standard 720p x uses left margin');
    near(stdPos.y, 720 - diameter - LoadingDialLogic.MARGIN, 'standard 720p y sits in bottom-left corner');

    // Widescreen viewport expands horizontally while keeping the dial anchored bottom-left.
    final widePos = LoadingDialLogic.position(1920, 720, diameter, diameter);
    near(widePos.x, LoadingDialLogic.MARGIN, 'widescreen keeps dial on the left edge');
    near(widePos.y, 720 - diameter - LoadingDialLogic.MARGIN, 'widescreen keeps dial on the bottom edge');

    // Tiny/degenerate viewports clamp safely instead of placing the dial off-screen.
    final tinyPos = LoadingDialLogic.position(40, 40, diameter, diameter);
    near(tinyPos.x, 0, 'narrow viewport clamps x to 0');
    near(tinyPos.y, 0, 'short viewport clamps y to 0');
  }

  static function testDialAmount():Void
  {
    near(LoadingDialLogic.dialAmount(Math.NaN, 40), 0, 'NaN progress resets to 0');
    near(LoadingDialLogic.dialAmount(-0.2, 40), 0, 'negative progress clamps to 0');
    near(LoadingDialLogic.dialAmount(0, 40), 0, 'zero progress stays 0');
    // Sub-step positive fractions (< 1/40) would hit FlxPieDial frame 0 (full circle).
    near(LoadingDialLogic.dialAmount(0.01, 40), 0, 'sub-step fraction snaps to 0 instead of flashing full circle');
    near(LoadingDialLogic.dialAmount(0.024, 40), 0, 'just below 1/40 still snaps to 0');
    near(LoadingDialLogic.dialAmount(0.03, 40), 0.03, 'first valid step is preserved');
    near(LoadingDialLogic.dialAmount(0.5, 40), 0.5, 'mid progress is preserved');
    check(LoadingDialLogic.dialAmount(0.99999, 40) < 1, 'near-complete progress stays below 1');
    near(LoadingDialLogic.dialAmount(1.0, 40), 1, 'exact completion returns 1');
    near(LoadingDialLogic.dialAmount(1.5, 40), 1, 'over-complete progress clamps to 1');
  }

  static function testProgressFromCounts():Void
  {
    near(LoadingDialLogic.progressFromCounts(0, 0), 1, 'zero total reports complete');
    near(LoadingDialLogic.progressFromCounts(-1, 10), 0, 'negative count clamps to 0');
    near(LoadingDialLogic.progressFromCounts(5, 20), 0.25, 'quarter count');
    near(LoadingDialLogic.progressFromCounts(25, 20), 1, 'overshoot count clamps to 1');
  }

  static function testWidget():Void
  {
    FlxG.width = 1280;
    FlxG.height = 720;
    ClientPrefs.loadingPieDialColor = 'Cyan';
    ClientPrefs.globalAntialiasing = true;

    final dial = new LoadingPieDial();
    final expectedSize:Float = LoadingDialLogic.RADIUS * 2;
    near(dial.x, LoadingDialLogic.MARGIN, 'widget starts at bottom-left x');
    near(dial.y, 720 - expectedSize - LoadingDialLogic.MARGIN, 'widget starts at bottom-left y');
    check(dial.scrollFactor.x == 0 && dial.scrollFactor.y == 0, 'group pins scrollFactor to 0');

    check(dial.trackDial != null && dial.progressDial != null, 'widget builds both track and progress FlxPieDials');
    near(dial.trackDial.amount, 1, 'track dial stays full');
    near(dial.trackDial.alpha, LoadingDialLogic.TRACK_ALPHA, 'track dial uses subtle alpha');
    check(dial.trackDial.shape == FlxPieDialShape.CIRCLE && dial.progressDial.shape == FlxPieDialShape.CIRCLE,
      'both dials are circular');
    check(dial.progressDial.clockwise, 'progress dial fills clockwise');
    check(dial.progressDial.innerRadius == LoadingDialLogic.INNER_RADIUS, 'progress dial uses ring cutout');
    check(dial.progressDial.color == 0xFF00E5FF, 'widget picks up ClientPrefs.loadingPieDialColor');
    check(dial.progressDial.antialiasing && dial.trackDial.antialiasing, 'antialiasing follows global preference');
    near(dial.progressDial.amount, 0, 'progress dial starts empty');

    dial.setProgress(0.01);
    near(dial.progressDial.amount, 0, 'widget guards tiny progress values');
    dial.setProgress(0.6);
    near(dial.progressDial.amount, 0.6, 'widget forwards mid progress');
    dial.setProgress(1.0);
    near(dial.progressDial.amount, 1.0, 'widget completes at 1.0');

    dial.layout(1600, 900);
    near(dial.x, LoadingDialLogic.MARGIN, 'resize keeps dial on left margin');
    near(dial.y, 900 - expectedSize - LoadingDialLogic.MARGIN, 'resize anchors dial to new bottom');

    final overrideDial = new LoadingPieDial('White');
    check(overrideDial.progressDial.color == 0xFFFFFFFF, 'explicit color argument overrides ClientPrefs');
  }
}
