package backend;

/**
 * Renderer-free rules and presets for the bottom-left `FlxPieDial` indicator
 * shown on loading screens (`states.LoadingState` and `mobile.CopyState`).
 *
 * Kept free of Flixel/OpenFL/Lime imports so `tests/haxe/LoadingDialSpec.hx`
 * can verify positioning, clamping and color normalization under `haxe --interp`
 * without installing the game haxelibs.
 */
class LoadingDialLogic
{
  /** Outer radius of the circular dial, matching `VideoSprite` / `CutsceneHandler`. */
  public static inline var RADIUS:Int = 40;

  /** Inner cutout radius so the dial renders as a crisp progress ring. */
  public static inline var INNER_RADIUS:Int = 24;

  /** Frame count baked into the dial spritesheet. */
  public static inline var FRAMES:Int = 40;

  /** Distance from the bottom and left edges of the viewport, in game units. */
  public static inline var MARGIN:Int = 24;

  /** Track ring color behind the active progress arc. */
  public static inline var TRACK_COLOR:Int = 0xFF000000;

  /** Opacity of the backing track ring so the dial stays readable on any art. */
  public static inline var TRACK_ALPHA:Float = 0.35;

  /** Default color preset name (matches Phoenix's signature loading pink). */
  public static inline var DEFAULT_COLOR:String = 'Pink';

  static final COLOR_ORDER:Array<String> = ['Pink', 'White', 'Cyan', 'Yellow', 'Green', 'Black'];

  static final COLOR_MAP:Map<String, Int> = [
    'pink' => 0xFFFF16D2,
    'white' => 0xFFFFFFFF,
    'cyan' => 0xFF00E5FF,
    'yellow' => 0xFFFFD800,
    'green' => 0xFF2ECC71,
    'black' => 0xFF1A1A1A
  ];

  /** Returns the ordered list of dial color preset names for Options menus. */
  public static function colorNames():Array<String>
    return COLOR_ORDER.copy();

  /**
   * Normalizes a saved or user-supplied color preset name, falling back to
   * `DEFAULT_COLOR` when missing or unrecognized.
   *
   * @param name raw preset name
   * @return canonical preset name from `colorNames()`
   */
  public static function normalizeColor(name:String):String
  {
    if (name == null) return DEFAULT_COLOR;
    final trimmed:String = StringTools.trim(name).toLowerCase();
    for (preset in COLOR_ORDER)
      if (preset.toLowerCase() == trimmed) return preset;
    return DEFAULT_COLOR;
  }

  /**
   * Resolves a preset name to its ARGB color integer.
   *
   * @param name preset name (case-insensitive)
   * @return `0xAARRGGBB` color value
   */
  public static function colorValue(name:String):Int
  {
    final canonical:String = normalizeColor(name).toLowerCase();
    final value:Null<Int> = COLOR_MAP.get(canonical);
    return value != null ? value : 0xFFFF16D2;
  }

  /**
   * Computes the bottom-left corner position for a dial inside the viewport.
   *
   * @param viewportWidth  current logical viewport width
   * @param viewportHeight current logical viewport height
   * @param dialWidth      dial sprite width
   * @param dialHeight     dial sprite height
   * @param margin         inset from the bottom and left edges
   * @return top-left coordinates placing the dial in the bottom-left corner
   */
  public static function position(viewportWidth:Int, viewportHeight:Int, dialWidth:Float, dialHeight:Float,
      ?margin:Int = MARGIN):{x:Float, y:Float}
  {
    final safeW:Float = (dialWidth != dialWidth || dialWidth < 0) ? 0 : dialWidth;
    final safeH:Float = (dialHeight != dialHeight || dialHeight < 0) ? 0 : dialHeight;
    final safeMargin:Float = (margin == null || margin < 0) ? 0 : margin;
    final viewW:Float = viewportWidth > 0 ? viewportWidth : 0;
    final viewH:Float = viewportHeight > 0 ? viewportHeight : 0;

    final maxX:Float = Math.max(0, viewW - safeW);
    final x:Float = Math.min(maxX, safeMargin);
    final y:Float = Math.max(0, viewH - safeH - safeMargin);
    return {x: x, y: y};
  }

  /**
   * Maps a normalized `0..1` loading progress value to a safe `FlxPieDial.amount`.
   *
   * `flixel.addons.display.FlxPieDial` stores the full 360-degree graphic at
   * frame 0 and computes `Std.int(f * pieFrames)`, so values between `0` and
   * `1 / frames` would flash a full circle if passed directly. This snaps
   * sub-step positive progress to `0` (skipped by `draw()`) and caps partial
   * progress below `1` so frame 0 only appears at completion (`1.0`).
   *
   * @param progress raw `0..1` progress
   * @param frames   frame count of the `FlxPieDial`
   * @return safe `0..1` value for `FlxPieDial.amount`
   */
  public static function dialAmount(progress:Float, ?frames:Int = FRAMES):Float
  {
    if (progress != progress || progress <= 0) return 0;
    if (progress >= 1) return 1;

    final safeFrames:Int = (frames == null || frames < 2) ? FRAMES : frames;
    final clamped:Float = progress > 0.9999 ? 0.9999 : progress;
    if (Std.int(clamped * safeFrames) <= 0) return 0;
    return clamped;
  }

  /**
   * Converts discrete item counts (`completed / total`) into a clamped `0..1`
   * progress ratio.
   *
   * @param completed number of completed items
   * @param total     total number of items
   * @return `0..1` ratio (`1` when `total <= 0`)
   */
  public static function progressFromCounts(completed:Int, total:Int):Float
  {
    if (total <= 0) return 1;
    if (completed <= 0) return 0;
    return completed >= total ? 1 : (completed / total);
  }
}
