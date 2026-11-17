package objects;

import backend.ClientPrefs;
import backend.MenuCheckerTextures;
import backend.Paths;
import flixel.addons.display.FlxBackdrop;
import flixel.graphics.FlxGraphic;
import flixel.util.FlxAxes;
import flixel.util.FlxColor;

/**
 * A lightweight, endlessly tiled menu backdrop.
 *
 * The visual is inspired by the moving checkerboards in Mic'd Up! Engine's
 * menus (Verwex/Funkin-Mic-d-Up-SC). This implementation is original and uses
 * Phoenix's existing neutral checker tile so each menu can tint one shared
 * asset instead of shipping a separate texture for every color.
 *
 * The tile itself is a preference: `ClientPrefs.menuCheckerTexture` picks one of
 * the `images/checker*.png` variants (Super Secret Debug Menu -> Menu Checker
 * Texture), and every live instance swaps to it through `refreshAll()`.
 */
class MovingCheckerboard extends FlxBackdrop
{
  /** Mic'd Up!'s main-menu movement converted from pixels/frame to pixels/s. */
  public static inline final DEFAULT_SPEED_X:Float = -27;
  public static inline final DEFAULT_SPEED_Y:Float = -9.6;

  static final instances:Array<MovingCheckerboard> = [];

  final motionX:Float;
  final motionY:Float;

  /** Key of the tile this instance repeats right now (`images/<key>.png`). */
  public var textureKey(default, null):String;

  /**
   * Creates a checkerboard that fills the current camera in both directions.
   *
   * @param tint color multiplied over the shared white checker tile.
   * @param speedX horizontal movement in pixels per second.
   * @param speedY vertical movement in pixels per second.
   * @param tileScale scale of the repeated 120x120 tile.
   * @param opacity overall opacity in addition to the tile's baked alpha.
   */
  public function new(tint:FlxColor = FlxColor.WHITE, speedX:Float = DEFAULT_SPEED_X,
      speedY:Float = DEFAULT_SPEED_Y, tileScale:Float = 2, opacity:Float = 1)
  {
    // The tile is a preference, so `refreshPreference()` below loads it instead
    // of the backdrop being handed a graphic here.
    super(null, FlxAxes.XY);

    motionX = speedX;
    motionY = speedY;
    color = tint;
    alpha = opacity;
    scale.set(tileScale, tileScale);
    updateHitbox();
    scrollFactor.set(0, 0.07);
    antialiasing = ClientPrefs.globalAntialiasing;

    instances.push(this);
    refreshPreference(); // also loads the preferred tile
  }

  /**
   * Every checker tile this build can offer, sorted with the default tile first.
   *
   * The shipped variants (`MenuCheckerTextures.BUILT_IN`) plus whatever the
   * preload images folder holds, so a `checker_*.png` that a content update adds
   * reaches the Super Secret Debug Menu without a code change. A mod can still
   * replace the pixels of any of these keys: `Paths.image()` resolves mod
   * folders before the engine's own assets.
   */
  public static function availableTextures():Array<String>
  {
    // Two spellings of the same folder: `assets/preload/images` is where the
    // tiles live on disk (loose-file builds) and `assets/images` is how the
    // embedded `preload` library exposes them (see project.hxp's addAssetPath).
    // Whichever the target cannot read simply contributes nothing.
    return MenuCheckerTextures.collect([
      listImageFolder('assets/preload/images'),
      listImageFolder(Paths.getPreloadPath('images'))
    ]);
  }

  /** Names inside an images folder; empty on a target that has no such folder. */
  static function listImageFolder(folder:String):Array<String>
  {
    try
    {
      final entries:Array<String> = Paths.readDirectory(folder);
      return entries != null ? entries : [];
    }
    catch (_:Dynamic)
    {
      return []; // content-stripped build, or the other spelling of the folder
    }
  }

  /**
   * Loads the tile `ClientPrefs.menuCheckerTexture` asks for, falling back to
   * the default tile when that variant is not installed.
   *
   * Safe to call on every preference refresh: an unchanged key does nothing, and
   * `FlxBackdrop` re-renders its tile grid from the new graphic on its own.
   */
  function applyTexture():Void
  {
    final wanted:String = MenuCheckerTextures.normalize(ClientPrefs.menuCheckerTexture);
    if (wanted == textureKey) return;

    var key:String = wanted;
    var tile:FlxGraphic = Paths.image(key, 'preload');
    if (tile == null && wanted != MenuCheckerTextures.DEFAULT_KEY)
    {
      // A variant that is not installed (disabled mod, stripped build) must not
      // leave every menu with an empty backdrop.
      key = MenuCheckerTextures.DEFAULT_KEY;
      tile = Paths.image(key, 'preload');
    }
    // Remembered even when no tile loaded: `Paths.image()` already warns once
    // and caches the miss, so asking again on every refresh would only spam it.
    textureKey = key;
    if (tile == null) return;
    loadGraphic(tile);
    updateHitbox();
  }

  /** Applies the checkerboard, tile and reduced-motion preferences immediately. */
  public function refreshPreference():Void
  {
    applyTexture();
    visible = ClientPrefs.movingMenuCheckerboard;
    active = visible && !ClientPrefs.reducedMotion;
    if (active) velocity.set(motionX, motionY);
    else velocity.set();
  }

  /** Refreshes every checkerboard currently owned by a state or substate. */
  public static function refreshAll():Void
  {
    for (checkerboard in instances)
      if (checkerboard != null && checkerboard.exists) checkerboard.refreshPreference();
  }

  override public function destroy():Void
  {
    instances.remove(this);
    super.destroy();
  }
}
