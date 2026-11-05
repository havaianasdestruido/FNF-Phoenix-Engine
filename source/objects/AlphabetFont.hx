package objects;

import backend.ClientPrefs;

/**
 * Static description of one font that can drive the alphabet renderer.
 *
 * Files are resolved through `Paths.font()`, so a mod can ship its own copy of the
 * file and override the bundled face without touching this table.
 */
typedef AlphabetFontDef =
{
  /** Stable id, used as the graphic cache prefix (`vcr`, `inconsolata`, ...). */
  key:String,
  /** Name shown in Options -> Visuals and UI, and stored in `ClientPrefs.alphabetFont`. */
  displayName:String,
  /** File inside `assets/fonts/` used for regular letters. */
  regular:String,
  /** File inside `assets/fonts/` used for bold letters. May equal `regular`. */
  bold:String,
  /** Pixel size the glyphs are rasterized at, regular text. */
  size:Int,
  /** Pixel size the glyphs are rasterized at, bold text. */
  boldSize:Int,
  /**
   * Cap height as a fraction of the em, read from the font's OS/2 table. Only used to keep
   * `size`/`boldSize` calibrated against the spritesheet they replace.
   */
  capHeight:Float,
  /** Distance between rows, in rasterized pixels, regular text. */
  lineHeight:Float,
  /** Distance between rows, in rasterized pixels, bold text. */
  boldLineHeight:Float,
  /** Fallback advance of a space, as a fraction of the pixel size. */
  spaceRatio:Float
}

/**
 * Model for the font driven alphabet renderer (`objects.Alphabet`).
 *
 * The alphabet used to be drawn only from the `images/alphabet` spritesheet. It can now be
 * drawn glyph by glyph out of a real font instead. This class holds everything about that
 * choice that does not need OpenFL/Flixel: the style and font resolution (both come from
 * `ClientPrefs`, so both are player toggleable in Options -> Visuals and UI), the sizes the
 * glyphs are rasterized at and the cache keys the rasterizer uses.
 *
 * It is deliberately free of OpenFL/Flixel imports so the resolution rules can be exercised
 * by `tests/haxe/run-alphabet-font.sh` on the Haxe interpreter.
 */
class AlphabetFont
{
  /** Alphabet drawn from a real font, glyph by glyph (default). */
  public static final STYLE_FONT:String = 'Font';

  /** Alphabet drawn from the classic `images/alphabet` spritesheet. */
  public static final STYLE_IMAGE:String = 'Image';

  /** Style used when the save file has no (or an unknown) value. */
  public static final DEFAULT_STYLE:String = STYLE_FONT;

  /** Font used when the save file has no (or an unknown) value. */
  public static final DEFAULT_FONT:String = 'VCR OSD Mono';

  /** Order the fonts are listed in the options menu. */
  public static var fontOrder:Array<String> = ['VCR OSD Mono', 'Inconsolata'];

  /**
   * Every font the renderer knows about, keyed by `displayName`.
   *
   * Sizes are calibrated against the spritesheet they replace: in `images/alphabet.xml` a
   * capital is ~53px tall and a bold capital ~68px, so `size`/`boldSize` are chosen so that
   * `size * capHeight` and `boldSize * capHeight` land on those heights (asserted by
   * `tests/haxe/AlphabetFontSpec.hx`). Row spacing stays near the spritesheet's
   * `Y_PER_ROW = 100`, raised where the font's own line box is taller.
   */
  public static var fonts:Map<String, AlphabetFontDef> = [
    'VCR OSD Mono' => {
      key: 'vcr',
      displayName: 'VCR OSD Mono',
      regular: 'vcr.ttf',
      bold: 'vcr.ttf', // no bold face bundled: OpenFL synthesizes it (see usesSyntheticBold)
      size: 72, // 72 * 0.732 = 53px caps, the spritesheet's uppercase height
      boldSize: 92, // 92 * 0.732 = 67px caps, the spritesheet's bold height
      capHeight: 0.732,
      lineHeight: 100,
      boldLineHeight: 110,
      spaceRatio: 0.586 // measured from the font: 1200/2048 em
    },
    'Inconsolata' => {
      key: 'inconsolata',
      displayName: 'Inconsolata',
      regular: 'inconsolata.ttf',
      bold: 'inconsolata-bold.ttf',
      size: 84, // 84 * 0.623 = 52px caps
      boldSize: 108, // 108 * 0.623 = 67px caps
      capHeight: 0.623,
      lineHeight: 112, // Inconsolata's line box is 1.049em, taller than VCR's 0.879em
      boldLineHeight: 142,
      spaceRatio: 0.5 // measured from the font: 500/1000 em
    }
  ];

  /**
   * Styles selectable in the options menu.
   */
  public static function styles():Array<String>
  {
    return [STYLE_FONT, STYLE_IMAGE];
  }

  /**
   * Font names selectable in the options menu, in `fontOrder` order.
   */
  public static function fontNames():Array<String>
  {
    var names:Array<String> = [];
    for (name in fontOrder)
      if (fonts.exists(name)) names.push(name);
    return names;
  }

  /**
   * Whether the alphabet should be drawn from the `images/alphabet` spritesheet.
   *
   * Anything that is not explicitly one of the image spellings falls back to the font
   * renderer, so an older or hand edited save file keeps working.
   *
   * @param style Value to inspect, defaults to `ClientPrefs.alphabetStyle`.
   */
  public static function usesImages(?style:String):Bool
  {
    if (style == null) style = ClientPrefs.alphabetStyle;
    if (style == null) return false;
    return switch (StringTools.trim(style.toLowerCase()))
    {
      case 'image' | 'images' | 'spritesheet' | 'sprite sheet' | 'atlas' | 'classic' | 'legacy': true;
      default: false;
    }
  }

  /**
   * Font definition for a name, falling back to `DEFAULT_FONT` for unknown values.
   *
   * @param name `displayName`, `key` or asset file of the wanted font; defaults to
   *             `ClientPrefs.alphabetFont`.
   */
  public static function resolveFont(?name:String):AlphabetFontDef
  {
    if (name == null) name = ClientPrefs.alphabetFont;
    if (name != null)
    {
      var wanted:String = StringTools.trim(name.toLowerCase());
      if (wanted.length > 0)
      {
        if (fonts.exists(wanted)) return fonts.get(wanted);
        for (def in fonts)
        {
          if (def.displayName.toLowerCase() == wanted || def.key == wanted || matchesFile(def.regular, wanted)
            || matchesFile(def.bold, wanted)) return def;
        }
      }
    }
    return fonts.get(DEFAULT_FONT);
  }

  /** `true` when `name` is `file`, or `file` without its extension (both lowercased). */
  static function matchesFile(file:String, name:String):Bool
  {
    if (file == null) return false;
    var lowered:String = file.toLowerCase();
    if (lowered == name) return true;
    var dot:Int = lowered.lastIndexOf('.');
    return dot > 0 && lowered.substr(0, dot) == name;
  }

  /** Font definition currently selected by the player. */
  public static function currentFont():AlphabetFontDef
  {
    return resolveFont(ClientPrefs.alphabetFont);
  }

  /** Whether the currently selected style draws from the spritesheet. */
  public static function currentUsesImages():Bool
  {
    return usesImages(ClientPrefs.alphabetStyle);
  }

  /** Pixel size the glyphs of `def` are rasterized at. */
  public static function sizeFor(def:AlphabetFontDef, bold:Bool):Int
  {
    if (def == null) def = fonts.get(DEFAULT_FONT);
    return bold ? def.boldSize : def.size;
  }

  /** Distance between rows, in rasterized pixels, for the glyphs of `def`. */
  public static function lineHeightFor(def:AlphabetFontDef, bold:Bool):Float
  {
    if (def == null) def = fonts.get(DEFAULT_FONT);
    return bold ? def.boldLineHeight : def.lineHeight;
  }

  /**
   * Fallback advance of a space, in rasterized pixels.
   *
   * The renderer measures the real advance and only uses this when the font cannot be
   * measured (headless target, stripped asset, ...).
   */
  public static function spaceWidthFor(def:AlphabetFontDef, bold:Bool):Float
  {
    if (def == null) def = fonts.get(DEFAULT_FONT);
    return sizeFor(def, bold) * def.spaceRatio;
  }

  /** `true` when bold letters must be synthesized, because the font has no bold file. */
  public static function usesSyntheticBold(def:AlphabetFontDef, bold:Bool):Bool
  {
    if (def == null) def = fonts.get(DEFAULT_FONT);
    return bold && def.bold == def.regular;
  }

  /** `assets/fonts/` file to use for `def`, honoring the bundled bold face when present. */
  public static function assetFile(def:AlphabetFontDef, bold:Bool):String
  {
    if (def == null) def = fonts.get(DEFAULT_FONT);
    return bold ? def.bold : def.regular;
  }

  /**
   * Whether a character can be drawn by the font renderer.
   *
   * Unlike the spritesheet, which only carries the glyphs listed in
   * `AlphaCharacter.allLetters`, a font renders any printable character.
   */
  public static function supports(char:String):Bool
  {
    if (char == null || char.length == 0) return false;
    var code:Int = char.charCodeAt(0);
    return code >= 32 && code != 127;
  }

  /** Cache safe name of a single character glyph (`u0041` for `A`). */
  public static function glyphName(char:String):String
  {
    if (char == null || char.length == 0) return 'empty';
    return 'u' + StringTools.hex(char.charCodeAt(0), 4).toLowerCase();
  }

  /**
   * Graphic cache key of one glyph. Two glyphs share a key only when font, weight, size and
   * character all match.
   */
  public static function cacheKey(def:AlphabetFontDef, char:String, bold:Bool):String
  {
    if (def == null) def = fonts.get(DEFAULT_FONT);
    return 'alphabet-font/' + def.key + '/' + (bold ? 'bold' : 'regular') + '/' + sizeFor(def, bold) + '/' + glyphName(char);
  }

  /** Cache key of the per font/weight metrics the renderer measures once. */
  public static function metricsKey(def:AlphabetFontDef, bold:Bool, metric:String):String
  {
    if (def == null) def = fonts.get(DEFAULT_FONT);
    return 'alphabet-font/' + def.key + '/' + (bold ? 'bold' : 'regular') + '/' + sizeFor(def, bold) + '/' + metric;
  }
}
