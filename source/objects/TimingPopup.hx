package objects;

import backend.ClientPrefs;
import backend.Conductor;
import backend.Paths;
import backend.ScreenLayout;
import debug.PoolStats;
import play.PlayState;

/**
 * The Mic'd Up!-style "Early"/"Late" label that pops next to a rating.
 *
 * The popups that share `PlayState.popUpGroup` are all `objects.Popup`, so this
 * class stays a plain `FlxSprite`: it is stored in its own
 * `PlayState.timingGroup` pool, and placed/drilled/faded by
 * `play.helpers.PlayStateRating.spawnTiming()`. Keeping it out of the rating
 * pool means a recycling mistake cannot leave a label on top of a combo digit.
 *
 * Every method is safe on a sprite that never got a graphic, so a ratings folder
 * without `early`/`late` art costs nothing beyond the class.
 */
class TimingPopup extends FlxSprite
{
  /** Image key currently loaded (`null` when the pool revived it without art). */
  public var asset(default, null):String = null;

  /** Song position the label was spawned at; mirrors `Popup.popTime`. */
  public var popTime:Float = 0;

  var playbackRate(get, never):Float;

  inline function get_playbackRate():Float
  {
    try
    {
      return PlayState.instance.playbackRate;
    }
    catch (e:Dynamic)
    {
      return 1.0;
    }
  }

  public function new()
  {
    super();
    scrollFactor.set();
    // Stays alive so `FlxTypedGroup.recycle()` can drift it; `setup()` decides
    // whether it is ever drawn. Killing here would freeze it in place, because
    // Flixel only updates live sprites.
    visible = false;
    alpha = 1;
  }

  /**
   * Loads the label art.
   *
   * @param asset full `images/...` key without extension, resolved by
   *              `PlayStateRating.timingAsset()`.
   * @return `false` (leaving the sprite hidden) when the art is missing.
   */
  public function setup(asset:String):Bool
  {
    if (asset == null || !Paths.imageExists(asset))
    {
      this.asset = null;
      visible = false;
      return false;
    }

    loadGraphic(Paths.image(asset));
    this.asset = asset;
    antialiasing = ClientPrefs.globalAntialiasing && !PlayState.isPixelStage;
    setGraphicSize(Std.int(width * scaleFactor()));
    updateHitbox();
    return true;
  }

  /** Graphic scale that matches the rating sprite drawn beside the label. */
  public static inline function scaleFactor():Float
  {
    return PlayState.isPixelStage ? PlayState.daPixelZoom * 0.85 : 0.7;
  }

  /**
   * Drops the label under the rating it belongs to and starts its upward drift.
   *
   * The rating sprite is already sized and positioned when this runs, so the
   * label hugs whatever art the current ratings style uses (heights differ a lot
   * between styles) instead of guessing an offset from the screen centre.
   *
   * @param anchor  rating popup to sit under; `null` centres the label instead.
   * @param offsetX `ClientPrefs.comboOffset[0]`, kept so ratings, combo digits
   *                and labels all follow the player's HUD offset.
   * @param offsetY `ClientPrefs.comboOffset[1]`.
   */
  public function place(?anchor:FlxSprite, offsetX:Float = 0, offsetY:Float = 0):Void
  {
    if (asset == null) return;

    popTime = Conductor.songPosition;
    screenCenter();
    if (anchor != null && anchor.width > 0 && anchor.height > 0)
    {
      x = anchor.x + (anchor.width - width) * 0.5;
      y = anchor.y + anchor.height * 0.72;
    }
    else
    {
      // No rating sprite (asset disabled): same centred HUD column as a rating.
      x = ScreenLayout.contentLeft(FlxG.width) + ScreenLayout.BASE_WIDTH * 0.35 - width * 0.5;
      y -= 10;
    }
    x += offsetX;
    y -= offsetY;

    alpha = 1;
    // Pool members are revived by `recycle()`; this also covers the very first
    // spawn, which hands back a freshly constructed (still dead) sprite.
    if (!exists) revive();
    visible = !ClientPrefs.hideHud;
    acceleration.y = 550 * playbackRate * playbackRate;
    velocity.y -= FlxG.random.int(120, 150) * playbackRate;
    velocity.x -= FlxG.random.int(0, 8) * playbackRate;
  }

  /** Same fade-out timeline as `Popup.alphaTween()`. */
  public function alphaTween():Void
  {
    if (asset == null) return;
    FlxTween.tween(this, {alpha: 0}, 0.2 / playbackRate, {
      startDelay: 0.7 / playbackRate,
      onComplete: function(_) kill()
    });
  }

  /**
   * Returns the label to `PlayState.timingGroup` and counts the return, like
   * `Popup.kill()` does for the rating pool. (#88)
   */
  override public function kill():Void
  {
    FlxTween.cancelTweensOf(this);
    visible = false;
    if (exists)
    {
      super.kill();
      PoolStats.release(PoolStats.POPUP);
      return;
    }
    super.kill();
  }

  override public function revive():Void
  {
    super.revive();
    alpha = 1;
    velocity.set(0, 0);
    acceleration.set(0, 0);
    visible = false;
  }
}
