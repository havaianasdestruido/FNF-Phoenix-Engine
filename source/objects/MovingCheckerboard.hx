package objects;

import backend.ClientPrefs;
import backend.Paths;
import flixel.addons.display.FlxBackdrop;
import flixel.util.FlxAxes;
import flixel.util.FlxColor;

/**
 * A lightweight, endlessly tiled menu backdrop.
 *
 * The visual is inspired by the moving checkerboards in Mic'd Up! Engine's
 * menus (Verwex/Funkin-Mic-d-Up-SC). This implementation is original and uses
 * Phoenix's existing neutral checker tile so each menu can tint one shared
 * asset instead of shipping a separate texture for every color.
 */
class MovingCheckerboard extends FlxBackdrop
{
  /** Mic'd Up!'s main-menu movement converted from pixels/frame to pixels/s. */
  public static inline final DEFAULT_SPEED_X:Float = -27;
  public static inline final DEFAULT_SPEED_Y:Float = -9.6;

  static final instances:Array<MovingCheckerboard> = [];

  final motionX:Float;
  final motionY:Float;

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
    super(Paths.image('checker', 'preload'), FlxAxes.XY);

    motionX = speedX;
    motionY = speedY;
    color = tint;
    alpha = opacity;
    scale.set(tileScale, tileScale);
    updateHitbox();
    scrollFactor.set(0, 0.07);
    antialiasing = ClientPrefs.globalAntialiasing;

    instances.push(this);
    refreshPreference();
  }

  /** Applies the checkerboard and reduced-motion preferences immediately. */
  public function refreshPreference():Void
  {
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
