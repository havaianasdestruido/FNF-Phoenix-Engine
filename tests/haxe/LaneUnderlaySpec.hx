import backend.ClientPrefs;
import backend.ScreenLayout;
import flixel.FlxCamera;
import flixel.FlxSprite;
import objects.StrumNote;
import play.PlayState;
import play.helpers.LaneUnderlayMath;
import play.helpers.PlayStateLaneUnderlay;

/**
 * Lane underlay contract: the pure math plus the strip's lifecycle, camera
 * routing and layering against the player's strums.
 *
 * Runs against small Flixel stubs, so it needs no game haxelibs:
 *
 *     bash tests/haxe/run-lane-underlay.sh
 */
class LaneUnderlaySpec
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
    stripLifecycle();
    stripLayering();
    stripGeometry();
    teardown();

    if (failures > 0)
    {
      Sys.println('LaneUnderlaySpec: $failures failure(s)');
      Sys.exit(1);
    }
    Sys.println('LaneUnderlaySpec: PASS');
  }

  /** 0 stays 0 (the default changes nothing), NaN and out-of-range are safe. */
  static function mathContract():Void
  {
    near(LaneUnderlayMath.alpha(0), 0, 'the default is off');
    near(LaneUnderlayMath.alpha(Math.NaN), 0, 'NaN falls back to off');
    near(LaneUnderlayMath.alpha(-1), 0, 'negative values clamp to off');
    near(LaneUnderlayMath.alpha(0.3), 0.3, 'a mid value is kept as-is');
    near(LaneUnderlayMath.alpha(5), LaneUnderlayMath.MAX_ALPHA, 'absurd values clamp to the maximum');

    check(!LaneUnderlayMath.isVisible(0), 'off is not visible');
    check(!LaneUnderlayMath.isVisible(Math.NaN), 'NaN is not visible');
    check(LaneUnderlayMath.isVisible(0.01), 'a real value is visible');

    // Default padding pads both sides; an explicit one wins; garbage falls
    // back to the default instead of producing a negative-width strip.
    final base = LaneUnderlayMath.laneRect(600, 1000);
    near(base.x, 600 - LaneUnderlayMath.PAD, 'the default padding starts before the span');
    near(base.width, 1000 + LaneUnderlayMath.PAD - (600 - LaneUnderlayMath.PAD), 'the default padding covers both sides');

    final explicit = LaneUnderlayMath.laneRect(600, 1000, 0);
    near(explicit.x, 600, 'zero padding pins the strip to the span');
    near(explicit.width, 400, 'zero padding keeps the exact width');

    final garbage = LaneUnderlayMath.laneRect(600, 1000, Math.NaN);
    near(garbage.x, 600 - LaneUnderlayMath.PAD, 'a NaN padding falls back to the default');
    final negative = LaneUnderlayMath.laneRect(600, 1000, -50);
    near(negative.x, 600 - LaneUnderlayMath.PAD, 'a negative padding falls back to the default');

    // NaN in means a zero-width strip at the origin (the caller renders
    // nothing while the option is off, so this never reaches the screen).
    final nan = LaneUnderlayMath.laneRect(Math.NaN, 1000);
    near(nan.x, 0, 'a NaN left edge yields origin x');
    near(nan.width, 0, 'a NaN left edge yields a zero-width strip');

    // An inverted pair is swapped, not rejected: scripts can feed these in.
    final swapped = LaneUnderlayMath.laneRect(1000, 600);
    check(swapped.width > 0, 'an inverted pair still yields a strip');
    near(swapped.x, 600 - LaneUnderlayMath.PAD, 'an inverted pair is normalised');
    near(swapped.x + swapped.width, 1000 + LaneUnderlayMath.PAD, 'an inverted pair spans the same range');

    // A hairline span is never allowed to collapse below one pixel.
    final hairline = LaneUnderlayMath.laneRect(600, 600, 0);
    check(hairline.width >= 1, 'a point span still yields at least one pixel');
  }

  /** The 0% default never draws; the preference drives visibility and alpha. */
  static function stripLifecycle():Void
  {
    final state = new PlayState();
    ClientPrefs.laneUnderlayAlpha = 0;
    PlayStateLaneUnderlay.setup(state);

    final overlay:FlxSprite = state.laneUnderlayOverlay;
    check(overlay != null, 'setup creates the strip even while off');
    check(!overlay.visible, 'the 0% default is hidden');
    near(overlay.alpha, 0, 'the 0% default has no alpha');
    check(overlay.scrollFactor.x == 0 && overlay.scrollFactor.y == 0, 'scrollFactor 0 pins it to the screen');
    check(overlay.cameras.length == 1 && overlay.cameras[0] == state.camHUD, 'the HUD camera draws it while camNotes is absent');
    check(overlay.cameras[0] != state.camGame, 'the gameplay camera never draws it');
    check(overlay.graphicColor == 0xFF000000, 'the strip is black');

    PlayStateLaneUnderlay.setup(state);
    check(state.laneUnderlayOverlay == overlay, 'setup is idempotent');

    ClientPrefs.laneUnderlayAlpha = 0.4;
    PlayStateLaneUnderlay.sync(state);
    check(overlay.visible, 'enabling the option shows the strip');
    near(overlay.alpha, 0.4, 'the preference drives the alpha');

    ClientPrefs.laneUnderlayAlpha = 0;
    PlayStateLaneUnderlay.sync(state);
    check(!overlay.visible, 'turning the option off hides the strip again');

    PlayStateLaneUnderlay.sync(null);
    PlayStateLaneUnderlay.setup(null);
    PlayStateLaneUnderlay.clear(null);
    check(true, 'the null guards do not throw');

    // A NaN preference renders as off.
    ClientPrefs.laneUnderlayAlpha = Math.NaN;
    PlayStateLaneUnderlay.sync(state);
    check(!overlay.visible, 'NaN does not show the strip');
    near(overlay.alpha, 0, 'NaN is treated as off');
    ClientPrefs.laneUnderlayAlpha = 0;
  }

  /** The strip draws before the strums and follows the note camera. */
  static function stripLayering():Void
  {
    final state = new PlayState();

    // With a note camera in place the strip goes there, beneath the strums.
    state.camNotes = new FlxCamera();
    state.add(state.strumLineNotes);
    ClientPrefs.laneUnderlayAlpha = 0.5;
    PlayStateLaneUnderlay.setup(state);

    final overlay:FlxSprite = state.laneUnderlayOverlay;
    check(overlay.cameras.length == 1 && overlay.cameras[0] == state.camNotes, 'the strip follows camNotes');
    check(state.members.indexOf(overlay) >= 0, 'the strip is in the state');
    check(state.members.indexOf(overlay) < state.members.indexOf(state.strumLineNotes), 'the strip draws before the strums');
    check(overlay.cameras[0] != state.camGame, 'the gameplay camera never draws it');

    // A mod that removes camNotes mid-song gets the strip re-routed to camHUD.
    state.camNotes = null;
    PlayStateLaneUnderlay.sync(state);
    check(overlay.cameras.length == 1 && overlay.cameras[0] == state.camHUD, 'the strip falls back to camHUD without camNotes');

    // A replacement camNotes is picked up the same way.
    final replacement = new FlxCamera();
    state.camNotes = replacement;
    PlayStateLaneUnderlay.sync(state);
    check(overlay.cameras[0] == replacement, 'the strip follows a replaced camNotes');

    ClientPrefs.laneUnderlayAlpha = 0;
  }

  /** Player strums span the strip; opponent lanes never widen it. */
  static function stripGeometry():Void
  {
    final state = new PlayState();
    ClientPrefs.laneUnderlayAlpha = 0.5;
    PlayStateLaneUnderlay.setup(state);

    final playerA = new StrumNote(1);
    playerA.x = 600;
    playerA.makeGraphic(112, 112, 0xFFFFFFFF);
    playerA.updateHitbox();
    final playerB = new StrumNote(1);
    playerB.x = 940;
    playerB.makeGraphic(112, 112, 0xFFFFFFFF);
    playerB.updateHitbox();
    final opponent = new StrumNote(0);
    opponent.x = 100;
    opponent.makeGraphic(112, 112, 0xFFFFFFFF);
    opponent.updateHitbox();

    state.strumLineNotes.members.push(playerA);
    state.strumLineNotes.members.push(playerB);
    state.strumLineNotes.members.push(opponent);

    PlayStateLaneUnderlay.sync(state);
    final overlay:FlxSprite = state.laneUnderlayOverlay;

    near(overlay.x, 600 - LaneUnderlayMath.PAD, 'the strip starts before the player span');
    near(overlay.width, (940 + 112 + LaneUnderlayMath.PAD) - (600 - LaneUnderlayMath.PAD), 'the strip spans the player lanes only');
    near(overlay.y, 0, 'the strip pins to the top edge');
    check(overlay.height > 0, 'the strip covers the full height');

    // Opponent-only members leave the span unset: the formula fallback kicks in.
    final lonely = new PlayState();
    PlayStateLaneUnderlay.setup(lonely);
    final oppOnly = new StrumNote(0);
    oppOnly.x = 100;
    oppOnly.makeGraphic(112, 112, 0xFFFFFFFF);
    oppOnly.updateHitbox();
    lonely.strumLineNotes.members.push(oppOnly);
    PlayStateLaneUnderlay.sync(lonely);

    // The fallback mirrors `generateStaticArrows` for the player side:
    // STRUM_X + 50 + centred content + BASE_WIDTH/2.
    final contentLeft:Float = ScreenLayout.contentLeft(1280);
    final expectedBase:Float = 48 + 50 + contentLeft + ScreenLayout.BASE_WIDTH / 2;
    near(lonely.laneUnderlayOverlay.x, expectedBase - LaneUnderlayMath.PAD, 'the fallback starts at the formula position');
    near(lonely.laneUnderlayOverlay.width, 4 * objects.Note.swagWidth + 2 * LaneUnderlayMath.PAD, 'the fallback covers four lanes');

    // Middlescroll shifts the formula to the middlescroll anchor.
    final ms = new PlayState();
    PlayState.middleScroll = true;
    PlayStateLaneUnderlay.setup(ms);
    PlayStateLaneUnderlay.sync(ms);
    final expectedMs:Float = -278 + 50 + contentLeft + ScreenLayout.BASE_WIDTH / 2;
    near(ms.laneUnderlayOverlay.x, expectedMs - LaneUnderlayMath.PAD, 'middlescroll uses its own anchor');
    PlayState.middleScroll = false;

    ClientPrefs.laneUnderlayAlpha = 0;
  }

  static function teardown():Void
  {
    final state = new PlayState();
    ClientPrefs.laneUnderlayAlpha = 0.3;
    PlayStateLaneUnderlay.setup(state);
    check(state.members.indexOf(state.laneUnderlayOverlay) >= 0, 'the strip is in the state');

    final overlay:FlxSprite = state.laneUnderlayOverlay;
    PlayStateLaneUnderlay.clear(state);
    check(state.laneUnderlayOverlay == null, 'clear() forgets the strip');
    check(state.members.indexOf(overlay) < 0, 'clear() takes it out of the members');

    PlayStateLaneUnderlay.setup(state);
    check(state.laneUnderlayOverlay != null, 'a later setup recreates it');

    ClientPrefs.laneUnderlayAlpha = 0;
  }
}
