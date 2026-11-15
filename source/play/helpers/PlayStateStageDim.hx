package play.helpers;

import backend.ClientPrefs;

import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxSprite;
import flixel.util.FlxColor;

import play.PlayState;

/**
 * **Stage dim** (`ClientPrefs.stageDim`, Options -> Visuals and UI): one
 * screen-fixed black quad drawn over the stage and the characters, and under
 * the notes, the strums and the HUD.
 *
 * ### Layering
 *
 * The overlay is routed to `camGame` alone. Notes and strums draw on
 * `camNotes` when Distant Notes is on and on `camHUD` otherwise
 * (`PlayState` routes them in `create()`), and neither camera draws this
 * sprite, so the whole note field and the HUD stay bright no matter how dark
 * the stage gets — including script effects added to `camHUD`.
 *
 * Within `camGame` the quad has to stay *last*, above every stage sprite,
 * character, trail and `createPost()` prop: built-in stages keep inserting
 * sprites after `create()` (`stages/Limo.hx`, `stages/Spooky.hx`,
 * `PlayStateEvents`), so `syncLayer()` moves it back to the end of the state
 * whenever something appeared above it. Inserting it once and hoping it stays
 * on top is not enough.
 *
 * ### Camera motion
 *
 * A `scrollFactor` of 0 pins the quad to the screen, but the gameplay camera
 * zooms (`camGame.zoom`) and `doTwist` rotates it, so the quad's size is
 * recomputed from `StageDimMath`. It only changes while one of those values
 * changes: the per-frame path is a few comparisons in the common case.
 *
 * ### Cost
 *
 * At the 0% default the overlay is hidden, Flixel skips `alpha == 0` sprites,
 * and the per-frame path is a pref read, a member-list comparison and an early
 * return. Enabling it costs one extra draw call; nothing is loaded from disk
 * (a 1x1 black pixel is generated and cached by `makeGraphic`).
 */
@:access(play.PlayState)
class PlayStateStageDim
{
  /**
   * Creates the overlay and places it above everything `camGame` draws.
   *
   * Called at the very end of `PlayState.create()`, once the stage, the
   * characters, the HUD, `onCreatePost` scripts and `createPost()` have all
   * added their sprites — creating it earlier would leave those props above it.
   * Safe to call twice: the second call reuses the sprite.
   */
  public static function setup(state:PlayState):Void
  {
    if (state == null) return;

    if (state.stageDimOverlay == null)
    {
      final overlay = new FlxSprite();
      // A 1x1 black pixel scaled to the viewport: no asset to ship, and Flixel
      // caches the generated graphic so every song shares it.
      overlay.makeGraphic(1, 1, FlxColor.BLACK);
      overlay.scrollFactor.set(0, 0);
      overlay.cameras = [state.camGame];
      overlay.alpha = StageDimMath.alpha(ClientPrefs.stageDim);
      overlay.visible = StageDimMath.isVisible(ClientPrefs.stageDim);
      state.stageDimOverlay = overlay;
    }

    sync(state);
  }

  /**
   * Applies the current preference and camera state to the overlay.
   *
   * Runs from `PlayState.update()`, after `super.update()`, so the camera
   * values for this frame are final. Exits immediately while the option is off.
   */
  public static function sync(state:PlayState):Void
  {
    final overlay:FlxSprite = state != null ? state.stageDimOverlay : null;
    if (overlay == null) return;

    final alpha:Float = StageDimMath.alpha(ClientPrefs.stageDim);
    if (overlay.alpha != alpha) overlay.alpha = alpha;

    final visible:Bool = alpha > StageDimMath.MIN_ALPHA;
    if (overlay.visible != visible) overlay.visible = visible;

    // Kept even while hidden: a stage added mid-song must end up beneath the
    // overlay, or the player would see it undimmed the moment the option is on.
    syncLayer(state);

    if (!visible) return;

    final camera:FlxCamera = state.camGame;
    if (camera == null) return;

    // A mod can replace the gameplay camera (or add its own). Parking the
    // overlay on the wrong camera would either hide it or dim the HUD, so it is
    // re-routed to `camGame` whenever that list changed.
    final cameras:Array<FlxCamera> = overlay.cameras;
    if (cameras == null || cameras.length != 1 || cameras[0] != camera)
    {
      overlay.cameras = [camera];
      // `set_cameras` does not touch ordering; re-append as well so the
      // overlay still ends up last.
      syncLayer(state);
    }

    syncRect(overlay, camera);
  }

  /**
   * Keeps the quad the last state member, so stage sprites added after
   * `create()` (or mid-song by an event) end up beneath it.
   *
   * `FlxState` is a `FlxContainer`: removing a member and adding it again
   * appends it at the end. `add()` alone is not enough, though: `FlxGroup.add()`
   * reuses the first `null` slot, and `PlayState` itself leaves holes when it
   * calls `remove()` without splicing (character swaps). `insert(members.length)`
   * always appends, so the quad cannot drift into the middle of the draw list.
   *
   * While nothing new was added the whole call is one array read and one
   * comparison: the `indexOf` scan below only runs on the frames that have to
   * move the quad.
   */
  public static function syncLayer(state:PlayState):Void
  {
    if (state == null) return;

    final overlay:FlxSprite = state.stageDimOverlay;
    final members:Array<FlxBasic> = state.members;
    if (overlay == null || members == null) return;

    // Common case: already last. One read, one comparison, no scan.
    final last:Int = members.length - 1;
    if (last >= 0 && members[last] == overlay) return;

    final index:Int = members.indexOf(overlay);
    if (index >= 0) state.remove(overlay, true);
    // Appending to the array, not filling a hole: see the note above.
    state.insert(members.length, overlay);
  }

  /** Sizes and positions the quad for the camera's current zoom and angle. */
  static function syncRect(overlay:FlxSprite, camera:FlxCamera):Void
  {
    if (camera.width <= 0 || camera.height <= 0) return;

    final size = StageDimMath.coverageSize(camera.width, camera.height, camera.zoom, camera.angle);
    final position = StageDimMath.coveragePosition(camera.width, camera.height, size);

    // `setGraphicSize` only writes `scale`; updating the hitbox too keeps the
    // sprite's `width`/`height` (and so its bounding box) correct for scripts
    // that inspect it. Both writes are skipped unless the value changed.
    if (overlay.x != position.x) overlay.x = position.x;
    if (overlay.y != position.y) overlay.y = position.y;

    final scaledWidth:Int = Std.int(Math.ceil(size.width));
    final scaledHeight:Int = Std.int(Math.ceil(size.height));
    if (Std.int(overlay.width) != scaledWidth || Std.int(overlay.height) != scaledHeight)
    {
      overlay.setGraphicSize(scaledWidth, scaledHeight);
      overlay.updateHitbox();
    }
  }

  /** Removes the overlay (song teardown); a later `setup()` recreates it. */
  public static function clear(state:PlayState):Void
  {
    if (state == null || state.stageDimOverlay == null) return;
    state.remove(state.stageDimOverlay, true);
    state.stageDimOverlay = null;
  }
}
