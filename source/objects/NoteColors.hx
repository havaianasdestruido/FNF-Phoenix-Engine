package objects;

import backend.Accessibility;
import backend.ClientPrefs;
import flixel.util.FlxColor;

/**
 * Shared note colour helpers used by `Note`, `StrumNote`, `NoteHelpers`,
 * `CoolUtil`, and the chart editor.
 *
 * Centralizing palette lookup here allows `ClientPrefs.noteColorblindPreset`
 * and `ClientPrefs.forceLuminanceContrast` to transform note, receptor,
 * sustain, splash, and chart-grid RGB colours without overwriting the
 * player's custom `arrowRGB` / `arrowRGBPixel` / `quantRGB` arrays on disk.
 */
class NoteColors
{
  static final DEFAULT_LANE:Array<FlxColor> = [0xFFFFFFFF, 0xFFFFFFFF, 0xFF000000];

  static var _cachedPreset:String = '';
  static var _cachedLuminance:Bool = false;
  static var _cachedRevision:Int = -1;
  static var _revision:Int = 0;

  static var _laneNormalCache:Array<Array<FlxColor>> = null;
  static var _lanePixelCache:Array<Array<FlxColor>> = null;
  static var _quantCache:Array<Array<FlxColor>> = null;

  /** Marks cached accessibility-transformed palettes dirty after custom RGB edits. */
  public static inline function invalidateCache():Void
  {
    _revision++;
  }

  /**
   * Resolves the `[r, g, b]` shader palette for a 4-lane note or strum receptor,
   * applying `noteColorblindPreset` and `forceLuminanceContrast` when active.
   */
  public static function laneRGB(noteData:Int, isPixelStage:Bool):Array<FlxColor>
  {
    final baseTable:Array<Array<FlxColor>> = isPixelStage ? ClientPrefs.arrowRGBPixel : ClientPrefs.arrowRGB;
    if (baseTable == null || baseTable.length == 0)
      return DEFAULT_LANE;

    final idx:Int = ((noteData % baseTable.length) + baseTable.length) % baseTable.length;
    final preset:String = Accessibility.normalizePreset(ClientPrefs.noteColorblindPreset);
    final forceLum:Bool = ClientPrefs.forceLuminanceContrast;

    if (preset == Accessibility.PRESET_NONE && !forceLum)
      return baseTable[idx];

    ensureCache(preset, forceLum);
    final cache:Array<Array<FlxColor>> = isPixelStage ? _lanePixelCache : _laneNormalCache;
    if (cache != null && idx >= 0 && idx < cache.length)
      return cache[idx];
    return baseTable[idx];
  }

  /**
   * Resolves the `[r, g, b]` shader palette for a quant subdivision index,
   * applying `noteColorblindPreset` and `forceLuminanceContrast` when active.
   */
  public static function quantRGB(quantIndex:Int):Array<FlxColor>
  {
    final baseTable:Array<Array<FlxColor>> = ClientPrefs.quantRGB;
    if (baseTable == null || baseTable.length == 0)
      return DEFAULT_LANE;

    final idx:Int = quantIndex < 0 ? 0 : (quantIndex >= baseTable.length ? baseTable.length - 1 : quantIndex);
    final preset:String = Accessibility.normalizePreset(ClientPrefs.noteColorblindPreset);
    final forceLum:Bool = ClientPrefs.forceLuminanceContrast;

    if (preset == Accessibility.PRESET_NONE && !forceLum)
      return baseTable[idx];

    ensureCache(preset, forceLum);
    if (_quantCache != null && idx >= 0 && idx < _quantCache.length)
      return _quantCache[idx];
    return baseTable[idx];
  }

  /**
   * Copies `(r, g, b)` from a `StrumNote` onto a note shader, leaving pixels
   * untouched if either shader is missing or disabled.
   */
  public static function syncRGBFromStrum(target:Note, myNote:StrumNote):Void
  {
    if (target == null || myNote == null) return;
    if (target.rgbShader == null || myNote.rgbShader == null) return;
    if (!target.rgbShader.enabled || !myNote.rgbShader.enabled) return;

    target.rgbShader.r = myNote.rgbShader.r;
    target.rgbShader.g = myNote.rgbShader.g;
    target.rgbShader.b = myNote.rgbShader.b;
  }

  static function ensureCache(preset:String, forceLum:Bool):Void
  {
    if (_cachedRevision == _revision && _cachedPreset == preset && _cachedLuminance == forceLum && _laneNormalCache != null)
      return;

    _cachedRevision = _revision;
    _cachedPreset = preset;
    _cachedLuminance = forceLum;

    _laneNormalCache = buildLaneCache(ClientPrefs.arrowRGB, false, preset, forceLum);
    _lanePixelCache = buildLaneCache(ClientPrefs.arrowRGBPixel, true, preset, forceLum);
    _quantCache = buildQuantCache(ClientPrefs.quantRGB, preset, forceLum);
  }

  static function buildLaneCache(
    src:Array<Array<FlxColor>>,
    isPixel:Bool,
    preset:String,
    forceLum:Bool
  ):Array<Array<FlxColor>>
  {
    final out:Array<Array<FlxColor>> = [];
    if (src == null) return out;
    for (i in 0...src.length)
    {
      final entry:Array<FlxColor> = src[i];
      final raw:Array<Int> = entry != null ? [cast entry[0], cast entry[1], cast entry[2]] : null;
      final resolved:Array<Int> = Accessibility.resolveLaneRGB(i, isPixel, raw, preset, forceLum);
      out.push([resolved[0], resolved[1], resolved[2]]);
    }
    return out;
  }

  static function buildQuantCache(
    src:Array<Array<FlxColor>>,
    preset:String,
    forceLum:Bool
  ):Array<Array<FlxColor>>
  {
    final out:Array<Array<FlxColor>> = [];
    if (src == null) return out;
    for (i in 0...src.length)
    {
      final entry:Array<FlxColor> = src[i];
      final raw:Array<Int> = entry != null ? [cast entry[0], cast entry[1], cast entry[2]] : null;
      final resolved:Array<Int> = Accessibility.resolveQuantRGB(i, raw, preset, forceLum);
      out.push([resolved[0], resolved[1], resolved[2]]);
    }
    return out;
  }
}
