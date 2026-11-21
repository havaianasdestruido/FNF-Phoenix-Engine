package states.substates;

import backend.ClothEasterEggLogic;
import backend.ClothEasterEggLogic.ClothCrop;
import backend.ClothEasterEggLogic.ClothScene;
import backend.ClientPrefs;
import backend.MusicBeatSubstate;
import backend.Paths;
import backend.ViewportVisuals;
import flixel.FlxCamera;
import flixel.addons.effects.FlxClothSprite;
import flixel.graphics.FlxGraphic;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.util.FlxColor;
import flixel.util.FlxDirectionFlags;
import openfl.geom.Point;

/**
 * Main-menu easter egg: the cloth pieces from the
 * [HaxeFlixel `FlxClothSprite` demo](https://haxeflixel.com/demos/FlxClothSprite/)
 * hanging over the menu and reacting to the pointer.
 *
 * Typing `C`, `L`, `O`, `T`, `H` on `states.MainMenuState` (builds with
 * `FUNNY_ALLOWED`, i.e. desktop) opens this substate; see
 * {@link backend.ClothEasterEggLogic} for the code itself. While it is open:
 *
 * - moving the pointer drags the left banner along with it;
 * - holding the pointer down blows wind through every piece;
 * - `BACK` (escape, a gamepad bind or the virtual pad) returns to the menu
 *   exactly where it was.
 *
 * The menu is the parent state and keeps running underneath: its music, tips and
 * selection are untouched, and none of its cameras are switched off. The scene
 * draws on a camera added on top of the menu's stack, over a half-transparent
 * black backdrop, so nothing has to be screenshotted and the effect works on
 * every render target. Positions, gravity and wind come from
 * `backend.ClothEasterEggLogic` and are spec-tested without Flixel
 * (`tests/haxe/ClothEasterEggSpec.hx`).
 *
 * Art: the pieces are cut out of the menu's own backdrop
 * (`assets/preload/images/menuBG.png`, or whatever mod replaces it), so the
 * cloth is a sheet of the menu art hanging over the menu. The dedicated
 * `clothFlag.png` / `clothRope.png` art stays as the fallback when a build has no
 * backdrop and behind `ClothEasterEggLogic.TEXTURE`. No asset or source file is
 * taken from the HaxeFlixel demo; only the behaviour is
 * modeled on it (author of `FlxClothSprite`: adrianulima).
 */
class ClothEasterEggSubstate extends MusicBeatSubstate
{
  /** Camera drawn above the menu's cameras; owned and removed by this substate. */
  var clothCam:FlxCamera;

  /** Banner that follows the pointer, pinned along its left edge. */
  var banner:FlxClothSprite;

  /** Banner pinned at both top corners by explicit indices, like the demo. */
  var bannerTwo:FlxClothSprite;

  /** Rope hanging from the top of the screen, one on each side. */
  var ropeLeft:FlxClothSprite;
  var ropeRight:FlxClothSprite;

  /** Dimming layer that makes the cloth readable over the menu art. */
  var backdrop:FlxSprite;

  /** Controls hint along the bottom edge. */
  var hint:FlxText;

  /** Set once the scene starts closing, so one press cannot close it twice. */
  var closing:Bool = false;

  /** `FlxG.mouse.visible` from before the scene took over the pointer. */
  var previousMouseVisible:Bool = false;

  /** Reused pointer position, already translated into {@link clothCam} space. */
  var pointer:FlxPoint = FlxPoint.get();

  /**
   * Cropped slice of the backdrop each piece is drawn from.
   *
   * The pieces are their only users, so {@link destroy} releases them: a hi-res
   * backdrop can make four of these a few megabytes.
   */
  var pieceGraphics:Array<FlxGraphic> = [];

  override function create():Void
  {
    clothCam = new FlxCamera();
    clothCam.bgColor.alpha = 0;
    FlxG.cameras.add(clothCam, false);

    // Everything this substate owns draws on that camera only, so the menu's
    // own cameras (and whatever a mod added to them) are left untouched.
    cameras = [clothCam];

    backdrop = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
    backdrop.scrollFactor.set();
    backdrop.alpha = 0.55;
    add(backdrop);

    final scene:ClothScene = ClothEasterEggLogic.scene(FlxG.width, FlxG.height);
    final gravity:Float = ClothEasterEggLogic.gravity(ClientPrefs.reducedMotion);

    // Where the cloth comes from: the menu's own backdrop by default, so each
    // piece is a window of the art the player is standing in front of and a mod
    // that replaces `menuBG` replaces the cloth with it. A build without that
    // image falls back to the dedicated cloth art, and
    // `ClothEasterEggLogic.TEXTURE` can force it (see `docs/CLOTH_EASTER_EGG.md`).
    final sourceGraphic:FlxGraphic = ClothEasterEggLogic.usesBackdrop(ClothEasterEggLogic.BACKDROP_MENU)
      ? Paths.image(ClothEasterEggLogic.BACKDROP_MENU) : null;

    // The demo's three configurations, in the same order: a mouse-following
    // flag pinned on its left edge, a flag pinned at both top corners with
    // crossing constraints and a denser mesh, and two ropes whose 2-column
    // crossing mesh bends like rope instead of sheeting.
    banner = createPiece(sourceGraphic, 'clothFlag', false, FlxDirectionFlags.LEFT, false);
    banner.setMesh(10, 10);
    banner.maxVelocity.set(ClothEasterEggLogic.BANNER_MAX_VELOCITY, ClothEasterEggLogic.BANNER_MAX_VELOCITY);
    banner.meshVelocity.y = gravity;
    banner.setPosition(scene.banner.x, scene.banner.y);
    add(banner);

    // `meshScale` has to be set before `setMesh()`, which reads it to size the
    // squares. `NONE` plus the explicit pinned indices is what the demo does:
    // only the two top corners are held, so the banner sags into a hammock.
    bannerTwo = createPiece(sourceGraphic, 'clothFlag', true, FlxDirectionFlags.NONE, false);
    bannerTwo.meshScale.set(1.5, 1);
    bannerTwo.setMesh(15, 10, 0, 0, [0, 14]);
    bannerTwo.iterations = 8;
    bannerTwo.maxVelocity.set(ClothEasterEggLogic.BANNER_MAX_VELOCITY, ClothEasterEggLogic.BANNER_MAX_VELOCITY);
    bannerTwo.meshVelocity.y = gravity;
    bannerTwo.setPosition(scene.bannerTwo.x, scene.bannerTwo.y);
    add(bannerTwo);

    ropeLeft = createPiece(sourceGraphic, 'clothRope', false, FlxDirectionFlags.UP, true);
    ropeLeft.setMesh(2, 10);
    ropeLeft.maxVelocity.set(ClothEasterEggLogic.ROPE_MAX_VELOCITY, ClothEasterEggLogic.ROPE_MAX_VELOCITY);
    ropeLeft.meshVelocity.y = gravity;
    ropeLeft.setPosition(scene.ropeLeft.x, scene.ropeLeft.y);
    add(ropeLeft);

    ropeRight = createPiece(sourceGraphic, 'clothRope', true, FlxDirectionFlags.UP, true);
    ropeRight.setMesh(2, 10);
    ropeRight.maxVelocity.set(ClothEasterEggLogic.ROPE_MAX_VELOCITY, ClothEasterEggLogic.ROPE_MAX_VELOCITY);
    ropeRight.meshVelocity.y = gravity;
    ropeRight.setPosition(scene.ropeRight.x, scene.ropeRight.y);
    add(ropeRight);

    // A single auto-sized line (no `fieldWidth`) that `onResize()` centers: a
    // fixed field width would need re-measuring on every window size, and an
    // auto-sized two-line field left-aligns the lines it wraps.
    hint = new FlxText(0, 0, 0, 'FlxClothSprite  -  move the pointer to drag, hold it to blow wind, ESC to leave');
    hint.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.WHITE, FlxTextAlign.LEFT);
    hint.scrollFactor.set();
    hint.updateHitbox();
    add(hint);

    onResize(FlxG.width, FlxG.height);

    #if !FLX_NO_MOUSE
    // The scene is driven by the pointer, so the cursor has to be back - and
    // put back exactly as it was when the scene ends (menus normally hide it).
    previousMouseVisible = FlxG.mouse.visible;
    FlxG.mouse.visible = true;
    #end

    super.create();
  }

  override public function onResize(width:Int, height:Int):Void
  {
    super.onResize(width, height);
    if (backdrop != null) ViewportVisuals.fill(backdrop);
    if (hint != null)
    {
      hint.y = height - hint.height - 18;
      hint.x = Math.max(0, (width - hint.width) * 0.5);
    }

    // Resizing re-anchors the fixed pieces; the pointer-following banner keeps
    // whatever position the player dragged it to, pulled back on screen.
    if (banner != null && bannerTwo != null && ropeLeft != null && ropeRight != null)
    {
      final scene:ClothScene = ClothEasterEggLogic.scene(width, height);
      bannerTwo.setPosition(scene.bannerTwo.x, scene.bannerTwo.y);
      ropeLeft.setPosition(scene.ropeLeft.x, scene.ropeLeft.y);
      ropeRight.setPosition(scene.ropeRight.x, scene.ropeRight.y);
      banner.setPosition(FlxMath.bound(banner.x, 0, Math.max(0, width - banner.frameWidth)),
        FlxMath.bound(banner.y, 0, Math.max(0, height - banner.frameHeight)));
    }

    if (clothCam != null) clothCam.setSize(width, height);
  }

  /**
   * Builds one cloth piece out of a window of the menu backdrop.
   *
   * The texture is chosen by {@link ClothEasterEggLogic.usesBackdrop}: the menu
   * backdrop when there is one, the piece's own dedicated art otherwise. The
   * window comes from {@link ClothEasterEggLogic.bannerCrop} /
   * {@link ClothEasterEggLogic.ropeCrop}, and a texture too small to cut still
   * yields a piece drawn from the whole image instead of nothing at all.
   *
   * A `FlxClothSprite` draws its mesh at the size of the graphic it was given,
   * so the crop doubles as the piece's on-screen size: the scene layout keeps
   * using `BANNER_WIDTH`/`ROPE_HEIGHT`, and the crop is cut to exactly that.
   *
   * @param source     Resolved menu backdrop, or `null` when the build has none.
   * @param artKey     Dedicated art of this piece (`clothFlag`, `clothRope`),
   *                   used when {@link ClothEasterEggLogic.TEXTURE} asks for it
   *                   and when there is no backdrop to cut from.
   * @param second     `true` for the second member of a pair (the wide banner,
   *                   the right rope), so the two take different crops.
   * @param pinnedSide Edge of the mesh that wind or gravity cannot move. Only
   *                   the top edge (`FlxDirectionFlags.UP`) and the left edge
   *                   (`FlxDirectionFlags.LEFT`) are used here.
   * @param crossing   Adds the two diagonal constraints per square, which makes
   *                   a narrow mesh bend like a rope instead of stretching.
   * @return A 2x2 mesh piece; callers reshape it with `setMesh()`.
   */
  function createPiece(source:FlxGraphic, artKey:String, second:Bool, pinnedSide:FlxDirectionFlags, crossing:Bool):FlxClothSprite
  {
    // The menu backdrop when this build has one and the scene is not pinned to
    // the old art, otherwise the piece's own dedicated texture.
    final texture:FlxGraphic = ClothEasterEggLogic.usesBackdrop(source == null ? null : source.key) ? source : Paths.image(artKey);
    final cropped:FlxGraphic = (texture == null) ? null : cropGraphic(texture, artKey, second);

    var piece:FlxClothSprite;
    if (cropped != null)
      piece = new FlxClothSprite(0, 0, cropped, 2, 2, pinnedSide, crossing);
    else
      // Nothing to cut from: draw the texture whole rather than hand the mesh a
      // null graphic, which would leave an invisible piece behind.
      piece = new FlxClothSprite(0, 0, texture, 2, 2, pinnedSide, crossing);

    piece.antialiasing = ClientPrefs.globalAntialiasing;
    // Screen-space scene: the menu camera below may be scrolled/zoomed.
    piece.scrollFactor.set();
    return piece;
  }

  /**
   * Cuts a piece-sized window out of a texture.
   *
   * The result is cached by Flixel under a unique key and tracked here, so
   * {@link destroy} can release it: the pieces are the only users of these
   * graphics, and a wide or hi-res backdrop can make them a few megabytes.
   *
   * @param texture Texture to cut from.
   * @param artKey  `clothFlag` / `clothRope`, which picks the window's size and
   *                aspect ratio.
   * @param second  `true` for the second member of a pair.
   * @return The cropped graphic, or `null` when the texture has no pixels to
   *         cut (a 0x0 placeholder), in which case the caller draws it whole.
   */
  function cropGraphic(texture:FlxGraphic, artKey:String, second:Bool):FlxGraphic
  {
    if (texture == null || texture.bitmap == null || texture.width < 1 || texture.height < 1) return null;

    final banner:Bool = artKey != 'clothRope';
    final crop:ClothCrop = banner
      ? ClothEasterEggLogic.bannerCrop(texture.width, texture.height, second)
      : ClothEasterEggLogic.ropeCrop(texture.width, texture.height, second);
    if (crop.width < 1 || crop.height < 1) return null;

    // Never cut a window that is the whole texture: `copyPixels` would only
    // duplicate it, and the piece can draw the original graphic directly.
    if (crop.width == texture.width && crop.height == texture.height) return null;

    final bitmap:BitmapData = new BitmapData(crop.width, crop.height, true, 0);
    try
    {
      // `mergeAlpha` is required whenever either bitmap is transparent (the
      // destination always is here), and a themed backdrop usually is too.
      bitmap.copyPixels(texture.bitmap, new Rectangle(crop.x, crop.y, crop.width, crop.height), new Point(0, 0), null, null, true);
    }
    catch (e:Dynamic)
    {
      // A backdrop that refuses to be copied (an unsupported or disposed
      // bitmap) is no reason to drop the easter egg: the pieces draw the
      // texture whole instead, which is exactly the fallback below.
      bitmap.dispose();
      return null;
    }
    // A free `cloth:*` key keeps the crop out of any other graphic's cache slot,
    // so destroying it in `destroy()` cannot take the menu's own backdrop down
    // with it. Not `unique`, which would clone the bitmap a second time: this
    // graphic owns the copy above, and nothing else references it.
    final cropped:FlxGraphic = FlxG.bitmap.add(bitmap, false, FlxG.bitmap.getUniqueKey('cloth:${artKey}:${second ? 2 : 1}'));
    if (cropped == null)
    {
      // The cache refused the bitmap (no graphic could be created): the piece
      // draws the source texture whole instead, and the copy is freed here.
      bitmap.dispose();
      return null;
    }
    pieceGraphics.push(cropped);
    return cropped;
  }

  override public function update(elapsed:Float):Void
  {
    if (closing)
    {
      super.update(elapsed);
      return;
    }

    if (controls.BACK)
    {
      closing = true;
      close();
      return;
    }

    // Same trick as the demo: put the banner's top-left corner under the
    // pointer (lifted by half its height, so the cursor holds its middle) and
    // hand the remaining movement to `velocity`, which the cloth mesh reads as
    // wind. `FlxMath.bound` keeps the whole banner on screen, where the demo
    // would happily let it hang off the edge and out of reach.
    var wind:Bool = false;
    #if !FLX_NO_MOUSE
    // `FlxG.mouse.x/screenX` are relative to the *main* camera, and the menu
    // camera pans and zooms on every beat, so ask the pointer where it is on
    // the overlay camera instead.
    FlxG.mouse.getScreenPosition(clothCam, pointer);
    final targetX:Float = FlxMath.bound(pointer.x, 0, Math.max(0, FlxG.width - banner.frameWidth));
    final targetY:Float = FlxMath.bound(pointer.y - banner.frameHeight * 0.5, 0,
      Math.max(0, FlxG.height - banner.frameHeight));
    banner.velocity.set(targetX - banner.x, targetY - banner.y);
    banner.setPosition(targetX, targetY);
    wind = FlxG.mouse.pressed;
    #end

    banner.meshVelocity.x = wind ? ClothEasterEggLogic.wind(FlxG.random.float(0, 1), banner.maxVelocity.x) : 0;
    bannerTwo.meshVelocity.x = wind ? ClothEasterEggLogic.wind(FlxG.random.float(0, 1), bannerTwo.maxVelocity.x) : 0;
    ropeLeft.meshVelocity.x = wind ? ClothEasterEggLogic.wind(FlxG.random.float(0, 1), ropeLeft.maxVelocity.x) : 0;
    ropeRight.meshVelocity.x = wind ? ClothEasterEggLogic.wind(FlxG.random.float(0, 1), ropeRight.maxVelocity.x) : 0;

    super.update(elapsed);
  }

  override function destroy():Void
  {
    #if !FLX_NO_MOUSE
    if (FlxG.mouse != null) FlxG.mouse.visible = previousMouseVisible;
    #end

    pointer = FlxDestroyUtil.put(pointer);

    // The pieces are the only users of their cropped graphics. `FlxClothSprite`
    // draws into its own mesh bitmap and does not dispose the graphic it was
    // given, and the crop holds a full copy of the backdrop's pixels, so drop
    // them here instead of leaving them in the cache until the next state
    // change. The menu's own backdrop is not in this list and is never touched.
    for (graphic in pieceGraphics) if (graphic != null && !graphic.isDestroyed) FlxG.bitmap.remove(graphic);
    pieceGraphics = [];

    if (clothCam != null)
    {
      FlxG.cameras.remove(clothCam);
      clothCam = null;
    }
    super.destroy();
  }
}
