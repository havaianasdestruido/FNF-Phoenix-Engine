import backend.PlatformIcons;

/** Renderer-free contract tests for the watermark platform badge. Run with:
 * bash tests/haxe/run-platform-icons.sh
 */
class PlatformIconSpec
{
  static function equal<T>(actual:T, expected:T, label:String):Void
  {
    if (actual != expected) throw '$label: expected $expected, got $actual';
  }

  static function check(ok:Bool, label:String):Void
  {
    if (!ok) throw label;
  }

  static function close(actual:Float, expected:Float, label:String, tolerance:Float = 0.0001):Void
  {
    if (Math.abs(actual - expected) > tolerance) throw '$label: expected $expected, got $actual';
  }

  static function main():Void
  {
    detection();
    density();
    raster();
    artwork();
    trace('PlatformIconSpec: ok');
  }

  /** The badge must follow the build target, not the host that compiled it. */
  static function detection():Void
  {
    #if android
    equal(PlatformIcons.detect(), PlatformKind.ANDROID, 'android build');
    #elseif ios
    equal(PlatformIcons.detect(), PlatformKind.IOS, 'ios build');
    #elseif html5
    equal(PlatformIcons.detect(), PlatformKind.WEB, 'html5 build');
    #elseif air
    // AIR also defines `flash`; the more specific target has to win.
    equal(PlatformIcons.detect(), PlatformKind.AIR, 'air build');
    #elseif flash
    equal(PlatformIcons.detect(), PlatformKind.FLASH, 'flash build');
    #elseif windows
    equal(PlatformIcons.detect(), PlatformKind.WINDOWS, 'windows build');
    #elseif mac
    equal(PlatformIcons.detect(), PlatformKind.MAC, 'mac build');
    #elseif linux
    equal(PlatformIcons.detect(), PlatformKind.LINUX, 'linux build');
    #else
    // No OS define: the runtime system name is the fallback.
    check(PlatformIcons.detect() != null, 'fallback detection');
    #end

    equal(PlatformIcons.fromSystemName('Windows'), PlatformKind.WINDOWS, 'Windows name');
    equal(PlatformIcons.fromSystemName('MinGW'), PlatformKind.WINDOWS, 'MinGW name');
    equal(PlatformIcons.fromSystemName('Mac'), PlatformKind.MAC, 'Mac name');
    equal(PlatformIcons.fromSystemName('Darwin'), PlatformKind.MAC, 'Darwin name');
    equal(PlatformIcons.fromSystemName('Linux'), PlatformKind.LINUX, 'Linux name');
    equal(PlatformIcons.fromSystemName('FreeBSD'), PlatformKind.LINUX, 'BSD name');
    equal(PlatformIcons.fromSystemName('Android'), PlatformKind.ANDROID, 'Android name');
    equal(PlatformIcons.fromSystemName('iPhone OS'), PlatformKind.IOS, 'iPhone name');
    equal(PlatformIcons.fromSystemName('BeOS'), PlatformKind.UNKNOWN, 'unknown name');
    equal(PlatformIcons.fromSystemName(null), PlatformKind.UNKNOWN, 'null name');

    for (kind in PlatformIcons.kinds())
      check(PlatformIcons.label(kind).length > 0, 'label for $kind');
  }

  /** Density drives the size; the curve is gentle, clamped and never shrinks. */
  static function density():Void
  {
    final base:Float = PlatformIcons.DESKTOP_BASELINE_DPI;
    close(PlatformIcons.densityScale(base, base), 1, 'baseline density');
    close(PlatformIcons.densityScale(base * 2.25, base), 1.5, 'square root curve');
    close(PlatformIcons.densityScale(base * 16, base), PlatformIcons.MAX_DENSITY_SCALE, 'clamped density');
    close(PlatformIcons.densityScale(base / 4, base), 1, 'low dpi never shrinks');
    close(PlatformIcons.densityScale(0, base), 1, 'unknown dpi');
    close(PlatformIcons.densityScale(-50, base), 1, 'negative dpi');
    close(PlatformIcons.densityScale(300, 0), 1, 'unknown baseline');

    var previous:Float = 0;
    var dpi:Float = 60;
    while (dpi <= 600)
    {
      final scale:Float = PlatformIcons.densityScale(dpi, base);
      check(scale >= previous, 'density scale is monotonic at $dpi');
      check(scale >= 1 && scale <= PlatformIcons.MAX_DENSITY_SCALE, 'density scale in range at $dpi');
      previous = scale;
      dpi += 10;
    }

    close(PlatformIcons.logicalSize(PlatformIcons.BASE_SIZE, base, base), PlatformIcons.BASE_SIZE, 'baseline size');
    check(PlatformIcons.logicalSize(PlatformIcons.BASE_SIZE, 440, PlatformIcons.MOBILE_BASELINE_DPI) > PlatformIcons.BASE_SIZE,
      'a phone screen grows the badge');
    check(PlatformIcons.logicalSize(PlatformIcons.BASE_SIZE, 440, PlatformIcons.MOBILE_BASELINE_DPI) <= PlatformIcons.BASE_SIZE
      * PlatformIcons.MAX_DENSITY_SCALE, 'but never past the cap');
  }

  /** Bitmaps follow the window scale and always leave room for the outline. */
  static function raster():Void
  {
    equal(PlatformIcons.rasterSize(18, 1), 18, '1x window');
    equal(PlatformIcons.rasterSize(18, 3), 54, '3x window');
    equal(PlatformIcons.rasterSize(18, 0.5), 18, 'never below the logical size');
    equal(PlatformIcons.rasterSize(18, 99), Std.int(18 * PlatformIcons.MAX_RASTER_SCALE), 'supersampling is capped');
    equal(PlatformIcons.rasterSize(1, 1), PlatformIcons.MIN_RASTER_SIZE, 'minimum bitmap');
    equal(PlatformIcons.rasterSize(4096, 4), PlatformIcons.MAX_RASTER_SIZE, 'maximum bitmap');

    for (size in [PlatformIcons.MIN_RASTER_SIZE, 16, 18, 27, 48, 96, PlatformIcons.MAX_RASTER_SIZE])
    {
      final outline:Float = PlatformIcons.outlineWidth(size);
      check(outline >= 1, 'outline is at least one pixel at $size');
      check(outline * 2 < size, 'outline leaves room for the glyph at $size');
      check(PlatformIcons.contentScale(size, outline) > 0, 'content scale at $size');
    }
  }

  /**
   * Artwork contract: every platform resolves to a glyph, every glyph has a
   * white body, and nothing leaves the grid, because the renderer only
   * reserves one outline width of padding around it.
   */
  static function artwork():Void
  {
    for (kind in PlatformIcons.kinds())
    {
      final glyph:Glyph = PlatformIcons.glyph(kind);
      check(glyph.length > 0, 'glyph for $kind is not empty');

      var bodies:Int = 0;
      for (part in glyph)
      {
        if (part.ink == GlyphInk.BODY) bodies++;
        for (point in points(part.shape))
          check(point >= 0 && point <= PlatformIcons.GRID, 'glyph $kind stays on the grid, got $point');
      }
      check(bodies > 0, 'glyph for $kind has a white body');
    }

    check(PlatformIcons.glyph(PlatformKind.MAC) == PlatformIcons.glyph(PlatformKind.IOS), 'apple is shared by mac and ios');
    check(PlatformIcons.glyph('something-else') == PlatformIcons.glyph(PlatformKind.UNKNOWN), 'unknown platforms fall back');
  }

  /** Every coordinate a shape touches, extremes included. */
  static function points(shape:GlyphShape):Array<Float>
  {
    return switch (shape)
    {
      case Rect(x, y, width, height): [x, y, x + width, y + height];
      case RoundRect(x, y, width, height, radius): [x, y, x + width, y + height, radius, radius];
      case Circle(x, y, radius): [x - radius, y - radius, x + radius, y + radius];
      case Ellipse(x, y, radiusX, radiusY): [x - radiusX, y - radiusY, x + radiusX, y + radiusY];
      case Polygon(coordinates): coordinates.copy();
      case Contour(commands) | Stroke(commands): commandPoints(commands);
    }
  }

  static function commandPoints(commands:Array<PathCommand>):Array<Float>
  {
    final values:Array<Float> = [];
    for (command in commands)
    {
      switch (command)
      {
        case Move(x, y) | Line(x, y):
          {
            values.push(x);
            values.push(y);
          }
        case Curve(controlX, controlY, x, y):
          {
            values.push(controlX);
            values.push(controlY);
            values.push(x);
            values.push(y);
          }
      }
    }
    return values;
  }
}
