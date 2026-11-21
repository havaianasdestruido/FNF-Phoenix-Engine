package backend;

/** Where one cloth piece is drawn, in 1280x720 game units. */
typedef ClothPiece =
{
  var x:Float;
  var y:Float;
}

/**
 * Rectangle of the menu backdrop a cloth piece is cut from, in texture pixels.
 *
 * Always inside the source texture and always the same aspect ratio as the box
 * the piece fills, so the crop is never stretched to fit.
 */
typedef ClothCrop =
{
  var x:Int;
  var y:Int;
  var width:Int;
  var height:Int;
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
 * These things live here instead of in the substate so they can be checked
 * without Flixel/OpenFL/Lime (see `tests/haxe/ClothEasterEggSpec.hx`):
 *
 * - the hidden key code that opens the scene (`C`, `L`, `O`, `T`, `H` typed on
 *   the main menu, forgotten after {@link SEQUENCE_TIMEOUT} seconds), mirroring
 *   how the other menu easter eggs are triggered;
 * - where the four pieces are placed inside the centered 1280x720 content area,
 *   so the scene keeps fitting widescreen, 4:3 and portrait viewports;
 * - the texture the pieces are cut from ({@link TEXTURE}, the menu backdrop by
 *   default) and the crop rectangle each piece takes from it;
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

  /** `TEXTURE` value meaning "the menu's own `images/menuBG.png`". */
  public static inline var BACKDROP_MENU:String = 'menuBG';

  /** `TEXTURE` value meaning "the old `images/clothFlag.png` / `clothRope.png` art". */
  public static inline var BACKDROP_CLOTH_ART:String = 'clothArt';

  /**
   * Which texture the two banners and two ropes are cut from.
   *
   * `BACKDROP_MENU` (the default) makes the cloth out of the menu's own
   * backdrop, so the scene looks like a sheet of the menu art hanging over the
   * menu, and a mod that replaces `images/menuBG.png` changes both at once.
   * `BACKDROP_CLOTH_ART` cuts the same crops out of the older dedicated
   * `clothFlag`/`clothRope` textures; it is the way back if the scene stops
   * reading well against a future backdrop.
   */
  public static var TEXTURE:String = BACKDROP_MENU;

  /** Aspect ratio of a banner's box: the old 300x200 flag art. */
  public static inline var BANNER_ASPECT:Float = BANNER_WIDTH / BANNER_HEIGHT;

  /** Aspect ratio of a rope's box: the old 20x360 chain art. */
  public static inline var ROPE_ASPECT:Float = ROPE_WIDTH / ROPE_HEIGHT;

  /**
   * Largest side of a cloth piece, as a fraction of the texture's side.
   *
   * Without it a hi-res backdrop would let one piece cut a window the size of
   * the whole menu, which no longer reads as a piece of cloth.
   */
  public static inline var MAX_CROP_SHARE:Float = 0.95;

  /** Where a piece's crop sits in its texture, as fractions of the free space. */
  public static inline var CENTER:Float = 0.5;

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

  /**
   * Key name in the form {@link SEQUENCE} uses: trimmed and upper case.
   *
   * `StringTools` has no `toUpperCase` (that is a `String` method), so the
   * trim happens first and the instance method upper-cases the result.
   */
  public static function normaliseKey(key:String):String
  {
    if (key == null) return '';
    return StringTools.trim(key).toUpperCase();
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
   * Whether the pieces are cut out of the menu backdrop.
   *
   * The scene cuts its pieces out of the menu backdrop, so a mod that replaces
   * `images/menuBG.png` changes the menu and the cloth at the same time. A
   * build or theme without that backdrop (`Paths.image()` answers `null` for a
   * missing image) falls back to the dedicated cloth art, so the scene is never
   * four invisible meshes.
   *
   * @param backdropKey Resolved image key of the menu backdrop, or `null`.
   * @return `false` when {@link TEXTURE} asks for the dedicated art or when
   *         there is no backdrop to cut from.
   */
  public static function usesBackdrop(backdropKey:String):Bool
  {
    if (TEXTURE == BACKDROP_CLOTH_ART) return false;
    return backdropKey != null && backdropKey.length > 0;
  }

  /**
   * Crop of the texture a banner is cut from.
   *
   * The two banners take different slices of the same backdrop, so the scene
   * shows two unrelated parts of the menu art instead of the same rectangle
   * twice: the follower banner sits low and left of it, the wide one high and
   * right.
   *
   * @param textureWidth  Width of the source texture in pixels.
   * @param textureHeight Height of the source texture in pixels.
   * @param wide          `true` for the corner-pinned banner, `false` for the
   *                      pointer-following one.
   * @return A rectangle inside the texture with {@link BANNER_ASPECT}.
   */
  public static function bannerCrop(textureWidth:Int, textureHeight:Int, wide:Bool):ClothCrop
  {
    final crop:ClothCrop = pieceCrop(textureWidth, textureHeight, BANNER_WIDTH, BANNER_HEIGHT);
    // Keep the two banners apart: the follower one hangs below and left of the
    // wide one, which hugs the top-right corner of the backdrop.
    crop.y = freeAxis(textureHeight - crop.height, wide ? 0.0 : 0.66);
    crop.x = freeAxis(textureWidth - crop.width, wide ? 0.66 : 0.34);
    return crop;
  }

  /**
   * Crop of the texture a rope is cut from.
   *
   * The ropes are tall and narrow, so they read as strips of the backdrop; the
   * pair takes two different columns of the texture so they do not look like a
   * copy of each other.
   *
   * @param textureWidth  Width of the source texture in pixels.
   * @param textureHeight Height of the source texture in pixels.
   * @param right         `true` for the right-hand rope.
   * @return A rectangle inside the texture with {@link ROPE_ASPECT}.
   */
  public static function ropeCrop(textureWidth:Int, textureHeight:Int, right:Bool):ClothCrop
  {
    final crop:ClothCrop = pieceCrop(textureWidth, textureHeight, ROPE_WIDTH, ROPE_HEIGHT);
    crop.x = freeAxis(textureWidth - crop.width, right ? 0.85 : 0.15);
    crop.y = freeAxis(textureHeight - crop.height, CENTER);
    return crop;
  }

  /**
   * Window of the backdrop a piece shows, centered and kept at the piece's size.
   *
   * A `FlxClothSprite` draws its mesh over the whole graphic, so the crop is
   * what the piece measures on screen: cutting `pieceWidth x pieceHeight`
   * pixels out of the backdrop puts one piece-sized window of the menu art in
   * the cloth, instead of squashing the entire menu into a small flag.
   *
   * Two rules keep that window honest:
   *
   * - {@link MAX_CROP_SHARE} stops a hi-res backdrop from cutting a window so
   *   big that it is the whole menu again;
   * - a backdrop smaller than the piece is used as far as it goes: the window
   *   shrinks to fit the texture (never outside it, which is what
   *   `BitmapData.copyPixels` throws on) while keeping the piece's ratio, so
   *   the art in it is never stretched.
   *
   * @param textureWidth  Width of the source texture in pixels.
   * @param textureHeight Height of the source texture in pixels.
   * @param pieceWidth    Width the piece is drawn at, in game units.
   * @param pieceHeight   Height the piece is drawn at, in game units.
   * @return A rectangle inside the texture with the piece's aspect ratio.
   */
  public static function pieceCrop(textureWidth:Int, textureHeight:Int, pieceWidth:Int, pieceHeight:Int):ClothCrop
  {
    final safeWidth:Int = textureWidth <= 0 ? 1 : textureWidth;
    final safeHeight:Int = textureHeight <= 0 ? 1 : textureHeight;
    final wantedWidth:Int = pieceWidth <= 0 ? BANNER_WIDTH : pieceWidth;
    final wantedHeight:Int = pieceHeight <= 0 ? BANNER_HEIGHT : pieceHeight;
    final ratio:Float = wantedWidth / wantedHeight;

    // The window starts as the piece's own size, then shrinks by a single scale
    // factor - never per axis - so the art in it is never stretched. It shrinks
    // for MAX_CROP_SHARE (a hi-res backdrop must not turn one piece into the
    // whole menu) and for a texture smaller than the piece (there is nothing
    // more to cut), whichever is tighter.
    final maxWidth:Float = Math.max(1.0, safeWidth * MAX_CROP_SHARE);
    final maxHeight:Float = Math.max(1.0, safeHeight * MAX_CROP_SHARE);
    final scale:Float = Math.min(1.0, Math.min(maxWidth / wantedWidth, maxHeight / wantedHeight));

    var width:Float = wantedWidth * scale;
    var height:Float = wantedHeight * scale;

    // Rounding each side separately can overshoot by a pixel; clamp instead of
    // letting the crop hang past the texture (which throws in BitmapData.copyPixels).
    final cropWidth:Int = clampInt(Math.round(width), 1, safeWidth);
    final cropHeight:Int = clampInt(Math.round(height), 1, safeHeight);

    return {
      x: clampInt(Math.round((safeWidth - cropWidth) * CENTER), 0, safeWidth - cropWidth),
      y: clampInt(Math.round((safeHeight - cropHeight) * CENTER), 0, safeHeight - cropHeight),
      width: cropWidth,
      height: cropHeight
    };
  }

  /**
   * Origin of a crop inside the free space its size leaves in the texture.
   *
   * @param free  Pixels of texture left over on that axis (`size - crop`).
   * @param share 0 = first pixel of the free space, 0.5 = centered, 1 = last.
   * @return A whole-pixel origin that never leaves the texture.
   */
  static function freeAxis(free:Int, share:Float):Int
  {
    if (free <= 0) return 0;
    final ratio:Float = Math.isNaN(share) ? CENTER : (share < 0 ? 0 : (share > 1 ? 1 : share));
    return clampInt(Math.round(ratio * free), 0, free);
  }

  /** Whole number inside `low`..`high`; a reversed range collapses to `low`. */
  static function clampInt(value:Int, low:Int, high:Int):Int
  {
    if (high < low) return low;
    return value < low ? low : (value > high ? high : value);
  }

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
