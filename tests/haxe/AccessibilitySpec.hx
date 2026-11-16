import backend.Accessibility;

/**
 * Exercises `backend.Accessibility` (§16) and verifies that every §16, §21.4,
 * and §22.7 preference has a live reader AND an `Option` row in `source/options/`
 * without disturbing `StageDimSpec` or `PhoenixURI` deep-link contracts.
 *
 * Run with:
 *
 *     bash tests/haxe/run-accessibility.sh
 */
class AccessibilitySpec
{
  static function main():Void
  {
    testColorblindPresets();
    testLuminanceContrast();
    testQuantResolution();
    testLaneGlyphsAreAscii();
    testHighContrastAndBeatMath();
    testOptionRowsAndPlayStateOrdering();

    Sys.println('AccessibilitySpec: PASS');
  }

  static function testColorblindPresets():Void
  {
    equal(Accessibility.COLORBLIND_PRESETS.length, 4, 'four colorblind preset choices');
    equal(Accessibility.normalizePreset(null), Accessibility.PRESET_NONE, 'null -> None');
    equal(Accessibility.normalizePreset('deuteranopia'), Accessibility.PRESET_DEUTERANOPIA, 'case-insensitive Deuteranopia');
    equal(Accessibility.normalizePreset('PROTAN'), Accessibility.PRESET_PROTANOPIA, 'Protan alias');
    equal(Accessibility.normalizePreset('tritanopia'), Accessibility.PRESET_TRITANOPIA, 'Tritanopia');
    equal(Accessibility.normalizePreset('unknown'), Accessibility.PRESET_NONE, 'unknown -> None');

    check(Accessibility.presetLaneColors(Accessibility.PRESET_NONE, 0, false) == null, 'None leaves user colors intact');

    final userLane:Array<Int> = [0xFFC24B99, 0xFFFFFFFF, 0xFF3C1F56];
    final passthrough:Array<Int> = Accessibility.resolveLaneRGB(0, false, userLane, Accessibility.PRESET_NONE, false);
    equal(passthrough[0], userLane[0], 'None + !forceLuminance keeps r');
    equal(passthrough[1], userLane[1], 'None + !forceLuminance keeps g');
    equal(passthrough[2], userLane[2], 'None + !forceLuminance keeps b');

    for (preset in [
      Accessibility.PRESET_DEUTERANOPIA,
      Accessibility.PRESET_PROTANOPIA,
      Accessibility.PRESET_TRITANOPIA
    ])
    {
      for (isPixel in [false, true])
      {
        final seen:Array<Int> = [];
        for (lane in 0...4)
        {
          final c:Array<Int> = Accessibility.resolveLaneRGB(lane, isPixel, userLane, preset, false);
          check(c.length == 3, '$preset lane $lane returns 3 channels');
          check(seen.indexOf(c[0]) == -1, '$preset gives distinct fill color per lane ($lane)');
          seen.push(c[0]);
        }
      }
    }

    // Input array must never be mutated in place.
    equal(userLane[0], 0xFFC24B99, 'user arrowRGB entry was not mutated');
  }

  static function testLuminanceContrast():Void
  {
    close(Accessibility.relativeLuminance(0xFF000000), 0.0, 'black luminance is 0');
    close(Accessibility.relativeLuminance(0xFFFFFFFF), 1.0, 'white luminance is 1');
    close(Accessibility.contrastRatio(0xFFFFFFFF, 0xFF000000), 21.0, 'white/black contrast is 21:1');

    // Worst-case input: all four lanes configured to the exact same mid-grey.
    final identicalGrey:Array<Int> = [0xFF808080, 0xFF999999, 0xFF777777];
    var prevLum:Float = -1.0;
    for (lane in 0...4)
    {
      final resolved:Array<Int> = Accessibility.resolveLaneRGB(
        lane,
        false,
        identicalGrey,
        Accessibility.PRESET_NONE,
        true
      );
      final fillLum:Float = Accessibility.relativeLuminance(resolved[0]);
      final outlineLum:Float = Accessibility.relativeLuminance(resolved[2]);

      check(Math.abs(fillLum - Accessibility.LANE_LUMINANCE_TARGETS[lane]) <= 0.03,
        'lane $lane hits target luminance band (got $fillLum)');
      if (prevLum >= 0.0)
        check(fillLum - prevLum >= 0.15, 'adjacent lanes stay clearly separated in greyscale ($prevLum -> $fillLum)');
      prevLum = fillLum;

      equal(resolved[1], Accessibility.HIGHLIGHT_WHITE, 'lane $lane inner highlight is crisp white');
      check(outlineLum <= Accessibility.MAX_OUTLINE_LUMINANCE + 0.01,
        'lane $lane outline is darkened for contrast (got $outlineLum)');
      check(Accessibility.contrastRatio(resolved[0], resolved[2]) >= 3.0,
        'lane $lane fill vs outline contrast >= 3:1');
    }
  }

  static function testQuantResolution():Void
  {
    final red4th:Array<Int> = [0xFFF9393F, 0xFFFFFFFF, 0xFF651038];
    final daltonized:Array<Int> = Accessibility.resolveQuantRGB(
      0,
      red4th,
      Accessibility.PRESET_PROTANOPIA,
      true
    );
    check(daltonized[0] != red4th[0], 'Protanopia + luminance adjusts quant fill');
    equal(daltonized[1], Accessibility.HIGHLIGHT_WHITE, 'quant highlight stays white');
    check(Accessibility.relativeLuminance(daltonized[2]) <= Accessibility.MAX_OUTLINE_LUMINANCE + 0.01,
      'quant outline stays dark');
    equal(red4th[0], 0xFFF9393F, 'quant base array was not mutated');
  }

  static function testLaneGlyphsAreAscii():Void
  {
    equal(Accessibility.laneGlyph(0), '<', 'left glyph');
    equal(Accessibility.laneGlyph(1), 'v', 'down glyph');
    equal(Accessibility.laneGlyph(2), '^', 'up glyph');
    equal(Accessibility.laneGlyph(3), '>', 'right glyph');
    equal(Accessibility.laneGlyph(4), '<', 'opponent/player wrapping');
    equal(Accessibility.laneGlyph(7), '>', '8-strum wrapping');

    for (g in Accessibility.LANE_GLYPHS)
    {
      check(g.length > 0, 'non-empty glyph');
      for (i in 0...g.length)
      {
        final code:Int = g.charCodeAt(i);
        check(code >= 33 && code <= 126, 'glyph "$g" must stay printable ASCII for vcr.ttf');
      }
    }
  }

  static function testHighContrastAndBeatMath():Void
  {
    close(Accessibility.effectiveStageDim(0.0, false), 0.0, 'stageDim 0 stays 0 without highContrast');
    close(Accessibility.effectiveStageDim(0.0, true), Accessibility.STAGE_DIM_HIGH_CONTRAST_FLOOR,
      'highContrast enforces minimum stage dim floor');
    close(Accessibility.effectiveStageDim(0.8, true), 0.8,
      'highContrast keeps stronger user stageDim untouched');

    check(Accessibility.allowsBeatPulse(true, true, false, false, false, false, false, false, false),
      'normal active beat pulses');
    check(!Accessibility.allowsBeatPulse(false, true, false, false, false, false, false, false, false),
      'disabled visualBeatIndicator suppresses pulse');
    check(!Accessibility.allowsBeatPulse(true, true, true, false, false, false, false, false, false),
      'paused game suppresses pulse');
    check(!Accessibility.allowsBeatPulse(true, true, false, false, false, false, false, true, false),
      'ffmpeg render suppresses pulse');
    check(!Accessibility.allowsBeatPulse(true, true, false, false, false, false, false, false, true),
      'seeking suppresses pulse');

    final normalPeak:Float = Accessibility.beatPeakAlpha(true, false);
    final reducedPeak:Float = Accessibility.beatPeakAlpha(true, true);
    check(reducedPeak < normalPeak, 'reducedMotion lowers beat pulse intensity');
    equal(Accessibility.beatEdgeThickness(reducedPeak, reducedPeak, true), Accessibility.BEAT_EDGE_BASE_PX,
      'reducedMotion keeps edge bar thickness fixed');
    equal(Accessibility.beatEdgeThickness(normalPeak, normalPeak, false), Accessibility.BEAT_EDGE_PEAK_PX,
      'normal mode expands edge bar at peak');

    // At 120 BPM (crochet = 500 ms), pulse decays cleanly to 0 within 0.4 s.
    var alpha:Float = normalPeak;
    for (_ in 0...24)
      alpha = Accessibility.decayBeatAlpha(alpha, 1.0 / 60.0, 500.0, 1.0);
    close(alpha, 0.0, 'beat pulse finishes decaying before next beat');
  }

  static function testOptionRowsAndPlayStateOrdering():Void
  {
    final visuals:String = sys.io.File.getContent('source/options/VisualsUISubState.hx');
    final access:String = sys.io.File.getContent('source/options/AccessibilitySubState.hx');
    final gameplay:String = sys.io.File.getContent('source/options/GameplaySettingsSubState.hx');
    final misc:String = sys.io.File.getContent('source/options/MiscSettingsSubState.hx');
    final audio:String = sys.io.File.getContent('source/options/AudioSettingsSubState.hx');
    final helpers:String = sys.io.File.getContent('source/options/helpers/OptionsMenuHelpers.hx');
    final optionsState:String = sys.io.File.getContent('source/options/OptionsState.hx');
    final playState:String = sys.io.File.getContent('source/play/PlayState.hx');
    final phoenixUri:String = sys.io.File.getContent('source/backend/deeplink/PhoenixURI.hx');

    final allMenus:String = visuals + '\n' + access + '\n' + gameplay + '\n' + misc + '\n' + audio + '\n' + helpers;

    // Every §16, §21.4, and §22.7 preference must be bound by an Option row.
    for (pref in [
      'noteColorblindPreset',
      'laneGlyphs',
      'forceLuminanceContrast',
      'highContrast',
      'visualBeatIndicator',
      'reducedMotion',
      'dialogueSpeedMult',
      'dimDialogueBackground',
      'instantDialogueAdvance',
      'hideDialogueBox',
      'safeMode',
      'showPhotosensitivityWarning',
      'disableAprilFools',
      'gamepadDeadzone',
      'accuracyPreset',
      'masterMuted'
    ])
    {
      contains(allMenus, '\'' + pref + '\'', 'Option row missing for preference "$pref"');
    }

    // OptionsState must expose the Accessibility category without changing PhoenixURI v1 MENU_NAMES.
    contains(optionsState, "'Accessibility'", 'OptionsState must list Accessibility');
    contains(optionsState, 'new options.AccessibilitySubState()', 'OptionsState must open AccessibilitySubState');
    check(phoenixUri.indexOf('"accessibility"') == -1, 'PhoenixURI v1 MENU_NAMES contract must remain unchanged');

    // PlayStateAccessibility must set up and sync BEFORE PlayStateStageDim so stageDimOverlay stays top-most.
    final setupAcc:Int = playState.indexOf('PlayStateAccessibility.setup(this);');
    final setupDim:Int = playState.indexOf('PlayStateStageDim.setup(this);');
    check(setupAcc != -1 && setupDim != -1 && setupAcc < setupDim,
      'PlayStateAccessibility.setup must run before PlayStateStageDim.setup');

    final syncAcc:Int = playState.indexOf('PlayStateAccessibility.sync(this, elapsed);');
    final syncDim:Int = playState.indexOf('PlayStateStageDim.sync(this);');
    check(syncAcc != -1 && syncDim != -1 && syncAcc < syncDim,
      'PlayStateAccessibility.sync must run before PlayStateStageDim.sync');

    // NoteColors routing across gameplay and editor sites.
    for (path in [
      'source/objects/NoteHelpers.hx',
      'source/objects/StrumNote.hx',
      'source/backend/CoolUtil.hx',
      'source/editors/charting/ChartingUIGrid.hx',
      'source/editors/charting/SelectionNote.hx'
    ])
    {
      final content:String = sys.io.File.getContent(path);
      contains(content, 'NoteColors.', '$path must resolve note RGB via NoteColors');
    }
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
    if (Math.isNaN(actual) || Math.abs(actual - expected) > 0.001)
      throw 'FAIL: $label (expected $expected, got $actual)';
  }

  static function contains(haystack:String, needle:String, label:String):Void
  {
    if (haystack == null || haystack.indexOf(needle) == -1)
      throw 'FAIL: $label (missing "$needle")';
  }
}
