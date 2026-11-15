import backend.AccuracyPresets;
import backend.GamepadDeadzone;

/**
 * Exercises `backend.AccuracyPresets`, `backend.GamepadDeadzone`, and their
 * wiring in `ClientPrefs`, `GameplaySettingsSubState`, `InitState`, and
 * `SettingsBackup`.
 *
 * Run with:
 *
 *     bash tests/haxe/run-accuracy-presets.sh
 */
class AccuracyPresetsSpec
{
  static inline var PREFS:String = 'source/backend/ClientPrefs.hx';
  static inline var GAMEPLAY:String = 'source/options/GameplaySettingsSubState.hx';
  static inline var INIT:String = 'source/states/InitState.hx';
  static inline var BACKUP:String = 'source/backend/SettingsBackup.hx';

  static function main():Void
  {
    testPresetCatalog();
    testDetectionAndCustomSwitch();
    testNeighbourBounds();
    testSafeFramesFormat();
    testGamepadDeadzoneClamp();
    testSourceWiring();

    Sys.println('AccuracyPresetsSpec: PASS');
  }

  static function testPresetCatalog():Void
  {
    equal(AccuracyPresets.NAMES.length, 5, 'five preset choices');
    equal(AccuracyPresets.NAMES[0], AccuracyPresets.VANILLA, 'Vanilla listed first');
    equal(AccuracyPresets.NAMES[1], AccuracyPresets.PSYCH, 'Psych listed second');
    equal(AccuracyPresets.NAMES[2], AccuracyPresets.KADE, 'Kade listed third');
    equal(AccuracyPresets.NAMES[3], AccuracyPresets.ITG, 'ITG listed fourth');
    equal(AccuracyPresets.NAMES[4], AccuracyPresets.CUSTOM, 'Custom listed fifth');

    equal(AccuracyPresets.normalize(null), AccuracyPresets.PSYCH, 'null normalizes to Psych');
    equal(AccuracyPresets.normalize(''), AccuracyPresets.PSYCH, 'blank normalizes to Psych');
    equal(AccuracyPresets.normalize('  kade '), AccuracyPresets.KADE, 'case-insensitive Kade');
    equal(AccuracyPresets.normalize('StepMania'), AccuracyPresets.ITG, 'StepMania alias -> ITG');
    equal(AccuracyPresets.normalize('unknown-preset'), AccuracyPresets.CUSTOM, 'unknown -> Custom');

    // Custom returns null so existing individual values stay untouched.
    check(AccuracyPresets.windowsFor(AccuracyPresets.CUSTOM) == null, 'Custom does not overwrite windows');

    // Every built-in preset must stay strictly ordered and keep safeFrames <= 10 so scores still save.
    for (name in [AccuracyPresets.VANILLA, AccuracyPresets.PSYCH, AccuracyPresets.KADE, AccuracyPresets.ITG])
    {
      final set = AccuracyPresets.windowsFor(name);
      check(set != null, '$name defines windows');
      check(set.perfect >= AccuracyPresets.MIN_PERFECT_WINDOW, '$name perfect >= min');
      check(set.perfect < set.sick, '$name perfect < sick');
      check(set.sick < set.good, '$name sick < good');
      check(set.good < set.bad, '$name good < bad');
      check(set.bad <= AccuracyPresets.MAX_BAD_WINDOW, '$name bad <= max');
      check(set.safeFrames <= 10.0, '$name keeps safeFrames <= 10 so highscores save');
    }

    final psych = AccuracyPresets.windowsFor(AccuracyPresets.PSYCH);
    close(psych.perfect, 15.0, 'Psych perfect default is 15.0 ms');
    close(psych.sick, 45.0, 'Psych sick default is 45.0 ms');
    close(psych.good, 90.0, 'Psych good default is 90.0 ms');
    close(psych.bad, 135.0, 'Psych bad default is 135.0 ms');
    close(psych.safeFrames, 10.0, 'Psych safeFrames default is 10.0');
  }

  static function testDetectionAndCustomSwitch():Void
  {
    for (name in [AccuracyPresets.PSYCH, AccuracyPresets.VANILLA, AccuracyPresets.KADE, AccuracyPresets.ITG])
    {
      final set = AccuracyPresets.windowsFor(name);
      equal(
        AccuracyPresets.detect(set.perfect, set.sick, set.good, set.bad, set.safeFrames),
        name,
        '$name round-trips through detect()'
      );
    }

    // Adjusting any single window or safeFrames switches detection to Custom.
    equal(AccuracyPresets.detect(18.0, 45.0, 90.0, 135.0, 10.0), AccuracyPresets.CUSTOM, 'tweaked perfect -> Custom');
    equal(AccuracyPresets.detect(15.0, 40.0, 90.0, 135.0, 10.0), AccuracyPresets.CUSTOM, 'tweaked sick -> Custom');
    equal(AccuracyPresets.detect(15.0, 45.0, 95.0, 135.0, 10.0), AccuracyPresets.CUSTOM, 'tweaked good -> Custom');
    equal(AccuracyPresets.detect(15.0, 45.0, 90.0, 140.0, 10.0), AccuracyPresets.CUSTOM, 'tweaked bad -> Custom');
    equal(AccuracyPresets.detect(15.0, 45.0, 90.0, 135.0, 11.0), AccuracyPresets.CUSTOM, 'tweaked safeFrames -> Custom');
  }

  static function testNeighbourBounds():Void
  {
    final b = AccuracyPresets.bounds(15.0, 45.0, 90.0, 135.0);
    close(b.perfectMin, 1.0, 'perfect min');
    close(b.perfectMax, 44.0, 'perfect max = sick - 1');
    close(b.sickMin, 16.0, 'sick min = perfect + 1');
    close(b.sickMax, 89.0, 'sick max = good - 1');
    close(b.goodMin, 46.0, 'good min = sick + 1');
    close(b.goodMax, 134.0, 'good max = bad - 1');
    close(b.badMin, 91.0, 'bad min = good + 1');
    close(b.badMax, 165.0, 'bad max accommodates Vanilla 150 ms');
  }

  static function testSafeFramesFormat():Void
  {
    equal(AccuracyPresets.safeFramesDisplayFormat(10.0), '%v', 'safeFrames <= 10 has normal format');
    equal(AccuracyPresets.safeFramesDisplayFormat(10.1), '%v (Will not save)', 'safeFrames > 10 warns');
  }

  static function testGamepadDeadzoneClamp():Void
  {
    close(GamepadDeadzone.clamp(0.15), 0.15, 'default deadzone unchanged');
    close(GamepadDeadzone.clamp(0.0), GamepadDeadzone.MIN, 'zero clamps to minimum non-zero floor');
    close(GamepadDeadzone.clamp(-0.5), GamepadDeadzone.MIN, 'negative clamps to floor');
    close(GamepadDeadzone.clamp(1.5), GamepadDeadzone.MAX, 'above 1 clamps to max');
    close(GamepadDeadzone.clamp(Math.NaN), GamepadDeadzone.DEFAULT, 'NaN falls back to 0.15');
    close(GamepadDeadzone.clamp(Math.POSITIVE_INFINITY), GamepadDeadzone.DEFAULT, 'Infinity falls back to 0.15');
    close(GamepadDeadzone.clamp(0.236), 0.24, 'rounds to 2 decimal places');
  }

  static function testSourceWiring():Void
  {
    final prefs:String = sys.io.File.getContent(PREFS);
    final gameplay:String = sys.io.File.getContent(GAMEPLAY);
    final init:String = sys.io.File.getContent(INIT);
    final backup:String = sys.io.File.getContent(BACKUP);

    // perfectWindow must agree on 15.0 ms in both ClientPrefs and GameplaySettingsSubState.
    contains(prefs, 'public static var perfectWindow:Float = 15.0;', 'ClientPrefs.perfectWindow must stay 15.0');
    contains(prefs, 'public static var accuracyPreset:String = AccuracyPresets.PSYCH;',
      'ClientPrefs.accuracyPreset must default to Psych');
    contains(gameplay, 'AccuracyPresets.DEFAULT_PERFECT',
      'GameplaySettingsSubState Perfect! Hit Window must use AccuracyPresets.DEFAULT_PERFECT (15.0)');
    check(gameplay.indexOf('22.0') == -1, 'GameplaySettingsSubState must no longer hardcode 22.0 ms for perfectWindow');

    // Accuracy Preset row + timing recalculation.
    contains(gameplay, "'accuracyPreset',", 'GameplaySettingsSubState must expose accuracyPreset');
    contains(gameplay, 'Conductor.recalculateTimings();', 'Preset changes must recalculate Conductor timings');
    contains(gameplay, 'refreshTimingBoundsAndLabels();', 'Window edits must refresh neighbour bounds and labels');

    // Gamepad deadzone wiring across boot, options, and settings backup.
    contains(gameplay, "'gamepadDeadzone',", 'GameplaySettingsSubState must expose gamepadDeadzone');
    contains(prefs, 'FlxG.gamepads.globalDeadZone = gamepadDeadzone;',
      'ClientPrefs.applyGamepadDeadzone() must write FlxG.gamepads.globalDeadZone');
    contains(init, 'ClientPrefs.applyGamepadDeadzone();', 'InitState must apply gamepadDeadzone even on freshPrefs');
    contains(backup, 'ClientPrefs.applyGamepadDeadzone();', 'SettingsBackup import must re-apply gamepadDeadzone');
  }

  static function check(ok:Bool, label:String):Void
  {
    if (!ok) throw 'FAIL: $label';
  }

  static function equal<T>(actual:T, expected:T, label:String):Void
  {
    if (actual != expected) throw 'FAIL: $label (expected $expected, got $actual)';
  }

  static function close(actual:Float, expected:Float, label:String):Void
  {
    if (Math.isNaN(actual) || Math.abs(actual - expected) > 0.0001)
      throw 'FAIL: $label (expected $expected, got $actual)';
  }

  static function contains(haystack:String, needle:String, label:String):Void
  {
    if (haystack == null || haystack.indexOf(needle) == -1)
      throw 'FAIL: $label (missing "$needle")';
  }
}
