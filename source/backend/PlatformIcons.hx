package backend;

/**
 * Which platform badge the engine-version watermark shows.
 *
 * The value doubles as the cache key suffix of the rendered bitmap, so keep it
 * lowercase and stable.
 */
enum abstract PlatformKind(String) from String to String
{
  var WINDOWS = "windows";
  var MAC = "mac";
  var IOS = "ios";
  var LINUX = "linux";
  var ANDROID = "android";
  var WEB = "web";
  var AIR = "air";
  var FLASH = "flash";
  var UNKNOWN = "unknown";
}

/** How a glyph part is painted. See `PlatformIcons` for the drawing order. */
enum abstract GlyphInk(Int) from Int to Int
{
  /** Part of the silhouette: dark outline underneath, white fill on top. */
  var BODY = 0;

  /** Dark shape painted over the white fill (eyes, letter counters). */
  var DETAIL = 1;

  /** Dark stroke painted over the white fill (globe meridians). */
  var MARK = 2;
}

/** A single segment of a hand-drawn contour on the glyph grid. */
enum PathCommand
{
  Move(x:Float, y:Float);
  Line(x:Float, y:Float);

  /** Quadratic segment, matching `openfl.display.Graphics.curveTo`. */
  Curve(controlX:Float, controlY:Float, x:Float, y:Float);
}

/** Primitive shapes a glyph part can be built from, on the 0..100 grid. */
enum GlyphShape
{
  Rect(x:Float, y:Float, width:Float, height:Float);
  RoundRect(x:Float, y:Float, width:Float, height:Float, radius:Float);

  /** Centre-anchored circle. */
  Circle(x:Float, y:Float, radius:Float);

  /** Centre-anchored ellipse. */
  Ellipse(x:Float, y:Float, radiusX:Float, radiusY:Float);

  /** Closed polygon from a flat `[x0, y0, x1, y1, ...]` list. */
  Polygon(points:Array<Float>);

  /** Closed contour; the renderer joins the last point back to the first. */
  Contour(commands:Array<PathCommand>);

  /** Open polyline. Only meaningful for `MARK` parts. */
  Stroke(commands:Array<PathCommand>);
}

typedef GlyphPart =
{
  var ink:GlyphInk;
  var shape:GlyphShape;
}

typedef Glyph = Array<GlyphPart>;

/**
 * Platform detection plus the vector artwork and sizing math behind the little
 * badge that sits on top of the engine-version watermark.
 *
 * Everything here is deliberately free of Flixel/OpenFL/Lime imports so the
 * geometry and the density math can run under `haxe --interp`
 * (`tests/haxe/run-platform-icons.sh`). `objects.PlatformIcon` turns the data
 * into a bitmap and `backend.ScreenDensity` answers the display questions.
 *
 * ### Why vectors instead of PNGs
 *
 * The badge has to look identical on a 96-dpi monitor, a 4K display and a
 * 440-dpi phone, so there is no single sensible pixel size to ship. Each glyph
 * is drawn on a 100x100 grid and rasterised on demand at the size the current
 * display actually needs, which also keeps the icons visually consistent: one
 * grid, one outline weight, one optical box for every platform.
 *
 * ### Painting order (see `objects.PlatformIcon`)
 *
 * 1. every `BODY` part is stroked *and* filled dark, which welds overlapping
 *    parts (an Android arm and its torso, Tux's head and belly) into a single
 *    silhouette with one uniform halo;
 * 2. every `BODY` part is filled white with no stroke, leaving the halo
 *    showing as the outline;
 * 3. `DETAIL` parts are filled dark on top, `MARK` parts are stroked dark.
 */
class PlatformIcons
{
  /** Glyphs are authored on a square 0..100 grid, y pointing down. */
  public static inline var GRID:Float = 100;

  /** Logical (game pixel) size of the badge on a baseline-density screen. */
  public static inline var BASE_SIZE:Float = 18;

  /** Density baseline for desktop and web: the classic 96-dpi monitor. */
  public static inline var DESKTOP_BASELINE_DPI:Float = 96;

  /** Density baseline for phones and tablets: Android's 160-dpi `mdpi`. */
  public static inline var MOBILE_BASELINE_DPI:Float = 160;

  /** Upper bound for the density growth, so the badge never dwarfs the text. */
  public static inline var MAX_DENSITY_SCALE:Float = 1.5;

  /** Upper bound for supersampling; 4x already covers 4K and retina panels. */
  public static inline var MAX_RASTER_SCALE:Float = 4;

  /** Clamps for the rasterised bitmap, in pixels. */
  public static inline var MIN_RASTER_SIZE:Int = 8;

  public static inline var MAX_RASTER_SIZE:Int = 512;

  /** Outline weight as a fraction of the rasterised box. */
  public static inline var OUTLINE_RATIO:Float = 0.055;

  /** `MARK` strokes are slightly lighter than the silhouette outline. */
  public static inline var MARK_RATIO:Float = 0.8;

  /**
   * The platform this build is running on.
   *
   * Compile-time defines decide it, in the order the targets overlap: AIR also
   * defines `flash`, mobile AIR/HashLink/Neko builds also define their host OS,
   * so the most specific target has to win. Builds without an OS define fall
   * back to the runtime system name.
   */
  public static function detect():PlatformKind
  {
    #if android
    return PlatformKind.ANDROID;
    #elseif ios
    return PlatformKind.IOS;
    #elseif html5
    return PlatformKind.WEB;
    #elseif air
    return PlatformKind.AIR;
    #elseif flash
    return PlatformKind.FLASH;
    #elseif windows
    return PlatformKind.WINDOWS;
    #elseif mac
    return PlatformKind.MAC;
    #elseif linux
    return PlatformKind.LINUX;
    #elseif sys
    return fromSystemName(Sys.systemName());
    #else
    return PlatformKind.UNKNOWN;
    #end
  }

  /** Maps a `Sys.systemName()` style string onto a badge. */
  public static function fromSystemName(name:String):PlatformKind
  {
    if (name == null) return PlatformKind.UNKNOWN;
    final lower:String = name.toLowerCase();
    if (lower.indexOf("android") >= 0) return PlatformKind.ANDROID;
    if (lower.indexOf("iphone") >= 0 || lower.indexOf("ipad") >= 0 || lower.indexOf("ios") >= 0) return PlatformKind.IOS;
    if (lower.indexOf("windows") >= 0 || lower.indexOf("mingw") >= 0 || lower.indexOf("cygwin") >= 0) return PlatformKind.WINDOWS;
    if (lower.indexOf("mac") >= 0 || lower.indexOf("darwin") >= 0) return PlatformKind.MAC;
    if (lower.indexOf("linux") >= 0 || lower.indexOf("bsd") >= 0) return PlatformKind.LINUX;
    return PlatformKind.UNKNOWN;
  }

  /** Human readable name, used by tooltips, logs and script getters. */
  public static function label(kind:PlatformKind):String
  {
    return switch (kind)
    {
      case PlatformKind.WINDOWS: "Windows";
      case PlatformKind.MAC: "macOS";
      case PlatformKind.IOS: "iOS";
      case PlatformKind.LINUX: "Linux";
      case PlatformKind.ANDROID: "Android";
      case PlatformKind.WEB: "Web";
      case PlatformKind.AIR: "Adobe AIR";
      case PlatformKind.FLASH: "Flash";
      default: "Unknown";
    }
  }

  /**
   * How much bigger the badge gets on a denser screen.
   *
   * A square root keeps the growth gentle: a screen with 2.25x the baseline
   * density draws the badge 1.5x bigger, not 2.25x, which is what keeps it
   * sitting next to 16-pixel watermark text instead of towering over it. The
   * badge never shrinks below its authored size.
   */
  public static function densityScale(dpi:Float, baselineDpi:Float):Float
  {
    if (!(dpi > 0) || !(baselineDpi > 0)) return 1;
    final scale:Float = Math.sqrt(dpi / baselineDpi);
    if (scale <= 1) return 1;
    return scale > MAX_DENSITY_SCALE ? MAX_DENSITY_SCALE : scale;
  }

  /**
   * Size of the badge in game pixels for the given display density, rounded
   * to whole pixels so the bitmap lands on the pixel grid instead of
   * straddling it.
   */
  public static function logicalSize(baseSize:Float, dpi:Float, baselineDpi:Float):Float
  {
    final size:Float = Math.fround(baseSize * densityScale(dpi, baselineDpi));
    return size < 1 ? 1 : size;
  }

  /**
   * Size of the bitmap to rasterise, in real pixels.
   *
   * `pixelsPerGamePixel` is how many device pixels one game pixel covers right
   * now (window scaling times the HiDPI backing scale), so a fullscreen 4K
   * window renders the same badge from a 3x bigger bitmap instead of smearing
   * a 720p one across the screen.
   */
  public static function rasterSize(logicalSize:Float, pixelsPerGamePixel:Float):Int
  {
    var ratio:Float = pixelsPerGamePixel;
    if (!(ratio > 1)) ratio = 1;
    if (ratio > MAX_RASTER_SCALE) ratio = MAX_RASTER_SCALE;
    final size:Int = Math.ceil(logicalSize * ratio);
    if (size < MIN_RASTER_SIZE) return MIN_RASTER_SIZE;
    return size > MAX_RASTER_SIZE ? MAX_RASTER_SIZE : size;
  }

  /** Outline thickness, in pixels, for a rasterised badge of `rasterSize`. */
  public static function outlineWidth(rasterSize:Float):Float
  {
    final width:Float = rasterSize * OUTLINE_RATIO;
    return width < 1 ? 1 : width;
  }

  /**
   * Pixels per grid unit once room for the outline halo has been reserved on
   * all four sides, so the stroke can never be clipped by the bitmap edge.
   */
  public static function contentScale(rasterSize:Float, outlinePx:Float):Float
  {
    final usable:Float = rasterSize - 2 * outlinePx;
    return usable > 0 ? usable / GRID : 0;
  }

  /** The artwork for a platform. Unknown platforms get the generic device. */
  public static function glyph(kind:PlatformKind):Glyph
  {
    return switch (kind)
    {
      case PlatformKind.WINDOWS: WINDOWS_GLYPH;
      case PlatformKind.MAC | PlatformKind.IOS: APPLE_GLYPH;
      case PlatformKind.LINUX: LINUX_GLYPH;
      case PlatformKind.ANDROID: ANDROID_GLYPH;
      case PlatformKind.WEB: WEB_GLYPH;
      case PlatformKind.AIR: AIR_GLYPH;
      case PlatformKind.FLASH: FLASH_GLYPH;
      default: UNKNOWN_GLYPH;
    }
  }

  /** Every badge, in a stable order. Used by the preview tool and the tests. */
  public static function kinds():Array<PlatformKind>
  {
    return [
      PlatformKind.WINDOWS,
      PlatformKind.MAC,
      PlatformKind.IOS,
      PlatformKind.LINUX,
      PlatformKind.ANDROID,
      PlatformKind.WEB,
      PlatformKind.AIR,
      PlatformKind.FLASH,
      PlatformKind.UNKNOWN
    ];
  }

  static inline function body(shape:GlyphShape):GlyphPart
    return {ink: GlyphInk.BODY, shape: shape};

  static inline function detail(shape:GlyphShape):GlyphPart
    return {ink: GlyphInk.DETAIL, shape: shape};

  static inline function mark(shape:GlyphShape):GlyphPart
    return {ink: GlyphInk.MARK, shape: shape};

  /*
   * ------------------------------------------------------------------------
   * Artwork. Everything lives inside roughly 10..90 on both axes: the outline
   * grows outwards from the shape, and the renderer only reserves one outline
   * width of padding around the grid.
   * ------------------------------------------------------------------------
   */

  /** Four flag panes, left column dropped for the familiar perspective. */
  static final WINDOWS_GLYPH:Glyph = [
    body(Polygon([12, 24, 46, 20.4, 46, 46, 12, 46])),
    body(Polygon([54, 19.6, 88, 16, 88, 46, 54, 46])),
    body(Polygon([12, 54, 46, 54, 46, 79.6, 12, 76])),
    body(Polygon([54, 54, 88, 54, 88, 84, 54, 80.4]))
  ];

  /** The bitten apple shared by the macOS and iOS builds. */
  static final APPLE_GLYPH:Glyph = [
    // The leaf keeps a small gap from the body: the two outlines meet in it
    // and read as the stem notch instead of one blob.
    body(Contour([Move(53, 30), Curve(54, 16, 73, 11), Curve(68, 27, 53, 30)])),
    body(Contour([
      Move(50, 37),
      Curve(56, 28, 64, 29),
      Curve(73, 31, 76, 35),
      // Concave control point: this is the bite out of the right-hand side.
      Curve(54, 45, 76, 56),
      Curve(86, 64, 81, 77),
      Curve(76, 90, 66, 90),
      Curve(57, 91, 50, 88),
      Curve(43, 91, 34, 90),
      Curve(24, 90, 19, 77),
      Curve(14, 63, 19, 50),
      Curve(23, 34, 35, 29),
      Curve(44, 26, 50, 37)
    ]))
  ];

  /** Tux, trimmed down to the shapes that survive at 18 pixels. */
  static final LINUX_GLYPH:Glyph = [
    body(Ellipse(50, 60, 27, 27)),
    body(Circle(50, 31, 19)),
    // Flippers and feet stick out of the silhouette; the weld hides the seams.
    body(Contour([Move(26, 48), Curve(14, 60, 20, 76), Curve(27, 72, 29, 58)])),
    body(Contour([Move(74, 48), Curve(86, 60, 80, 76), Curve(73, 72, 71, 58)])),
    body(Ellipse(36, 86, 13, 6)),
    body(Ellipse(64, 86, 13, 6)),
    detail(Circle(43.5, 29, 3.2)),
    detail(Circle(56.5, 29, 3.2)),
    detail(Ellipse(50, 37, 8, 4.5))
  ];

  /** The droid: dome, antennae, torso, arms and legs. */
  static final ANDROID_GLYPH:Glyph = [
    body(Polygon([39.8, 23.3, 29.3, 7.8, 22.7, 12.2, 33.2, 27.7])),
    body(Polygon([60.2, 23.3, 70.7, 7.8, 77.3, 12.2, 66.8, 27.7])),
    body(Contour([Move(27, 40), Curve(27, 17, 50, 17), Curve(73, 17, 73, 40)])),
    body(RoundRect(27, 44, 46, 36, 6)),
    body(RoundRect(14, 46, 9, 26, 4.5)),
    body(RoundRect(77, 46, 9, 26, 4.5)),
    body(RoundRect(35, 76, 10, 14, 5)),
    body(RoundRect(55, 76, 10, 14, 5)),
    detail(Circle(41, 30, 3.4)),
    detail(Circle(59, 30, 3.4))
  ];

  /**
   * Globe for HTML5 builds. Only the equator and a single meridian survive at
   * watermark size; extra latitude lines turn the disc into grey mush.
   */
  static final WEB_GLYPH:Glyph = [
    body(Circle(50, 50, 37)),
    mark(Stroke([Move(14, 50), Line(86, 50)])),
    mark(Ellipse(50, 50, 15.5, 37))
  ];

  /** Adobe's wedge "A" for AIR builds. */
  static final AIR_GLYPH:Glyph = [
    body(Polygon([50, 11, 85, 88, 15, 88])),
    detail(Polygon([50, 44, 61, 70, 39, 70]))
  ];

  /** A lightning bolt for Flash builds. */
  static final FLASH_GLYPH:Glyph = [body(Polygon([60, 8, 26, 55, 45, 55, 40, 92, 76, 43, 55, 43]))];

  /** Anonymous monitor for targets the engine cannot name. */
  static final UNKNOWN_GLYPH:Glyph = [
    body(RoundRect(12, 20, 76, 48, 7)),
    body(Rect(42, 68, 16, 10)),
    body(RoundRect(28, 78, 44, 9, 4.5))
  ];
}
