package backend;

/** Where one cloth piece is drawn, in 1280x720 game units. */
typedef ClothPiece =
{
  var x:Float;
  var y:Float;
}

/** The four pieces the cloth easter egg draws (see `states.substates.ClothEasterEggSubstate`). */
typedef ClothScene =
{
  /** Banner that follows the pointer, pinned on its left edge. */
  var banner:ClothPiece;
  /** Banner pinned at both top corners, with crossing constraints. */
  var bannerTwo:ClothPiece;
  /** Hanging rope on the left of the pair. */
  var ropeLeft:ClothPiece;
  /** Hanging rope on the right of the pair. */
  var ropeRight:ClothPiece;
}

/**
 * Renderer-free rules behind the `FlxClothSprite` easter egg
 * (`states.substates.ClothEasterEggSubstate`).
 *
 * Three things live here instead of in the substate so they can be checked
 * without Flixel/OpenFL/Lime (see `tests/haxe/ClothEasterEggSpec.hx`):
 *
 * - the hidden key code that opens the scene (`C`, `L`, `O`, `T`, `H` typed on
 *   the main menu, forgotten after {@link SEQUENCE_TIMEOUT} seconds), mirroring
 *   how the other menu easter eggs are triggered;
 * - where the four pieces are placed inside the centered 1280x720 content area,
 *   so the scene keeps fitting widescreen, 4:3 and portrait viewports;
 * - the wind/gravity numbers the cloth mesh is driven with, including the
 *   reduced-motion variant.
 *
 * No Flixel, OpenFL or Lime imports, so `haxe --interp` can run the spec in CI
 * without the game's haxelibs - the same trick `backend.MenuMusicLogic` and
 * `backend.HoldToConfirmLogic` use.
 */
class ClothEasterEggLogic
{
  /** Letters (as key names) that open the easter egg, in order. */
  public static final SEQUENCE:Array<String> = ['C', 'L', 'O', 'T', 'H'];

  /** Seconds of inactivity after which an unfinished code is forgotten. */
  public static inline var SEQUENCE_TIMEOUT:Float = 2.5;

  /** Downward mesh velocity used as gravity, in pixels per second. */
  public static inline var GRAVITY:Float = 40;

  /** Gravity used when Options -> Visuals and UI -> Reduced Motion is on. */
  public static inline var REDUCED_MOTION_GRAVITY:Float = 10;

  /** Horizontal wind ceiling of the mouse-following banner. */
  public static inline var BANNER_MAX_VELOCITY:Float = 200;

  /** Horizontal wind ceiling of the two hanging ropes. */
  public static inline var ROPE_MAX_VELOCITY:Float = 40;

  /** Width of `assets/preload/images/clothFlag.png`, in pixels. */
  public static inline var BANNER_WIDTH:Int = 300;

  /** Height of `assets/preload/images/clothFlag.png`, in pixels. */
  public static inline var BANNER_HEIGHT:Int = 200;

  /** Width of `assets/preload/images/clothRope.png`, in pixels. */
  public static inline var ROPE_WIDTH:Int = 20;

  /** Height of `assets/preload/images/clothRope.png`, in pixels. */
  public static inline var ROPE_HEIGHT:Int = 360;

  /**
   * Logical size of the mod-compatible content column. Mirrors
   * `backend.ScreenLayout.BASE_WIDTH` / `BASE_HEIGHT`; duplicated so this module
   * stays importable on its own in the interpreter specs.
   */
  public static inline var BASE_WIDTH:Int = 1280;

  /** @see BASE_WIDTH */
  public static inline var BASE_HEIGHT:Int = 720;

  /**
   * Advances the hidden key code by one typed key.
   *
   * A key that does not continue the sequence either restarts the code (when it
   * is the first letter) or clears the progress, and an unfinished code is
   * forgotten once {@link SEQUENCE_TIMEOUT} seconds pass without a key.
   *
   * @param progress         Current progress; anything out of range counts as 0.
   * @param key              Key name of the pressed key, e.g. `'C'`.
   * @param elapsedSinceLast Seconds since the previous accepted key.
   * @return The new progress; equals `SEQUENCE.length` when the code is complete.
   */
  public static function advance(progress:Int, key:String, elapsedSinceLast:Float):Int
  {
    if (progress < 0 || progress > SEQUENCE.length) progress = 0;
    if (elapsedSinceLast > SEQUENCE_TIMEOUT) progress = 0;
    if (progress == SEQUENCE.length) return progress;

    final typed:String = normaliseKey(key);
    if (typed.length == 0) return progress;
    if (typed == SEQUENCE[progress]) return progress + 1;

    // A wrong key does not always throw everything away: typing the first
    // letter again starts a fresh attempt.
    return typed == SEQUENCE[0] ? 1 : 0;
  }

  /** True when every key of the sequence has been typed. */
  public static inline function isComplete(progress:Int):Bool
    return progress >= SEQUENCE.length;

  /** Key name in the form {@link SEQUENCE} uses: trimmed and upper case. */
  public static function normaliseKey(key:String):String
  {
    if (key == null) return '';
    return StringTools.toUpperCase(StringTools.trim(key));
  }

  /**
   * Gravity the mesh should use.
   *
   * @param reducedMotion The `ClientPrefs.reducedMotion` value: the scene still
   *                      responds to the pointer, it just drifts far less.
   */
  public static inline function gravity(reducedMotion:Bool):Float
    return reducedMotion ? REDUCED_MOTION_GRAVITY : GRAVITY;

  /**
   * Horizontal wind applied while the pointer is held down.
   *
   * @param random01    A random value in 0..1 (out-of-range values clamp).
   * @param maxVelocity Ceiling from the piece's `maxVelocity.x`.
   */
  public static function wind(random01:Float, maxVelocity:Float):Float
  {
    var value:Float = Math.isNaN(random01) ? 0 : random01;
    value = value < 0 ? 0 : (value > 1 ? 1 : value);
    return value * maxVelocity;
  }

  /**
   * Left edge of the centered content column, matching
   * `backend.ScreenLayout.contentLeft` (narrow viewports letterbox instead).
   */
  public static function contentLeft(viewportWidth:Int):Float
    return Math.max(0, (Math.max(BASE_WIDTH, viewportWidth) - BASE_WIDTH) / 2);

  /**
   * Places the four cloth pieces inside the centered content area.
   *
   * The pieces are anchored to the 1280-pixel content column (not to the raw
   * viewport), so an ultrawide window does not leave the ropes off to one side,
   * while vertical anchors are a fraction of the viewport height so the scene
   * does not float in the middle of very tall windows.
   *
   * @param width  Viewport width in game units (usually `FlxG.width`).
   * @param height Viewport height in game units (usually `FlxG.height`).
   * @return Positions in game units.
   */
  public static function scene(width:Int, height:Int):ClothScene
  {
    final safeWidth:Int = width <= 0 ? BASE_WIDTH : width;
    final safeHeight:Int = height <= 0 ? BASE_HEIGHT : height;
    final left:Float = contentLeft(safeWidth);

    // The banner is 300x200 and a rope 20x360, so the two ropes hang from the
    // top-right corner of the content column without overlapping, and the
    // banner sits below them where the pointer can reach it.
    return {
      banner: {
        x: left + 40,
        y: Math.round(safeHeight * 0.40)
      },
      bannerTwo: {
        x: left + 470,
        y: Math.round(safeHeight * 0.18)
      },
      ropeLeft: {
        x: left + 1000,
        y: Math.round(safeHeight * 0.05)
      },
      ropeRight: {
        x: left + 1200,
        y: Math.round(safeHeight * 0.05)
      }
    };
  }
}
