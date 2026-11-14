import backend.ClientPrefs;
import flixel.FlxCamera;
import flixel.FlxSprite;
import play.PlayState;
import play.helpers.PlayStateStageDim;
import play.helpers.StageDimMath;

/**
 * Stage dim contract: the pure math plus the overlay's lifecycle and layering.
 *
 * Runs against small Flixel stubs, so it needs no game haxelibs:
 *
 *     bash tests/haxe/run-stage-dim.sh
 */
class StageDimSpec
{
  static var failures:Int = 0;

  static function check(ok:Bool, label:String, ?pos:haxe.PosInfos):Void
  {
    if (ok) return;
    failures++;
    Sys.println('FAIL: ' + label + ' @' + (pos == null ? 0 : pos.lineNumber));
  }

  static function near(actual:Float, expected:Float, label:String):Void
  {
    check(Math.abs(actual - expected) < 0.001, '$label (expected $expected, got $actual)');
  }

  static function main():Void
  {
    mathContract();
    percentSafety();
    overlayLifecycle();
    overlayLayering();
    cameraMotion();
    teardown();

    if (failures > 0)
    {
      Sys.println('StageDimSpec: $failures failure(s)');
      Sys.exit(1);
    }
    Sys.println('StageDimSpec: PASS');
  }

  /** 0 stays 0 (the default changes nothing), NaN and out-of-range are safe. */
  static function mathContract():Void
  {
    near(StageDimMath.alpha(0), 0, 'the default is off');
    near(StageDimMath.alpha(Math.NaN), 0, 'NaN falls back to off');
    near(StageDimMath.alpha(-1), 0, 'negative values clamp to off');
    near(StageDimMath.alpha(0.5), 0.5, 'a mid value is kept as-is');
    near(StageDimMath.alpha(1), StageDimMath.MAX_ALPHA, 'the maximum is capped');

    check(!StageDimMath.isVisible(0), 'off is not visible');
    check(!StageDimMath.isVisible(Math.NaN), 'NaN is not visible');
    check(StageDimMath.isVisible(0.2), 'a real value is visible');

    near(StageDimMath.safeZoom(0), 1, 'a zero zoom means 1:1');
    near(StageDimMath.safeZoom(-2), 1, 'a negative zoom means 1:1');
    near(StageDimMath.safeZoom(2), 2, 'a real zoom is kept');

    // 1:1 and no rotation covers the viewport plus the safety margin.
    final flat = StageDimMath.coverageSize(1280, 720, 1, 0);
    check(flat.width >= 1280 && flat.height >= 720, 'the flat quad covers the viewport');
    near(flat.width, 1280 * (1 + StageDimMath.SAFETY_MARGIN), 'flat width includes the margin');
    near(flat.height, 720 * (1 + StageDimMath.SAFETY_MARGIN), 'flat height includes the margin');

    // Zooming in shows less world, so the screen-fixed quad shrinks with it.
    final zoomedIn = StageDimMath.coverageSize(1280, 720, 2, 0);
    near(zoomedIn.width, flat.width / 2, 'zooming in halves the quad');
    final zoomedOut = StageDimMath.coverageSize(1280, 720, 0.5, 0);
    near(zoomedOut.width, flat.width * 2, 'zooming out doubles the quad');

    // A rotated view needs the bounding box of the tilted rectangle, so both
    // axes grow (widest at 45°) and a 90° turn swaps the axes.
    final rotated = StageDimMath.coverageSize(1280, 720, 1, 90);
    near(rotated.width, flat.height, 'a 90 degree rotation swaps width into height');
    near(rotated.height, flat.width, 'a 90 degree rotation swaps height into width');
    final tilted = StageDimMath.coverageSize(1280, 720, 1, 45);
    check(tilted.width > flat.width && tilted.height > flat.height, '45 degrees grows the quad');
    near(tilted.width, tilted.height, 'a 45 degree tilt covers a square');

    // Centring: a quad bigger than the viewport starts before the origin and
    // a smaller one starts inside it.
    final bigPos = StageDimMath.coveragePosition(1280, 720, zoomedOut);
    check(bigPos.x < 0 && bigPos.y < 0, 'an oversized quad starts outside the viewport');
    final smallPos = StageDimMath.coveragePosition(1280, 720, zoomedIn);
    check(smallPos.x > 0 && smallPos.y > 0, 'an undersized quad starts inside the viewport');
    near(bigPos.x + zoomedOut.width / 2, 640, 'the oversized quad is horizontally centred');
    near(smallPos.y + zoomedIn.height / 2, 360, 'the undersized quad is vertically centred');

    // A degenerate camera size must not produce a zero-size quad.
    final degenerate = StageDimMath.coverageSize(0, 0, 1, 0);
    check(degenerate.width > 0 && degenerate.height > 0, 'a zero camera size still yields a quad');
  }

  /** `NaN` and odd values never produce a visible overlay or a broken size. */
  static function percentSafety():Void
  {
    final state = new PlayState();
    ClientPrefs.stageDim = Math.NaN;
    PlayStateStageDim.setup(state);
    check(!state.stageDimOverlay.visible, 'a NaN preference does not show the overlay');
    near(state.stageDimOverlay.alpha, 0, 'a NaN preference is treated as off');

    ClientPrefs.stageDim = 5;
    PlayStateStageDim.sync(state);
    near(state.stageDimOverlay.alpha, StageDimMath.MAX_ALPHA, 'an absurd value clamps to the maximum');
    check(state.stageDimOverlay.visible, 'a clamped value is visible');

    ClientPrefs.stageDim = 0;
  }

  static function overlayLifecycle():Void
  {
    final state = new PlayState();
    ClientPrefs.stageDim = 0;
    PlayStateStageDim.setup(state);

    final overlay:FlxSprite = state.stageDimOverlay;
    check(overlay != null, 'setup creates the overlay even while off');
    check(!overlay.visible, 'the 0% default is hidden');
    near(overlay.alpha, 0, 'the 0% default has no alpha');
    check(overlay.scrollFactor.x == 0 && overlay.scrollFactor.y == 0, 'scrollFactor 0 pins it to the screen');
    check(overlay.cameras.length == 1 && overlay.cameras[0] == state.camGame, 'only camGame draws it');
    check(overlay.graphicColor == 0xFF000000, 'the quad is black');

    PlayStateStageDim.setup(state);
    check(state.stageDimOverlay == overlay, 'setup is idempotent');

    ClientPrefs.stageDim = 0.35;
    PlayStateStageDim.sync(state);
    check(overlay.visible, 'enabling the option shows the overlay');
    near(overlay.alpha, 0.35, 'the preference drives the alpha');

    ClientPrefs.stageDim = 0;
    PlayStateStageDim.sync(state);
    check(!overlay.visible, 'turning the option off hides the overlay again');

    PlayStateStageDim.sync(null);
    PlayStateStageDim.setup(null);
    PlayStateStageDim.clear(null);
    check(true, 'the null guards do not throw');
  }

  /** The overlay must be the last camGame member, even after late sprites. */
  static function overlayLayering():Void
  {
    final state = new PlayState();
    ClientPrefs.stageDim = 0.4;
    PlayStateStageDim.setup(state);

    final overlay:FlxSprite = state.stageDimOverlay;
    check(state.members[state.members.length - 1] == overlay, 'the overlay is added last');

    final lateStageProp = new FlxSprite();
    state.add(lateStageProp);
    PlayStateStageDim.sync(state);
    check(state.members[state.members.length - 1] == overlay, 'a late stage sprite ends up beneath it');

    // A stage that inserts itself *before* the overlay (the real `insert()`
    // path) keeps the overlay last without extra work.
    final background = new FlxSprite();
    state.insert(0, background);
    PlayStateStageDim.sync(state);
    check(state.members[state.members.length - 1] == overlay, 'insertions elsewhere keep the overlay last');
    check(state.members.indexOf(overlay) == state.members.length - 1, 'no duplicate overlay members');

    // Notes and strums live on other cameras, so the real PlayState never
    // routes them here; the overlay's camera list is the guard.
    check(overlay.cameras.length == 1, 'the overlay is never routed to camNotes or camHUD');
    check(overlay.cameras[0] != state.camHUD, 'the HUD camera never draws it');

    // A character swap removes a member without splicing, leaving a `null`
    // hole *before* the overlay. Flixel's `add()` fills the first hole, so
    // re-appending the quad with `add()` would drop it into that hole and
    // leave whatever was added after it undimmed. `insert(length, …)` appends.
    final victim = new FlxSprite();
    final lateProp = new FlxSprite();
    state.add(victim);
    PlayStateStageDim.sync(state);
    state.add(lateProp);
    state.remove(victim, false);
    check(state.members.indexOf(null) >= 0, 'the swap left a null hole before the overlay');
    PlayStateStageDim.sync(state);
    check(state.members[state.members.length - 1] == overlay, 'a null hole does not pull the overlay forward');
    check(state.members.indexOf(lateProp) < state.members.indexOf(overlay), 'the late prop is still beneath it');
    state.remove(lateProp, true);

    // While off, the overlay is hidden but still ordered, so enabling it later
    // needs no rebuild.
    ClientPrefs.stageDim = 0;
    state.add(new FlxSprite());
    PlayStateStageDim.sync(state);
    check(!overlay.visible, 'still hidden while off');
    check(state.members[state.members.length - 1] == overlay, 'ordering is kept while off');

    // A mod that swaps the gameplay camera gets the overlay moved with it.
    ClientPrefs.stageDim = 0.4;
    final replacement = new FlxCamera();
    state.camGame = replacement;
    PlayStateStageDim.sync(state);
    check(overlay.cameras[0] == replacement, 'the overlay follows a replaced camGame');
    check(state.members[state.members.length - 1] == overlay, 're-routing keeps it last');

    ClientPrefs.stageDim = 0;
  }

  static function cameraMotion():Void
  {
    final state = new PlayState();
    ClientPrefs.stageDim = 0.5;
    PlayStateStageDim.setup(state);
    final overlay:FlxSprite = state.stageDimOverlay;

    final flatWidth:Float = overlay.width;
    check(flatWidth >= 1280, 'at 1:1 the quad covers the viewport');

    state.camGame.zoom = 2;
    PlayStateStageDim.sync(state);
    check(overlay.width < flatWidth, 'zooming in shrinks the screen-fixed quad');
    near(overlay.width, Math.ceil(1280 * 0.5 * (1 + StageDimMath.SAFETY_MARGIN)), 'half the world is shown at 2x');

    state.camGame.zoom = 1;
    state.camGame.angle = 45;
    PlayStateStageDim.sync(state);
    check(overlay.width > flatWidth, 'a twist grows the quad so the corners stay covered');

    state.camGame.angle = 0;
    state.camGame.zoom = Math.NaN;
    PlayStateStageDim.sync(state);
    check(overlay.width > 0 && overlay.height > 0, 'a NaN zoom never collapses the quad');

    state.camGame.zoom = 1;
    PlayStateStageDim.sync(state);
    // The position comes from the exact float size while `updateHitbox()`
    // rounds the sprite's own width/height up to whole pixels, so the centre
    // is only within half a pixel.
    check(Math.abs(overlay.x - (1280 - overlay.width) / 2) < 1, 'the quad is horizontally centred');
    check(Math.abs(overlay.y - (720 - overlay.height) / 2) < 1, 'the quad is vertically centred');
    check(Math.abs(overlay.x + overlay.width / 2 - 640) < 1, 'the quad is centred on the camera width');
    check(Math.abs(overlay.y + overlay.height / 2 - 360) < 1, 'the quad is centred on the camera height');

    // A resize moves the quad with the viewport: the checks read the camera
    // size, which the engine resizes with the window.
    state.camGame.width = 1920;
    state.camGame.height = 1080;
    PlayStateStageDim.sync(state);
    check(overlay.width > flatWidth, 'a wider viewport grows the quad');
    state.camGame.width = 1280;
    state.camGame.height = 720;

    ClientPrefs.stageDim = 0;
  }

  static function teardown():Void
  {
    final state = new PlayState();
    ClientPrefs.stageDim = 0.3;
    PlayStateStageDim.setup(state);
    check(state.members.indexOf(state.stageDimOverlay) >= 0, 'the overlay is in the state');

    final overlay:FlxSprite = state.stageDimOverlay;
    PlayStateStageDim.clear(state);
    check(state.stageDimOverlay == null, 'clear() forgets the overlay');
    check(state.members.indexOf(overlay) < 0, 'clear() takes it out of the members');

    PlayStateStageDim.setup(state);
    check(state.stageDimOverlay != null, 'a later setup recreates it');

    ClientPrefs.stageDim = 0;
  }
}
