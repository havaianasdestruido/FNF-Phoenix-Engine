package objects;

import backend.Paths;
import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import objects.AlphabetFont.AlphabetFontDef;
import openfl.Assets;
import openfl.display.BitmapData;
import openfl.geom.Matrix;
import openfl.text.TextField;
import openfl.text.TextFieldAutoSize;
import openfl.text.TextFormat;
import openfl.utils.AssetType;

/**
 * Rasterizes alphabet glyphs out of a real font.
 *
 * Every glyph is drawn once into its own transparent bitmap, at the pixel size given by
 * `AlphabetFont.sizeFor()`, and cached as an `FlxGraphic` under `AlphabetFont.cacheKey()`.
 * All glyphs of one font/weight share the same box height, so a row of letters lands on a
 * common baseline without any per character offset tables (which is what the spritesheet
 * needed `AlphaCharacter.allLetters` for).
 *
 * If a font file cannot be loaded — stripped asset, mod overriding it with junk, headless
 * target — every entry point here returns a neutral value and `AlphaCharacter` falls back
 * to the classic spritesheet instead of drawing nothing.
 */
class AlphabetFontRenderer
{
  /** Text measured once per font/weight to size the shared glyph box. */
  static final PROBE:String = 'Hgjqpy|!?(){}[]0123456789ÄÁç';

  /** First and last printable ASCII code, used by `warmUp()`. */
  static final WARM_FROM:Int = 33;

  /** @see WARM_FROM */
  static final WARM_TO:Int = 126;

  static var glyphs:Map<String, FlxGraphic> = new Map();
  static var boxes:Map<String, Int> = new Map();
  static var spaces:Map<String, Float> = new Map();
  static var families:Map<String, String> = new Map();
  static var unusable:Map<String, Bool> = new Map();

  static var field:TextField = null;

  /**
   * Drops every cached glyph and metric. Call it when the alphabet font changes so the old
   * faces stop holding VRAM.
   *
   * Glyphs still held by a letter are handed back to Flixel instead of being destroyed here:
   * `persist = false` makes the cache drop them as soon as the last letter lets go, so a
   * glyph can never be destroyed under a sprite that is still drawing it.
   */
  public static function clearCache():Void
  {
    for (graphic in glyphs)
    {
      if (graphic == null || graphic.isDestroyed) continue;
      if (graphic.useCount <= 0) FlxG.bitmap.remove(graphic);
      else graphic.persist = false;
    }
    glyphs = new Map();
    boxes = new Map();
    spaces = new Map();
    families = new Map();
    unusable = new Map();
  }

  /**
   * Rasterizes the printable ASCII range for both weights, so the first menu that asks for
   * letters does not pay for it. Bounded work: 94 characters per weight.
   */
  public static function warmUp(?def:AlphabetFontDef):Void
  {
    if (def == null) def = AlphabetFont.currentFont();
    if (familyName(def, false) == null || familyName(def, true) == null) return;

    for (bold in [false, true])
      for (code in WARM_FROM...WARM_TO + 1)
        glyph(def, String.fromCharCode(code), bold);
  }

  /**
   * Cached graphic holding `char`, drawn with `def`. Returns `null` when the font cannot be
   * used, which tells the caller to fall back to the spritesheet.
   */
  public static function glyph(def:AlphabetFontDef, char:String, bold:Bool):FlxGraphic
  {
    if (!AlphabetFont.supports(char)) return null;

    var key:String = AlphabetFont.cacheKey(def, char, bold);
    if (glyphs.exists(key)) return glyphs.get(key);
    if (!prepare(def, bold)) return null;

    var boxH:Int = boxHeight(def, bold);
    if (boxH <= 0) return null;

    var padH:Int = padding(def, bold, false);
    var padV:Int = padding(def, bold, true);
    field.text = char;
    var width:Int = Math.ceil(field.textWidth) + padH * 2;
    if (width < 1) width = 1;

    var bitmap:BitmapData = new BitmapData(width, boxH, true, 0x00000000);
    bitmap.draw(field, new Matrix(1, 0, 0, 1, padH, padV));

    var graphic:FlxGraphic = FlxG.bitmap.add(bitmap, false, key);
    if (graphic == null) return null;
    // A glyph outlives the letters using it (recycled letters, state changes), exactly like
    // the alphabet spritesheet it replaces: without this Flixel destroys it as soon as the
    // last letter is released, leaving a dead graphic in the cache.
    graphic.persist = true;
    glyphs.set(key, graphic);
    return graphic;
  }

  /**
   * Advance of a space, in rasterized pixels, for `def`.
   *
   * Spaces never become a glyph: `Alphabet` just moves the pen by this much.
   */
  public static function spaceAdvance(def:AlphabetFontDef, bold:Bool):Float
  {
    var key:String = AlphabetFont.metricsKey(def, bold, 'space');
    if (spaces.exists(key)) return spaces.get(key);

    var width:Float = 0;
    if (prepare(def, bold))
    {
      field.text = ' ';
      width = field.textWidth;
      if (width <= 0)
      {
        // Some targets trim a lone trailing space: measure it between two letters instead.
        field.text = 'n n';
        var withSpace:Float = field.textWidth;
        field.text = 'nn';
        width = withSpace - field.textWidth;
      }
    }
    if (width <= 0) width = AlphabetFont.spaceWidthFor(def, bold);

    spaces.set(key, width);
    return width;
  }

  /** Height of the shared glyph box of `def`, in rasterized pixels. */
  public static function boxHeight(def:AlphabetFontDef, bold:Bool):Int
  {
    var key:String = AlphabetFont.metricsKey(def, bold, 'box');
    if (boxes.exists(key)) return boxes.get(key);

    var height:Int = 0;
    if (prepare(def, bold))
    {
      field.text = PROBE;
      height = Math.ceil(field.textHeight) + padding(def, bold, true) * 2;
    }
    boxes.set(key, height);
    return height;
  }

  /** Family name of the face behind `def`, or `null` when it cannot be loaded. */
  public static function familyName(def:AlphabetFontDef, bold:Bool):String
  {
    if (def == null) def = AlphabetFont.resolveFont();
    var file:String = AlphabetFont.assetFile(def, bold);
    if (families.exists(file)) return families.get(file);
    if (unusable.exists(file)) return null;

    var name:String = null;
    try
    {
      var path:String = Paths.font(file);
      if (Assets.exists(path, AssetType.FONT))
      {
        var font = Assets.getFont(path);
        if (font != null) name = font.fontName;
      }
    }
    catch (e)
      name = null;

    if (name == null || name.length == 0)
    {
      if (bold && def.bold != def.regular) return familyName(def, false); // missing bold face
      unusable.set(file, true);
      FlxG.log.warn('AlphabetFontRenderer: could not load font "$file", falling back to the alphabet spritesheet.');
      return null;
    }
    families.set(file, name);
    return name;
  }

  /**
   * Points the shared `TextField` at the face and size of `def`.
   *
   * @return `false` when the font is unusable, so callers can bail out.
   */
  static function prepare(def:AlphabetFontDef, bold:Bool):Bool
  {
    var name:String = familyName(def, bold);
    if (name == null) return false;

    if (field == null)
    {
      field = new TextField();
      field.selectable = false;
      field.multiline = false;
      field.wordWrap = false;
      field.autoSize = TextFieldAutoSize.LEFT;
      field.sharpness = 100;
      field.embedFonts = true;
    }
    field.defaultTextFormat = new TextFormat(name, AlphabetFont.sizeFor(def, bold), 0xFFFFFF, AlphabetFont.usesSyntheticBold(def, bold));
    field.text = '';
    return true;
  }

  /**
   * Padding around every glyph, in rasterized pixels.
   *
   * Room for accents and for the half pixel bleed of filtering when the letters get scaled.
   *
   * @param vertical `true` for the top/bottom padding, `false` for left/right.
   */
  static function padding(def:AlphabetFontDef, bold:Bool, vertical:Bool):Int
  {
    var size:Int = AlphabetFont.sizeFor(def, bold);
    var pad:Int = Math.round(size * (vertical ? 0.12 : 0.05));
    return pad < 2 ? 2 : pad;
  }
}
