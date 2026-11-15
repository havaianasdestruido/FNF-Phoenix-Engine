package backend;

/**
 * Pure, Flixel-free accessibility math and palette helpers (§16).
 *
 * Covers all five accessibility preferences in `ClientPrefs`:
 *  - `noteColorblindPreset` (`None`, `Deuteranopia`, `Protanopia`, `Tritanopia`)
 *  - `forceLuminanceContrast` (monotonic per-lane relative luminance + crisp border)
 *  - `laneGlyphs` (ASCII-safe per-lane symbols `<`, `v`, `^`, `>` for `vcr.ttf`)
 *  - `highContrast` (menu and HUD contrast constants)
 *  - `visualBeatIndicator` (edge beat-pulse alpha/decay/thickness math)
 */
class Accessibility
{
  public static inline var PRESET_NONE:String = 'None';
  public static inline var PRESET_DEUTERANOPIA:String = 'Deuteranopia';
  public static inline var PRESET_PROTANOPIA:String = 'Protanopia';
  public static inline var PRESET_TRITANOPIA:String = 'Tritanopia';

  public static final COLORBLIND_PRESETS:Array<String> = [
    PRESET_NONE,
    PRESET_DEUTERANOPIA,
    PRESET_PROTANOPIA,
    PRESET_TRITANOPIA
  ];

  /** ASCII-only lane direction badges so `assets/fonts/vcr.ttf` renders every glyph. */
  public static final LANE_GLYPHS:Array<String> = ['<', 'v', '^', '>'];

  /** Monotonic WCAG relative-luminance targets across the four lanes (`0..1`). */
  public static final LANE_LUMINANCE_TARGETS:Array<Float> = [0.18, 0.39, 0.62, 0.86];

  public static inline var HIGHLIGHT_WHITE:Int = 0xFFFFFFFF;
  public static inline var MAX_OUTLINE_LUMINANCE:Float = 0.015;

  // High-contrast UI / HUD tuning constants.
  public static inline var MENU_BG_NORMAL:Int = 0xFFEA71FD;
  public static inline var MENU_BG_HIGH_CONTRAST:Int = 0xFF12121A;
  public static inline var MENU_DESC_ALPHA_NORMAL:Float = 0.6;
  public static inline var MENU_DESC_ALPHA_HIGH_CONTRAST:Float = 0.92;
  public static inline var MENU_UNSELECTED_ALPHA_NORMAL:Float = 0.6;
  public static inline var MENU_UNSELECTED_ALPHA_HIGH_CONTRAST:Float = 0.82;
  public static inline var STAGE_DIM_HIGH_CONTRAST_FLOOR:Float = 0.45;
  public static inline var HUD_BORDER_NORMAL:Float = 1.25;
  public static inline var HUD_BORDER_HIGH_CONTRAST:Float = 2.6;
  public static inline var HUD_STRIP_ALPHA_HIGH_CONTRAST:Float = 0.78;

  // Visual beat indicator tuning constants.
  public static inline var BEAT_ALPHA_DOWNBEAT:Float = 0.38;
  public static inline var BEAT_ALPHA_NORMAL:Float = 0.24;
  public static inline var BEAT_ALPHA_DOWNBEAT_REDUCED:Float = 0.22;
  public static inline var BEAT_ALPHA_NORMAL_REDUCED:Float = 0.14;
  public static inline var BEAT_EDGE_BASE_PX:Int = 6;
  public static inline var BEAT_EDGE_PEAK_PX:Int = 10;
  public static inline var BEAT_COLOR_DOWNBEAT:Int = 0xFFFFF3B0;
  public static inline var BEAT_COLOR_NORMAL:Int = 0xFFA8E6FF;

  // 4-lane [fill, highlight, outline] palettes tuned per CVD type.
  static final DEUTERANOPIA_LANES:Array<Array<Int>> = [
    [0xFF56B4E9, 0xFFFFFFFF, 0xFF133B5C], // Left: sky blue
    [0xFF0072B2, 0xFFFFFFFF, 0xFF002945], // Down: cobalt blue
    [0xFFF0E442, 0xFFFFFFFF, 0xFF5A5208], // Up: bright yellow
    [0xFFD55E00, 0xFFFFFFFF, 0xFF4F2100]  // Right: vermilion orange
  ];

  static final DEUTERANOPIA_PIXEL_LANES:Array<Array<Int>> = [
    [0xFF56B4E9, 0xFFFFFFFF, 0xFF1A3A54],
    [0xFF0072B2, 0xFFFFFFFF, 0xFF0D2B42],
    [0xFFF0E442, 0xFFFFFFFF, 0xFF574E12],
    [0xFFD55E00, 0xFFFFFFFF, 0xFF4D1F08]
  ];

  static final PROTANOPIA_LANES:Array<Array<Int>> = [
    [0xFF33BBEE, 0xFFFFFFFF, 0xFF0E4159], // Left: bright cyan
    [0xFF2E5BFF, 0xFFFFFFFF, 0xFF0E1F63], // Down: royal indigo
    [0xFFFFDD44, 0xFFFFFFFF, 0xFF5E4E0A], // Up: warm gold
    [0xFFEE8822, 0xFFFFFFFF, 0xFF572E06]  // Right: bright amber
  ];

  static final PROTANOPIA_PIXEL_LANES:Array<Array<Int>> = [
    [0xFF33BBEE, 0xFFFFFFFF, 0xFF144257],
    [0xFF2E5BFF, 0xFFFFFFFF, 0xFF12215E],
    [0xFFFFDD44, 0xFFFFFFFF, 0xFF594A10],
    [0xFFEE8822, 0xFFFFFFFF, 0xFF522D0A]
  ];

  static final TRITANOPIA_LANES:Array<Array<Int>> = [
    [0xFFEE3355, 0xFFFFFFFF, 0xFF570B19], // Left: crimson red
    [0xFF008899, 0xFFFFFFFF, 0xFF003238], // Down: deep teal
    [0xFF77EEDD, 0xFFFFFFFF, 0xFF1E5951], // Up: ice aqua
    [0xFFFF8899, 0xFFFFFFFF, 0xFF5E242D]  // Right: coral rose
  ];

  static final TRITANOPIA_PIXEL_LANES:Array<Array<Int>> = [
    [0xFFEE3355, 0xFFFFFFFF, 0xFF54101D],
    [0xFF008899, 0xFFFFFFFF, 0xFF08343B],
    [0xFF77EEDD, 0xFFFFFFFF, 0xFF22574F],
    [0xFFFF8899, 0xFFFFFFFF, 0xFF592830]
  ];

  /** Canonicalizes a colorblind preset string to one of `COLORBLIND_PRESETS`. */
  public static function normalizePreset(name:Null<String>):String
  {
    if (name == null) return PRESET_NONE;
    return switch (StringTools.trim(name).toLowerCase())
    {
      case 'deuteranopia', 'deutan': PRESET_DEUTERANOPIA;
      case 'protanopia', 'protan': PRESET_PROTANOPIA;
      case 'tritanopia', 'tritan': PRESET_TRITANOPIA;
      default: PRESET_NONE;
    };
  }

  /** Returns the ASCII glyph (`<`, `v`, `^`, `>`) for any non-negative or wrapped lane index. */
  public static function laneGlyph(lane:Int):String
  {
    final idx:Int = ((lane % 4) + 4) % 4;
    return LANE_GLYPHS[idx];
  }

  /**
   * Returns a fresh `[r, g, b]` lane triplet for a named colorblind preset,
   * or `null` when `preset` resolves to `None`.
   */
  public static function presetLaneColors(preset:Null<String>, lane:Int, isPixel:Bool):Null<Array<Int>>
  {
    final idx:Int = ((lane % 4) + 4) % 4;
    final table:Null<Array<Array<Int>>> = switch (normalizePreset(preset))
    {
      case PRESET_DEUTERANOPIA: isPixel ? DEUTERANOPIA_PIXEL_LANES : DEUTERANOPIA_LANES;
      case PRESET_PROTANOPIA: isPixel ? PROTANOPIA_PIXEL_LANES : PROTANOPIA_LANES;
      case PRESET_TRITANOPIA: isPixel ? TRITANOPIA_PIXEL_LANES : TRITANOPIA_LANES;
      default: null;
    };
    if (table == null) return null;
    final src:Array<Int> = table[idx];
    return [src[0], src[1], src[2]];
  }

  /**
   * Resolves `[r, g, b]` shader colors for a 4-lane note/strum without
   * mutating `baseColors`.
   */
  public static function resolveLaneRGB(
    lane:Int,
    isPixel:Bool,
    baseColors:Null<Array<Int>>,
    preset:Null<String>,
    forceLuminance:Bool
  ):Array<Int>
  {
    final normalized:String = normalizePreset(preset);
    var out:Null<Array<Int>> = presetLaneColors(normalized, lane, isPixel);
    if (out == null)
    {
      out = copyTriplet(baseColors);
    }

    if (forceLuminance)
    {
      final idx:Int = ((lane % 4) + 4) % 4;
      final targetLum:Float = LANE_LUMINANCE_TARGETS[idx];
      out[0] = adjustToLuminance(out[0], targetLum);
      out[1] = HIGHLIGHT_WHITE;
      out[2] = ensureDarkOutline(out[2], MAX_OUTLINE_LUMINANCE);
    }
    return out;
  }

  /**
   * Resolves `[r, g, b]` shader colors for a quant-based note subdivision
   * without mutating `baseColors`.
   */
  public static function resolveQuantRGB(
    quantIndex:Int,
    baseColors:Null<Array<Int>>,
    preset:Null<String>,
    forceLuminance:Bool
  ):Array<Int>
  {
    final normalized:String = normalizePreset(preset);
    final out:Array<Int> = copyTriplet(baseColors);

    if (normalized != PRESET_NONE)
    {
      out[0] = daltonize(out[0], normalized);
      out[2] = ensureDarkOutline(daltonize(out[2], normalized), 0.12);
    }

    if (forceLuminance)
    {
      final idx:Int = ((quantIndex % 4) + 4) % 4;
      final targetLum:Float = LANE_LUMINANCE_TARGETS[idx];
      out[0] = adjustToLuminance(out[0], targetLum);
      out[1] = HIGHLIGHT_WHITE;
      out[2] = ensureDarkOutline(out[2], MAX_OUTLINE_LUMINANCE);
    }
    return out;
  }

  /** WCAG 2.1 relative luminance (`0.0` black .. `1.0` white) for an `0xAARRGGBB` color. */
  public static function relativeLuminance(argb:Int):Float
  {
    final r:Float = linearizeChannel(((argb >> 16) & 0xFF) / 255.0);
    final g:Float = linearizeChannel(((argb >> 8) & 0xFF) / 255.0);
    final b:Float = linearizeChannel((argb & 0xFF) / 255.0);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /** WCAG 2.1 contrast ratio (`1.0` .. `21.0`) between two `0xAARRGGBB` colors. */
  public static function contrastRatio(c1:Int, c2:Int):Float
  {
    final l1:Float = relativeLuminance(c1);
    final l2:Float = relativeLuminance(c2);
    final lighter:Float = l1 > l2 ? l1 : l2;
    final darker:Float = l1 > l2 ? l2 : l1;
    return (lighter + 0.05) / (darker + 0.05);
  }

  /**
   * Shifts `argb` toward black or white along its hue until its WCAG relative
   * luminance matches `targetLuminance` (`0..1`), preserving alpha (`0xFF` if 0).
   */
  public static function adjustToLuminance(argb:Int, targetLuminance:Float):Int
  {
    final target:Float = clamp01(targetLuminance);
    final current:Float = relativeLuminance(argb);
    final alphaBits:Int = extractOpaqueAlpha(argb);
    if (Math.abs(current - target) <= 0.005)
      return alphaBits | (argb & 0x00FFFFFF);

    final r0:Float = ((argb >> 16) & 0xFF) / 255.0;
    final g0:Float = ((argb >> 8) & 0xFF) / 255.0;
    final b0:Float = (argb & 0xFF) / 255.0;

    final towardWhite:Bool = target > current;
    var lo:Float = 0.0;
    var hi:Float = 1.0;
    var best:Int = alphaBits | (argb & 0x00FFFFFF);

    for (_ in 0...18)
    {
      final t:Float = (lo + hi) * 0.5;
      final r:Float = towardWhite ? (r0 + (1.0 - r0) * t) : (r0 * (1.0 - t));
      final g:Float = towardWhite ? (g0 + (1.0 - g0) * t) : (g0 * (1.0 - t));
      final b:Float = towardWhite ? (b0 + (1.0 - b0) * t) : (b0 * (1.0 - t));
      best = packRGB(alphaBits, r, g, b);
      final lum:Float = relativeLuminance(best);
      if ((towardWhite && lum < target) || (!towardWhite && lum > target))
        lo = t;
      else
        hi = t;
    }
    return best;
  }

  /** Darkens `argb` only if its relative luminance exceeds `maxLuminance`. */
  public static function ensureDarkOutline(argb:Int, maxLuminance:Float):Int
  {
    if (relativeLuminance(argb) <= maxLuminance)
      return extractOpaqueAlpha(argb) | (argb & 0x00FFFFFF);
    return adjustToLuminance(argb, maxLuminance);
  }

  /**
   * Daltonizes an arbitrary RGB color for `Deuteranopia`, `Protanopia`, or
   * `Tritanopia` by projecting simulated cone-loss error onto preserved channels.
   */
  public static function daltonize(argb:Int, preset:String):Int
  {
    final normalized:String = normalizePreset(preset);
    if (normalized == PRESET_NONE)
      return argb;

    final alphaBits:Int = extractOpaqueAlpha(argb);
    final r:Float = ((argb >> 16) & 0xFF) / 255.0;
    final g:Float = ((argb >> 8) & 0xFF) / 255.0;
    final b:Float = (argb & 0xFF) / 255.0;

    // Viénot 1999 sRGB simulation approximations + error redistribution.
    var sr:Float = r;
    var sg:Float = g;
    var sb:Float = b;
    switch (normalized)
    {
      case PRESET_PROTANOPIA:
        sr = 0.56667 * r + 0.43333 * g;
        sg = 0.55833 * r + 0.44167 * g;
        sb = 0.24167 * g + 0.75833 * b;
      case PRESET_DEUTERANOPIA:
        sr = 0.625 * r + 0.375 * g;
        sg = 0.70 * r + 0.30 * g;
        sb = 0.30 * g + 0.70 * b;
      case PRESET_TRITANOPIA:
        sr = 0.95 * r + 0.05 * g;
        sg = 0.43333 * g + 0.56667 * b;
        sb = 0.475 * g + 0.525 * b;
      default:
    }

    final er:Float = r - sr;
    final eg:Float = g - sg;
    final eb:Float = b - sb;

    var outR:Float = r;
    var outG:Float = g;
    var outB:Float = b;
    if (normalized == PRESET_TRITANOPIA)
    {
      outR = clamp01(r + eb * 0.7 + eg * 0.35);
      outG = clamp01(g + eb * 0.5);
      outB = clamp01(b);
    }
    else
    {
      outR = clamp01(r);
      outG = clamp01(g + 0.7 * er);
      outB = clamp01(b + 0.7 * er + 0.5 * eg);
    }
    return packRGB(alphaBits, outR, outG, outB);
  }

  /** Effective stage-dim alpha when `highContrast` enforces a readability floor. */
  public static inline function effectiveStageDim(stageDim:Float, highContrast:Bool):Float
  {
    final clamped:Float = Math.isNaN(stageDim) ? 0.0 : clamp01(stageDim);
    return (highContrast && clamped < STAGE_DIM_HIGH_CONTRAST_FLOOR)
      ? STAGE_DIM_HIGH_CONTRAST_FLOOR
      : clamped;
  }

  /** Whether a beat or countdown tick should pulse the visual beat indicator. */
  public static inline function allowsBeatPulse(
    enabled:Bool,
    startedCountdown:Bool,
    paused:Bool,
    endingSong:Bool,
    isDead:Bool,
    transitioning:Bool,
    inCutscene:Bool,
    ffmpegMode:Bool,
    seeking:Bool
  ):Bool
  {
    return enabled
      && startedCountdown
      && !paused
      && !endingSong
      && !isDead
      && !transitioning
      && !inCutscene
      && !ffmpegMode
      && !seeking;
  }

  /** Peak alpha for a beat pulse (`isDownbeat` marks beat 0 of a measure / "GO!"). */
  public static inline function beatPeakAlpha(isDownbeat:Bool, reducedMotion:Bool):Float
  {
    if (reducedMotion)
      return isDownbeat ? BEAT_ALPHA_DOWNBEAT_REDUCED : BEAT_ALPHA_NORMAL_REDUCED;
    return isDownbeat ? BEAT_ALPHA_DOWNBEAT : BEAT_ALPHA_NORMAL;
  }

  /** Frame-rate-independent decay of the visual beat indicator over ~65% of a beat. */
  public static function decayBeatAlpha(
    currentAlpha:Float,
    elapsed:Float,
    crochetMs:Float,
    playbackRate:Float
  ):Float
  {
    if (!(currentAlpha > 0.0) || Math.isNaN(currentAlpha))
      return 0.0;
    if (!(elapsed > 0.0) || Math.isNaN(elapsed))
      return currentAlpha;

    final safeCrochetSec:Float = (crochetMs > 60.0 && !Math.isNaN(crochetMs))
      ? (crochetMs / 1000.0)
      : 0.5;
    final safeRate:Float = (playbackRate > 0.05 && !Math.isNaN(playbackRate))
      ? playbackRate
      : 1.0;
    final windowSec:Float = Math.max(0.10, (safeCrochetSec / safeRate) * 0.65);
    final next:Float = currentAlpha - (BEAT_ALPHA_DOWNBEAT / windowSec) * elapsed;
    return next > 0.002 ? next : 0.0;
  }

  /** Edge bar thickness in pixels (`reducedMotion` keeps thickness fixed so nothing expands). */
  public static function beatEdgeThickness(alpha:Float, peakAlpha:Float, reducedMotion:Bool):Int
  {
    if (reducedMotion || !(peakAlpha > 0.0) || !(alpha > 0.0))
      return BEAT_EDGE_BASE_PX;
    final ratio:Float = clamp01(alpha / peakAlpha);
    return BEAT_EDGE_BASE_PX + Math.round((BEAT_EDGE_PEAK_PX - BEAT_EDGE_BASE_PX) * ratio);
  }

  static function copyTriplet(src:Null<Array<Int>>):Array<Int>
  {
    if (src == null || src.length == 0)
      return [0xFFFFFFFF, 0xFFFFFFFF, 0xFF000000];
    final r:Int = src[0];
    final g:Int = src.length > 1 ? src[1] : 0xFFFFFFFF;
    final b:Int = src.length > 2 ? src[2] : 0xFF000000;
    return [r, g, b];
  }

  static inline function extractOpaqueAlpha(argb:Int):Int
  {
    final a:Int = (argb >>> 24) & 0xFF;
    return (a == 0 ? 0xFF : a) << 24;
  }

  static inline function packRGB(alphaBits:Int, r:Float, g:Float, b:Float):Int
  {
    final ri:Int = Math.round(clamp01(r) * 255.0) & 0xFF;
    final gi:Int = Math.round(clamp01(g) * 255.0) & 0xFF;
    final bi:Int = Math.round(clamp01(b) * 255.0) & 0xFF;
    return alphaBits | (ri << 16) | (gi << 8) | bi;
  }

  static inline function linearizeChannel(srgb:Float):Float
  {
    return srgb <= 0.04045 ? (srgb / 12.92) : Math.pow((srgb + 0.055) / 1.055, 2.4);
  }

  static inline function clamp01(v:Float):Float
  {
    return v < 0.0 ? 0.0 : (v > 1.0 ? 1.0 : v);
  }
}
