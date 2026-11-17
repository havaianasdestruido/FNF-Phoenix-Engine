package play.helpers;

import backend.ClientPrefs;
import backend.ScreenLayout;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.util.FlxColor;

import play.PlayState;

/**
 * **Lane underlay** (`ClientPrefs.laneUnderlayAlpha`, Options -> Visuals and UI):
 * one black quad drawn behind the player's lanes, above the stage and below
 * the notes, the strums, the splashes and the HUD.
 *
 * ### Purpose
 *
 * Busy stages can swallow the arrows. The underlay darkens exactly the
 * player's lane strip so the notes stay readable; everything else keeps its
 * original brightness. Unlike Stage dim, it does not dim the characters.
 *
 * ### Layering
 *
 * The strip is routed to the same camera the notes are drawn on
 * (`camNotes` when Distant Notes is on, otherwise `camHUD`) and is inserted
 * into the state's member list just before `strumLineNotes`, so it always
 * draws first on that camera: above the stage (`camGame`), below the notes,
 * the strums, the sustains and the splashes. The HUD camera is never
 * covered, and the notes/strums are never dimmed.
 *
 * ### Geometry
 *
 * A `scrollFactor` of 0 pins the strip to the screen. The gameplay cameras
 * zoom around their centre, and the strums (also `scrollFactor` 0 on the same
 * camera) zoom identically, so the strip and the lanes stay aligned no
 * matter what the camera does. The span itself is measured from the live
 * player strums (`LaneUnderlayMath.laneRect`), which handles downscroll,
 * middlescroll, pixel stages and resizes without any special cases; before
 * the strums exist it falls back to the same formula
 * `PlayStateNoteHelpers.generateStaticArrows` uses.
 *
 * ### Cost
 *
 * At the 0% default the strip is hidden, Flixel skips `alpha == 0` sprites
 * and the per-frame path is a pref read plus an early return. Enabling it
 * costs one draw call; nothing is loaded from disk (a 1x1 black pixel is
 * generated and cached by `makeGraphic`).
 */
@:access(play.PlayState)
class PlayStateLaneUnderlay
{
  /**
   * Creates the strip if missing and parks it under the notes on the notes
   * camera. Called at the very end of `PlayState.create()`; safe to call
   * twice. Members are inserted relative to `strumLineNotes`, so everything
   * that draws on top of the strums still does.
   */
  public static function setup(state:PlayState):Void
  {
    if (state == null) return;

    if (state.laneUnderlayOverlay == null)
    {
      final overlay = new FlxSprite();
      // A 1x1 black pixel stretched to the viewport: no asset to ship, and
      // Flixel caches the generated graphic so every song shares it.
      overlay.makeGraphic(1, 1, FlxColor.BLACK);
      overlay.scrollFactor.set(0, 0);
      overlay.cameras = [noteCamera(state)];
      overlay.alpha = LaneUnderlayMath.alpha(ClientPrefs.laneUnderlayAlpha);
      overlay.visible = LaneUnderlayMath.isVisible(ClientPrefs.laneUnderlayAlpha);
      state.laneUnderlayOverlay = overlay;

      // Draw before the strums (and therefore before the notes) on the note
      // camera. `insert` at the strum group's index puts the strip behind
      // every strum/notes draw, regardless of creation order.
      final index:Int = state.members.indexOf(state.strumLineNotes);
      if (index >= 0) state.insert(index, overlay);
      else state.add(overlay);
    }

    sync(state);
  }

  /**
   * Applies the current preference and measure to the strip.
   *
   * Runs from `PlayState.update()`, after `super.update()`, so this frame's
   * strum positions are final. Exits immediately while the option is off.
   */
  public static function sync(state:PlayState):Void
  {
    final overlay:FlxSprite = state != null ? state.laneUnderlayOverlay : null;
    if (overlay == null) return;

    final alpha:Float = LaneUnderlayMath.alpha(ClientPrefs.laneUnderlayAlpha);
    if (overlay.alpha != alpha) overlay.alpha = alpha;

    final visible:Bool = alpha > LaneUnderlayMath.MIN_ALPHA;
    if (overlay.visible != visible) overlay.visible = visible;

    if (!visible) return;

    // A mod can toggle Distant Notes (or the note camera) mid-song; the
    // strip follows whichever camera the notes are on.
    final camera:FlxCamera = noteCamera(state);
    final cameras:Array<FlxCamera> = overlay.cameras;
    if (cameras == null || cameras.length != 1 || cameras[0] != camera)
      overlay.cameras = [camera];

    syncRect(state, overlay);
  }

  /** Removes the strip (song teardown); a later `setup()` recreates it. */
  public static function clear(state:PlayState):Void
  {
    if (state == null || state.laneUnderlayOverlay == null) return;
    state.remove(state.laneUnderlayOverlay, true);
    state.laneUnderlayOverlay = null;
  }

  /** Which camera the notes (and so the strip) draw on this frame. */
  static function noteCamera(state:PlayState):FlxCamera
  {
    return state.camNotes != null ? state.camNotes : state.camHUD;
  }

  /** Measures the player's strum span and stretches/positions the quad. */
  static function syncRect(state:PlayState, overlay:FlxSprite):Void
  {
    final bounds:{left:Null<Float>, right:Null<Float>} = strumBounds(state);

    // Before the strums exist (the countdown has not run yet) use the same
    // base formula `generateStaticArrows` uses for player lanes.
    final contentLeft:Float = ScreenLayout.contentLeft(FlxG.width);
    final base:Float = (PlayState.middleScroll ? PlayState.STRUM_X_MIDDLESCROLL : PlayState.STRUM_X)
      + 50 + contentLeft + ScreenLayout.BASE_WIDTH / 2;
    final left:Float = bounds.left != null ? bounds.left : base;
    final right:Float = bounds.right != null ? bounds.right : base + 4 * objects.Note.swagWidth;

    final rect:{x:Float, width:Float} = LaneUnderlayMath.laneRect(left, right);

    final x:Float = rect.x;
    final height:Float = FlxG.height;

    if (overlay.x != x) overlay.x = x;
    if (overlay.y != 0) overlay.y = 0;

    // `setGraphicSize` only writes `scale`; the hitbox keeps width/height
    // (and so the bounding box scripts inspect) correct. Writes are skipped
    // unless the value changed.
    final scaledWidth:Int = Std.int(Math.ceil(rect.width));
    final scaledHeight:Int = Std.int(Math.max(1, Math.ceil(height)));
    if (Std.int(overlay.width) != scaledWidth || Std.int(overlay.height) != scaledHeight)
    {
      overlay.setGraphicSize(scaledWidth, scaledHeight);
      overlay.updateHitbox();
    }
  }

  /**
   * Left/right edges of the player's strum span in screen pixels, or nulls
   * when the strums do not exist yet (or none of them is the player's).
   */
  static function strumBounds(state:PlayState):{left:Null<Float>, right:Null<Float>}
  {
    var left:Null<Float> = null;
    var right:Null<Float> = null;

    // `strumLineNotes` holds both sides as direct children; `player == 1`
    // filters to the player's lanes no matter where they ended up (opponent
    // chart, middlescroll, custom offsets from scripts).
    final members = state.strumLineNotes != null ? state.strumLineNotes.members : null;

    if (members != null)
    {
      for (strum in members)
      {
        if (strum == null || strum.player != 1) continue;

        final strumLeft:Float = strum.x;
        final strumRight:Float = strum.x + strum.width;

        if (left == null || strumLeft < left) left = strumLeft;
        if (right == null || strumRight > right) right = strumRight;
      }
    }

    return {left: left, right: right};
  }
}
