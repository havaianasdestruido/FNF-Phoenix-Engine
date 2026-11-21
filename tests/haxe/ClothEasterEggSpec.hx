import backend.ClothEasterEggLogic;
import backend.ClothEasterEggLogic.ClothCrop;
import backend.ClothEasterEggLogic.ClothScene;

/**
 * Renderer-free contract for the `FlxClothSprite` easter egg's hidden key code,
 * scene layout, texture crops and mesh numbers
 * (`source/backend/ClothEasterEggLogic.hx`).
 *
 * Run with: `bash tests/haxe/run-cloth-easter-egg.sh`
 */
class ClothEasterEggSpec
{
  static var failures:Int = 0;

  /** Cloth art sizes, kept in the logic module so the art and this spec agree. */
  static inline var BANNER_WIDTH:Float = ClothEasterEggLogic.BANNER_WIDTH;

  static inline var BANNER_HEIGHT:Float = ClothEasterEggLogic.BANNER_HEIGHT;
  static inline var ROPE_WIDTH:Float = ClothEasterEggLogic.ROPE_WIDTH;
  static inline var ROPE_HEIGHT:Float = ClothEasterEggLogic.ROPE_HEIGHT;

  /**
   * The texture the pieces are cut from in every crop check: the shipped
   * `menuBG.png` (1286x730), so the spec exercises the real backdrop rather
   * than a square placeholder.
   */
  static inline var MENU_BG_WIDTH:Int = 1286;

  static inline var MENU_BG_HEIGHT:Int = 730;

  static function main():Void
  {
    sequenceOpens();
    sequenceForgivesMistakes();
    sequenceTimesOut();
    keyNamesNormalise();
    gravityRespondsToReducedMotion();
    windClamps();
    sceneStaysInsideTheContentColumn();
    piecesAreCutFromTheMenuBackdrop();
    cropsStayInsideEveryTexture();
    cropsSurviveBrokenTextures();

    if (failures > 0) throw '$failures cloth easter egg check(s) failed';
    Sys.println('ClothEasterEggSpec: PASS');
  }

  /* ------------------------------------------------------------------ *
   * Typing C-L-O-T-H in order completes the code exactly once.
   * ------------------------------------------------------------------ */
  static function sequenceOpens():Void
  {
    var progress:Int = 0;
    for (letter in ClothEasterEggLogic.SEQUENCE)
      progress = ClothEasterEggLogic.advance(progress, letter, 0.1);

    check(ClothEasterEggLogic.isComplete(progress), 'typing every letter opens the scene');

    // Staying complete is stable: extra keys cannot push it out of range.
    equal(ClothEasterEggLogic.advance(progress, 'X', 0.1), progress, 'a complete code stays complete');
  }

  /* ------------------------------------------------------------------ *
   * Partial progress is kept, and restarting is one key away.
   * ------------------------------------------------------------------ */
  static function sequenceForgivesMistakes():Void
  {
    final L = ClothEasterEggLogic;

    equal(L.advance(0, 'C', 0), 1, 'the first letter starts the code');
    equal(L.advance(1, 'L', 0), 2, 'the second letter advances it');
    equal(L.advance(2, 'Z', 0), 0, 'a wrong letter clears the progress');
    equal(L.advance(3, 'C', 0), 1, 'the first letter always restarts');
    equal(L.advance(4, 'L', 0), 0, 'a later letter out of order does not count');

    // Out-of-range callers (a state reloaded mid-code) start from scratch
    // instead of reading past the array.
    equal(L.advance(-3, 'C', 0), 1, 'negative progress restarts');
    equal(L.advance(99, 'C', 0), 1, 'progress past the sequence restarts');
    equal(L.advance(2, null, 0), 2, 'no key press keeps the progress');
    equal(L.advance(2, '', 0), 2, 'an empty key name keeps the progress');
  }

  /* ------------------------------------------------------------------ *
   * An unfinished code expires; a completed one is not affected.
   * ------------------------------------------------------------------ */
  static function sequenceTimesOut():Void
  {
    final L = ClothEasterEggLogic;

    equal(L.advance(3, 'T', L.SEQUENCE_TIMEOUT), 4, 'the timeout boundary still counts as fresh');
    equal(L.advance(3, 'T', L.SEQUENCE_TIMEOUT + 0.01), 0, 'a slow typist has to start over');
    equal(L.advance(3, 'C', L.SEQUENCE_TIMEOUT + 5), 1, 'the restart letter works after a timeout');

    // A slow first key is fine: there is nothing to expire yet.
    equal(L.advance(0, 'C', 60), 1, 'the first key never expires');
  }

  /** Key names arrive from input formatting, so case and padding are ignored. */
  static function keyNamesNormalise():Void
  {
    final L = ClothEasterEggLogic;

    equal(L.normaliseKey('c'), 'C', 'lower case keys upper case');
    equal(L.normaliseKey(' t '), 'T', 'padding is trimmed');
    equal(L.normaliseKey(null), '', 'a missing key is empty');
    equal(L.advance(0, ' c ', 0), 1, 'a lowercase key still advances the code');
  }

  /* ------------------------------------------------------------------ *
   * Reduced Motion keeps the cloth alive without the heavy drift.
   * ------------------------------------------------------------------ */
  static function gravityRespondsToReducedMotion():Void
  {
    final L = ClothEasterEggLogic;

    close(L.gravity(false), L.GRAVITY, 'normal builds use the full gravity');
    close(L.gravity(true), L.REDUCED_MOTION_GRAVITY, 'reduced motion lowers gravity');
    check(L.REDUCED_MOTION_GRAVITY > 0, 'reduced motion must not freeze the mesh');
    check(L.REDUCED_MOTION_GRAVITY < L.GRAVITY, 'reduced motion is quieter than the default');
    check(L.ROPE_MAX_VELOCITY < L.BANNER_MAX_VELOCITY, 'ropes sway less than the banner');
  }

  /** Wind is a 0..1 sample times the piece's ceiling, never NaN. */
  static function windClamps():Void
  {
    final L = ClothEasterEggLogic;

    close(L.wind(0, 200), 0, 'no wind at 0');
    close(L.wind(1, 200), 200, 'full wind at 1');
    close(L.wind(0.5, 40), 20, 'wind scales with the ceiling');
    close(L.wind(-2, 200), 0, 'negative samples clamp to no wind');
    close(L.wind(7, 200), 200, 'samples above 1 clamp to the ceiling');
    close(L.wind(Math.NaN, 200), 0, 'NaN cannot launch the mesh');
  }

  /* ------------------------------------------------------------------ *
   * Every piece sits inside the centered 1280-wide content column, at
   * every viewport the engine supports (4:3, 16:9 and ultrawide).
   * ------------------------------------------------------------------ */
  static function sceneStaysInsideTheContentColumn():Void
  {
    final L = ClothEasterEggLogic;

    final viewports:Array<Array<Int>> = [[1280, 720], [960, 720], [1920, 720], [2560, 1080], [720, 1280]];

    for (viewport in viewports)
    {
      final width:Int = viewport[0];
      final height:Int = viewport[1];
      final scene:ClothScene = L.scene(width, height);
      final left:Float = L.contentLeft(width);
      final label:String = '${width}x${height}';

      for (piece in [scene.banner, scene.bannerTwo, scene.ropeLeft, scene.ropeRight])
      {
        check(piece.x >= left, '$label: piece at ${piece.x} starts inside the content column');
        check(piece.x <= left + L.BASE_WIDTH, '$label: piece at ${piece.x} stays inside the content column');
        check(piece.y >= 0, '$label: piece at ${piece.y} is on screen');
        check(piece.y <= height, '$label: piece at ${piece.y} is above the bottom edge');
      }

      check(scene.ropeLeft.x < scene.ropeRight.x, '$label: the ropes keep their left/right order');
      check(scene.banner.y > scene.ropeLeft.y, '$label: the banner hangs below the ropes');

      // The art is 300x200 for a banner and 20x360 for a rope; nothing may be
      // drawn past the right edge of the content column or the bottom of a
      // short window (a rope hanging off screen would never be pulled back).
      check(scene.banner.x + BANNER_WIDTH <= left + L.BASE_WIDTH, '$label: the banner fits horizontally');
      check(scene.bannerTwo.x + BANNER_WIDTH * 1.5 <= left + L.BASE_WIDTH, '$label: the wide banner fits horizontally');
      check(scene.ropeRight.x + ROPE_WIDTH <= left + L.BASE_WIDTH, '$label: the right rope fits horizontally');
      check(scene.ropeLeft.y + ROPE_HEIGHT <= height, '$label: the ropes fit vertically');
      check(scene.banner.y + BANNER_HEIGHT <= height, '$label: the banner fits vertically');
    }

    // The 1280x720 baseline is the layout the scene is authored for.
    final base:ClothScene = L.scene(1280, 720);
    close(base.banner.x, 40, 'baseline banner x');
    close(base.ropeRight.x, 1200, 'baseline right rope x');

    // A broken viewport cannot produce NaN positions.
    final broken:ClothScene = L.scene(0, 0);
    check(!Math.isNaN(broken.banner.x) && !Math.isNaN(broken.banner.y), 'a 0x0 viewport falls back to the baseline');

    // Ultrawide windows shift the whole scene with the content column.
    final wide:ClothScene = L.scene(1920, 720);
    close(wide.banner.x - base.banner.x, 320, 'ultrawide shifts the scene by the content offset');
  }

  /* ------------------------------------------------------------------ *
   * The pieces come from the menu backdrop, and fall back to the old art
   * when a build (or a mod) has no `menuBG`.
   * ------------------------------------------------------------------ */
  static function piecesAreCutFromTheMenuBackdrop():Void
  {
    final L = ClothEasterEggLogic;
    final previous:String = L.TEXTURE;

    L.TEXTURE = L.BACKDROP_MENU;
    check(L.usesBackdrop('menuBG'), 'the pieces are cut from the menu backdrop by default');
    check(L.usesBackdrop('mods/some-mod:menuBG'), 'a mod-resolved backdrop key is used too');
    check(!L.usesBackdrop(null), 'a build without menuBG falls back to the cloth art');
    check(!L.usesBackdrop(''), 'an empty backdrop key falls back to the cloth art');

    // The escape hatch: the dedicated textures, whatever the build ships.
    L.TEXTURE = L.BACKDROP_CLOTH_ART;
    check(!L.usesBackdrop('menuBG'), 'cloth art mode ignores the menu backdrop');

    L.TEXTURE = previous;
  }

  /* ------------------------------------------------------------------ *
   * Every crop is inside the texture and keeps the piece's aspect ratio,
   * so the mesh never draws a stretched or out-of-bounds slice.
   * ------------------------------------------------------------------ */
  static function cropsStayInsideEveryTexture():Void
  {
    final L = ClothEasterEggLogic;

    // Real backdrop, a 16:9, a 4:3, a portrait and a square texture.
    final textures:Array<Array<Int>> = [
      [MENU_BG_WIDTH, MENU_BG_HEIGHT], [1280, 720], [1024, 768], [720, 1280], [512, 512]
    ];

    for (texture in textures)
    {
      final width:Int = texture[0];
      final height:Int = texture[1];
      final label:String = '${width}x$height';

      final crops:Array<ClothCrop> = [
        L.bannerCrop(width, height, false),
        L.bannerCrop(width, height, true),
        L.ropeCrop(width, height, false),
        L.ropeCrop(width, height, true)
      ];
      final aspects:Array<Float> = [L.BANNER_ASPECT, L.BANNER_ASPECT, L.ROPE_ASPECT, L.ROPE_ASPECT];
      final names:Array<String> = ['follower banner', 'wide banner', 'left rope', 'right rope'];

      for (i in 0...crops.length)
      {
        final crop:ClothCrop = crops[i];
        check(crop.width > 0 && crop.height > 0, '$label: the ${names[i]} crop has pixels');
        check(crop.x >= 0 && crop.y >= 0, '$label: the ${names[i]} crop starts inside the texture');
        check(crop.x + crop.width <= width, '$label: the ${names[i]} crop fits horizontally');
        check(crop.y + crop.height <= height, '$label: the ${names[i]} crop fits vertically');
        checkNear(crop.width / crop.height, aspects[i], 0.05, '$label: the ${names[i]} crop keeps its aspect');
      }

      // The two banners and the two ropes must not be the same rectangle, or the
      // scene would show the same slice of the backdrop four times.
      check(!sameCrop(crops[0], crops[1]), '$label: the two banners take different slices');
      check(!sameCrop(crops[2], crops[3]), '$label: the two ropes take different slices');
      check(crops[2].x < crops[3].x, '$label: the left rope cuts further left than the right one');
    }

    // The pieces keep the size they are drawn at, so a `FlxClothSprite` (which
    // draws its mesh at the graphic's size) still fills the same box on screen.
    final banner:ClothCrop = L.bannerCrop(MENU_BG_WIDTH, MENU_BG_HEIGHT, false);
    equal(banner.width, L.BANNER_WIDTH, 'the banner crop is as wide as the banner is drawn');
    equal(banner.height, L.BANNER_HEIGHT, 'the banner crop is as tall as the banner is drawn');

    final rope:ClothCrop = L.ropeCrop(MENU_BG_WIDTH, MENU_BG_HEIGHT, false);
    equal(rope.width, L.ROPE_WIDTH, 'the rope crop is as wide as the rope is drawn');
    equal(rope.height, L.ROPE_HEIGHT, 'the rope crop is as tall as the rope is drawn');
  }

  /* ------------------------------------------------------------------ *
   * A 0x0, a sliver or a huge texture cannot produce a crop the mesh or
   * `BitmapData.copyPixels` chokes on.
   * ------------------------------------------------------------------ */
  static function cropsSurviveBrokenTextures():Void
  {
    final L = ClothEasterEggLogic;

    for (size in [[0, 0], [-5, 40], [3, 0], [3, 1000], [4096, 4096]])
    {
      final width:Int = size[0];
      final height:Int = size[1];
      final crop:ClothCrop = L.bannerCrop(width, height, false);
      check(crop.width >= 1 && crop.height >= 1, 'a ${width}x$height texture still yields a crop with pixels');
      check(crop.x >= 0 && crop.y >= 0, 'a ${width}x$height texture keeps the crop at the origin');
      check(crop.width <= Math.max(1, width) && crop.height <= Math.max(1, height),
        'a ${width}x$height texture is not cropped past its edge');
      check(crop.x + crop.width <= Math.max(1, width), 'a ${width}x$height texture keeps the crop inside it');
    }

    // A backdrop smaller than a piece is used whole; the piece shrinks with it
    // rather than asking for pixels that are not there.
    final sliver:ClothCrop = L.ropeCrop(3, 40, false);
    check(sliver.width <= 3 && sliver.height <= 40, 'a sliver texture keeps the whole crop inside it');
    check(sliver.width < sliver.height, 'a sliver texture still yields a vertical rope');

    // A huge backdrop cannot cut a window bigger than MAX_CROP_SHARE of it.
    final huge:ClothCrop = L.bannerCrop(4096, 4096, true);
    check(huge.width <= 4096 * L.MAX_CROP_SHARE && huge.height <= 4096 * L.MAX_CROP_SHARE,
      'a huge texture caps the crop at MAX_CROP_SHARE');

    // A 0 aspect or a NaN size falls back to the banner box instead of dividing
    // by zero, and a zero-size piece still gets a rectangle with pixels.
    final broken:ClothCrop = L.pieceCrop(400, 400, 0, 0);
    check(broken.width > 0 && broken.height > 0, 'a zero-size piece still gets a crop with pixels');
    check(!Math.isNaN(broken.width / broken.height), 'a zero-size piece still yields a real crop');
  }

  /* ------------------------------------------------------------------ */

  /** True when two crops cover exactly the same rectangle. */
  static function sameCrop(a:ClothCrop, b:ClothCrop):Bool
  {
    return a.x == b.x && a.y == b.y && a.width == b.width && a.height == b.height;
  }

  /** Fails when two floats differ by more than `tolerance`. */
  static function checkNear(actual:Float, expected:Float, tolerance:Float, label:String):Void
  {
    if (!Math.isNaN(actual) && Math.abs(actual - expected) <= tolerance) return;
    failures++;
    Sys.println('FAILED: $label (expected $expected, got $actual)');
  }

  static function check(ok:Bool, label:String):Void
  {
    if (ok) return;
    failures++;
    Sys.println('FAILED: $label');
  }

  static function equal<T>(actual:T, expected:T, label:String):Void
  {
    if (actual == expected) return;
    failures++;
    Sys.println('FAILED: $label (expected $expected, got $actual)');
  }

  static function close(actual:Float, expected:Float, label:String):Void
  {
    if (Math.abs(actual - expected) <= 0.0001) return;
    failures++;
    Sys.println('FAILED: $label (expected $expected, got $actual)');
  }
}
