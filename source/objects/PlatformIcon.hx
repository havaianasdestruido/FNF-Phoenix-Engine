package objects;

import backend.ClientPrefs;
import backend.PlatformIcons;
import backend.ScreenDensity;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import openfl.display.BitmapData;
import openfl.display.Graphics;
import openfl.display.Shape;

/**
 * The little platform badge that rides on top of the engine-version watermark:
 * Windows on a Windows build, the droid on Android, the apple on macOS/iOS, a
 * globe on web, a bolt on Flash, Adobe's wedge on AIR, Tux on Linux.
 *
 * The artwork is vector data (`backend.PlatformIcons`) rasterised on demand,
 * which is what makes the badge density-aware: its size follows the display
 * DPI and its bitmap follows the window scale, so it stays crisp on a 4K
 * desktop and legible on a phone without shipping one PNG per platform per
 * density.
 *
 * ```haxe
 * platformIcon = new PlatformIcon();
 * add(platformIcon);
 * platformIcon.placeAbove(EngineWatermark);
 * ```
 */
class PlatformIcon extends FlxSprite
{
  static inline var FILL_COLOR:Int = 0xFFFFFF;

  static inline var OUTLINE_COLOR:Int = 0x000000;

  /** Rasterised badges, keyed by platform and pixel size. */
  static var graphicCache:Map<String, FlxGraphic> = new Map();

  /** Which platform this badge is drawing. */
  public var kind(default, null):PlatformKind;

  /** Authored size in game pixels, before the density boost. */
  public var baseSize(default, null):Float;

  /** Size in game pixels the badge is currently drawn at. */
  public var displaySize(default, null):Float = 0;

  var rasterSize:Int = 0;
  var anchor:FlxObject;
  var anchorGap:Float = 3;
  var anchorRight:Bool = false;

  /** `baseSize` is in game pixels before the density boost; 0 keeps the default. */
  public function new(x:Float = 0, y:Float = 0, ?kind:PlatformKind, baseSize:Float = 0)
  {
    super(x, y);
    this.kind = (kind == null) ? PlatformIcons.detect() : kind;
    this.baseSize = baseSize > 0 ? baseSize : PlatformIcons.BASE_SIZE;

    scrollFactor.set();
    moves = false;
    active = false;
    antialiasing = ClientPrefs.globalAntialiasing;
    refresh(true);
  }

  /**
   * Re-rasterises the badge when the display density or the window scale
   * changed, then re-anchors it. Cheap to call every resize: it returns
   * immediately when the bitmap would come out identical.
   */
  public function refresh(force:Bool = false):Void
  {
    final size:Float = PlatformIcons.logicalSize(baseSize, ScreenDensity.dpi(), ScreenDensity.baselineDpi());
    final raster:Int = PlatformIcons.rasterSize(size, ScreenDensity.pixelsPerGamePixel());
    if (!force && raster == rasterSize && size == displaySize) return;

    displaySize = size;
    rasterSize = raster;

    loadGraphic(graphicFor(kind, raster));
    setGraphicSize(size, size);
    updateHitbox();
    reposition();
  }

  /**
   * Pins the badge on top of `target` (the watermark text) and remembers it,
   * so resizes and density changes keep the two together.
   *
   * @param gap        distance to the text, in game pixels.
   * @param alignRight anchor to the target's right edge instead of its left,
   *                   for watermark styles that hug the right of the screen.
   */
  public function placeAbove(target:FlxObject, gap:Float = 3, alignRight:Bool = false):PlatformIcon
  {
    anchor = target;
    anchorGap = gap;
    anchorRight = alignRight;
    return reposition();
  }

  /** Re-applies the anchor set by `placeAbove`. */
  public function reposition():PlatformIcon
  {
    if (anchor == null) return this;

    x = anchorRight ? anchor.x + anchor.width - width : anchor.x;

    // Watermark styles that sit near the top of the screen leave no room
    // above them, so the badge drops under the text instead of off-screen.
    final above:Float = anchor.y - anchorGap - height;
    y = above >= 0 ? above : anchor.y + anchor.height + anchorGap;
    return this;
  }

  override public function destroy():Void
  {
    anchor = null;
    super.destroy();
  }

  /** Cached bitmap for one platform at one pixel size. */
  static function graphicFor(kind:PlatformKind, size:Int):FlxGraphic
  {
    final key:String = 'phoenix-platform-icon:$kind:$size';
    if (graphicCache.exists(key))
    {
      final cached:FlxGraphic = graphicCache.get(key);
      // Paths.clearStoredMemory() evicts bitmaps between states, so verify the
      // cached graphic is still the live one (same guard as HealthIcon).
      if (cached != null && cached.bitmap != null && FlxG.bitmap.get(cached.key) == cached) return cached;
      graphicCache.remove(key);
    }

    final graphic:FlxGraphic = FlxGraphic.fromBitmapData(render(kind, size), false, key);
    graphic.persist = true;
    graphic.destroyOnNoUse = false;
    graphicCache.set(key, graphic);
    return graphic;
  }

  /**
   * Draws one badge into a fresh `size` x `size` bitmap.
   *
   * Three passes, in this order, which is what gives every platform the same
   * white-with-an-outline look:
   *
   * 1. each body part is filled *and* stroked in the outline colour, so parts
   *    that overlap (an arm over a torso, Tux's head over his belly) weld into
   *    a single silhouette with one halo instead of showing inner seams;
   * 2. each body part is filled white without a stroke, leaving exactly half
   *    the stroke width of halo visible as the outline;
   * 3. details are filled and marks are stroked in the outline colour on top.
   *
   * Each part gets its own `beginFill`/`endFill` pair: overlapping sub-paths
   * inside one fill cancel out (even-odd) instead of merging.
   */
  public static function render(kind:PlatformKind, size:Int):BitmapData
  {
    final outline:Float = PlatformIcons.outlineWidth(size);
    final scale:Float = PlatformIcons.contentScale(size, outline);
    final glyph:Glyph = PlatformIcons.glyph(kind);

    final shape:Shape = new Shape();
    final gfx:Graphics = shape.graphics;

    for (part in glyph)
    {
      if (part.ink != GlyphInk.BODY) continue;
      gfx.lineStyle(outline * 2, OUTLINE_COLOR, 1);
      gfx.beginFill(OUTLINE_COLOR, 1);
      drawShape(gfx, part.shape, outline, scale);
      gfx.endFill();
    }

    gfx.lineStyle();
    for (part in glyph)
    {
      if (part.ink != GlyphInk.BODY) continue;
      gfx.beginFill(FILL_COLOR, 1);
      drawShape(gfx, part.shape, outline, scale);
      gfx.endFill();
    }

    for (part in glyph)
    {
      if (part.ink != GlyphInk.DETAIL) continue;
      gfx.beginFill(OUTLINE_COLOR, 1);
      drawShape(gfx, part.shape, outline, scale);
      gfx.endFill();
    }

    for (part in glyph)
    {
      if (part.ink != GlyphInk.MARK) continue;
      gfx.lineStyle(outline * PlatformIcons.MARK_RATIO, OUTLINE_COLOR, 1);
      drawShape(gfx, part.shape, outline, scale);
    }
    gfx.lineStyle();

    final bitmap:BitmapData = new BitmapData(size, size, true, 0);
    bitmap.draw(shape);
    return bitmap;
  }

  /** Emits one glyph shape, mapping the 0..100 grid onto the bitmap. */
  static function drawShape(gfx:Graphics, shape:GlyphShape, offset:Float, scale:Float):Void
  {
    switch (shape)
    {
      case Rect(x, y, width, height):
        gfx.drawRect(offset + x * scale, offset + y * scale, width * scale, height * scale);

      case RoundRect(x, y, width, height, radius):
        gfx.drawRoundRect(offset + x * scale, offset + y * scale, width * scale, height * scale, radius * 2 * scale, radius * 2 * scale);

      case Circle(x, y, radius):
        gfx.drawCircle(offset + x * scale, offset + y * scale, radius * scale);

      case Ellipse(x, y, radiusX, radiusY):
        gfx.drawEllipse(offset + (x - radiusX) * scale, offset + (y - radiusY) * scale, radiusX * 2 * scale, radiusY * 2 * scale);

      case Polygon(points):
        if (points.length < 6) return;
        gfx.moveTo(offset + points[0] * scale, offset + points[1] * scale);
        var index:Int = 2;
        while (index + 1 < points.length)
        {
          gfx.lineTo(offset + points[index] * scale, offset + points[index + 1] * scale);
          index += 2;
        }
        gfx.lineTo(offset + points[0] * scale, offset + points[1] * scale);

      case Contour(commands):
        drawCommands(gfx, commands, offset, scale, true);

      case Stroke(commands):
        drawCommands(gfx, commands, offset, scale, false);
    }
  }

  static function drawCommands(gfx:Graphics, commands:Array<PathCommand>, offset:Float, scale:Float, close:Bool):Void
  {
    var startX:Float = 0;
    var startY:Float = 0;
    var started:Bool = false;

    for (command in commands)
    {
      switch (command)
      {
        case Move(x, y):
          startX = offset + x * scale;
          startY = offset + y * scale;
          started = true;
          gfx.moveTo(startX, startY);

        case Line(x, y):
          gfx.lineTo(offset + x * scale, offset + y * scale);

        case Curve(controlX, controlY, x, y):
          gfx.curveTo(offset + controlX * scale, offset + controlY * scale, offset + x * scale, offset + y * scale);
      }
    }

    // Fills close themselves, strokes do not: without this the outline pass
    // would leave a notch where the contour started.
    if (close && started) gfx.lineTo(startX, startY);
  }
}
