package objects;

import backend.Paths;
import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.frames.FlxFrame;
import flixel.math.FlxRect;
import objects.AlphabetFont.AlphabetFontDef;
import openfl.Assets;
import openfl.display.BitmapData;
import openfl.geom.Matrix;
import openfl.text.TextField;
import openfl.text.TextFieldAutoSize;
import openfl.text.TextFormat;
import openfl.utils.AssetType;

/** One dynamically packed texture and the frames stored in it. */
typedef AlphabetAtlasPage =
{
  graphic:FlxGraphic,
  frames:FlxAtlasFrames,
  x:Float,
  y:Float,
  rowHeight:Float
}

/**
 * Rasterizes alphabet glyphs out of a real font.
 *
 * Glyphs are drawn once into shared atlas pages at the pixel size given by
 * `AlphabetFont.sizeFor()`. Every letter then uses a frame of its page instead of owning a
 * separate texture. This is important for menus with many options: Flixel can batch the
 * whole list into a few draws rather than switching textures for every character.
 *
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

  /** A power-of-two page works on the low-end mobile GPUs the engine targets. */
  static final ATLAS_SIZE:Int = 1024;

  /** Transparent separation prevents neighbouring glyphs bleeding when filtered. */
  static final ATLAS_GAP:Int = 2;

  static var glyphs:Map<String, FlxFrame> = new Map();
  static var pages:Array<AlphabetAtlasPage> = [];
  static var activePages:Map<String, AlphabetAtlasPage> = new Map();
  static var boxes:Map<String, Int> = new Map();
  static var spaces:Map<String, Float> = new Map();
  static var families:Map<String, String> = new Map();
  static var unusable:Map<String, Bool> = new Map();

  static var field:TextField = null;

  /**
   * Drops every cached glyph and metric. Call it when the alphabet font changes so the old
   * faces stop holding VRAM.
   *
   * Pages still held by a letter are handed back to Flixel instead of being destroyed here:
   * `persist = false` makes the cache drop them as soon as the last letter lets go, so a
   * page can never be destroyed under a sprite that is still drawing it.
   */
  public static function clearCache():Void
  {
    for (page in pages)
    {
      var graphic:FlxGraphic = page.graphic;
      if (graphic == null || graphic.isDestroyed) continue;
      if (graphic.useCount <= 0) FlxG.bitmap.remove(graphic);
      else graphic.persist = false;
    }
    glyphs = new Map();
    pages = [];
    activePages = new Map();
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
   * Cached atlas graphic holding `char`, drawn with `def`. Returns `null` when the font
   * cannot be used, which tells the caller to fall back to the spritesheet.
   *
   * Use `glyphFrame()` when assigning the glyph to a sprite; the graphic contains a whole
   * atlas page, not just this character.
   */
  public static function glyph(def:AlphabetFontDef, char:String, bold:Bool):FlxGraphic
  {
    var frame:FlxFrame = glyphFrame(def, char, bold);
    return frame == null ? null : frame.parent;
  }

  /**
   * Cached frame holding `char` in a shared atlas page. Non-ASCII glyphs are packed on
   * demand, and a new page is started only when the current one is full.
   */
  public static function glyphFrame(def:AlphabetFontDef, char:String, bold:Bool):FlxFrame
  {
    if (!AlphabetFont.supports(char)) return null;

    var key:String = AlphabetFont.cacheKey(def, char, bold);
    if (glyphs.exists(key))
    {
      var cached:FlxFrame = glyphs.get(key);
      if (cached != null && isUsable(cached.parent)) return cached;

      // A state/cache transition can invalidate a page while its frames remain in this
      // renderer's map. Never hand one of those frames to a live sprite.
      glyphs.remove(key);
      return null; // AlphaCharacter falls back to the classic alphabet spritesheet.
    }
    if (!prepare(def, bold)) return null;

    var boxH:Int = boxHeight(def, bold);
    if (boxH <= 0 || boxH > ATLAS_SIZE) return null;

    var padH:Int = padding(def, bold, false);
    var padV:Int = padding(def, bold, true);
    field.text = char;
    var width:Int = Math.ceil(field.textWidth) + padH * 2;
    if (width < 1) width = 1;
    if (width > ATLAS_SIZE) return null;

    var pageKey:String = AlphabetFont.metricsKey(def, bold, 'active-page');
    var page:AlphabetAtlasPage = activePages.get(pageKey);
    if (page != null && !isUsable(page.graphic))
    {
      activePages.remove(pageKey);
      page = null;
    }
    if (page == null) page = createPage(def, bold);
    if (page == null) return null;

    if (page.x + width > ATLAS_SIZE)
    {
      page.x = 0;
      page.y += page.rowHeight + ATLAS_GAP;
      page.rowHeight = 0;
    }
    if (page.y + boxH > ATLAS_SIZE)
    {
      page = createPage(def, bold);
      if (page == null) return null;
    }

    var frameX:Float = page.x;
    var frameY:Float = page.y;
    page.graphic.bitmap.draw(field, new Matrix(1, 0, 0, 1, frameX + padH, frameY + padV));

    var frame:FlxFrame = page.frames.addSpriteSheetFrame(FlxRect.get(frameX, frameY, width, boxH));
    glyphs.set(key, frame);

    page.x += width + ATLAS_GAP;
    page.rowHeight = Math.max(page.rowHeight, boxH);
    activePages.set(pageKey, page);
    return frame;
  }

  /** Allocates one empty page. Its key cannot collide with a live page from an older cache. */
  static function createPage(def:AlphabetFontDef, bold:Bool):AlphabetAtlasPage
  {
    var bitmap:BitmapData = new BitmapData(ATLAS_SIZE, ATLAS_SIZE, true, 0x00000000);
    var key:String = FlxG.bitmap.getUniqueKey(AlphabetFont.metricsKey(def, bold, 'atlas'));
    var graphic:FlxGraphic = FlxG.bitmap.add(bitmap, false, key);
    if (!isUsable(graphic)) return null;

    // An atlas outlives the letters using it (recycled letters, state changes), exactly like
    // the alphabet spritesheet it replaces. Otherwise Flixel destroys it as soon as the last
    // letter is released, leaving dead frames in the cache.
    graphic.persist = true;
    var page:AlphabetAtlasPage = {
      graphic: graphic,
      frames: new FlxAtlasFrames(graphic),
      x: 0,
      y: 0,
      rowHeight: 0
    };
    pages.push(page);
    return page;
  }

  /** A cached graphic is only safe to assign to a sprite while its bitmap is alive. */
  static inline function isUsable(graphic:FlxGraphic):Bool
  {
    return graphic != null && !graphic.isDestroyed && graphic.bitmap != null;
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
