import backend.DiagnosticsReport;
import flixel.FlxG;
import lime.system.Clipboard;
import states.DiagnosticsState;

/**
 * Behaviour tests for `states.DiagnosticsState`, the page `phoenix://diagnostics`
 * opens.
 *
 * Compiled against the stubs in `tests/haxe/stubs/diagnostics`, so it runs in the
 * Haxe interpreter without the game haxelibs:
 *
 *     bash tests/haxe/run-diagnostics-report.sh
 *
 * The point is the promise behind the route: one tap, one screenshot, nothing
 * changed. So this checks that the page renders the report it was given, scrolls
 * without escaping its bounds, hands the clipboard exactly the same text, keeps
 * its snapshot stable until `R`, leaves through the Main Menu, releases the
 * camera it borrowed — and that a clipboard that refuses to work costs a hint
 * line instead of the page.
 */
/** `@:access` so the page's private members can be inspected without widening them in production. */
@:access(states.DiagnosticsState)
class DiagnosticsStateSpec
{
  static function check(ok:Bool, label:String):Void
  {
    if (!ok) throw label;
  }

  static function fresh():DiagnosticsState
  {
    Clipboard.writes = 0;
    Clipboard.fail = false;
    FlxG.switchedToInt = [];
    FlxG.cameras.added = [];
    FlxG.cameras.removed = [];
    FlxG.keys.justPressed.ESCAPE = false;
    FlxG.keys.justPressed.C = false;
    FlxG.keys.justPressed.R = false;
    FlxG.mouse.wheel = 0;
    backend.ViewportVisuals.covers = 0;
    final state = new DiagnosticsState();
    state.create();
    return state;
  }

  static function main():Void
  {
    testRendering();
    testScrollingStaysInsideThePage();
    testCopyAndRefresh();
    testLeavingIsSingleShot();
    testDestroyReleasesTheCamera();
    Sys.println('DiagnosticsStateSpec passed');
  }

  static function testRendering():Void
  {
    final state = fresh();
    check(state.created, 'the page initialises through its base state');
    check(state.reportText.text == DiagnosticsReport.build(), 'the page renders the report verbatim');
    check(state.reportPanel.graphicSize != null, 'the panel is sized to the page, not left 1x1');
    check(FlxG.cameras.added.length == 1, 'the page borrows exactly one camera');
    check(state.reportText.cameras.length == 1 && state.reportText.cameras[0] == state.reportCamera,
      'the report renders into that one camera only');
    check(state.virtualPadAdded == 'UP_DOWN/A_B', 'a phone gets scroll plus A/B: ' + state.virtualPadAdded);
    check(state.virtualPadCamera, 'the pad is drawn on its own camera');
    check(state.updates == 0, 'creating the page does not run a game update');
    check(state.reportCamera.width > 0 && state.reportCamera.height > 0, 'the panel is laid out on entry');
    check(state.hintText.y > 0 && state.hintText.y < FlxG.height, 'the footer sits inside the window');

    state.onResize(800, 600);
    check(state.reportPanel.graphicSize != '1x1', 'a resize re-lays the panel out');
    check(state.reportCamera.width >= 320 && state.reportCamera.width <= 1160,
      'the panel width stays inside its bounds after a resize');
  }

  static function testScrollingStaysInsideThePage():Void
  {
    final state = fresh();
    check(state.maxScroll > 0, 'a report taller than the panel is scrollable');

    state.controls.UI_DOWN = true;
    for (i in 0...400)
      state.update(1.0);
    check(state.scrollOffset == state.maxScroll, 'scrolling down clamps at the bottom');
    check(state.reportCamera.scroll.y == state.maxScroll, 'the camera follows the clamp');

    state.controls.UI_DOWN = false;
    state.controls.UI_UP = true;
    for (i in 0...400)
      state.update(1.0);
    check(state.scrollOffset == 0, 'scrolling back up clamps at the top');

    // The wheel gets the same bounded treatment, in either direction.
    state.controls.UI_UP = false;
    FlxG.mouse.wheel = -20;
    state.update(0.016);
    check(state.scrollOffset > 0 && state.scrollOffset <= state.maxScroll, 'the mouse wheel scrolls inside the page');
    FlxG.mouse.wheel = 9999;
    state.update(0.016);
    check(state.scrollOffset == 0, 'a big wheel flick up cannot leave the page');
  }

  static function testCopyAndRefresh():Void
  {
    backend.VLog.enabled = true;
    backend.VLog.active = true;
    backend.VLog.lines = ['FRAME one'];
    final state = fresh();
    final first:String = state.report;

    state.controls.ACCEPT = true;
    state.update(0.016);
    check(Clipboard.writes == 1, 'one copy press writes the clipboard once');
    check(Clipboard.text == first, 'the clipboard gets exactly what the screen shows');
    check(state.hintTimer > 0, 'the page answers that the copy happened');

    // The snapshot is stable: it must describe one moment, not race the frames.
    backend.VLog.lines = ['FRAME one', 'FRAME two'];
    state.update(0.016);
    check(state.report == first, 'the snapshot does not drift on its own');
    check(state.reportText.text == first, 'and neither does the rendered text');

    state.controls.ACCEPT = false;
    FlxG.keys.justPressed.R = true;
    state.update(0.016);
    check(state.report != first, 'R is the only thing that re-reads it');
    check(state.report.indexOf('FRAME two') != -1, 'and the refresh sees the new log line');

    // A clipboard that is unavailable has to degrade into a hint.
    Clipboard.fail = true;
    state.copy();
    check(state.hintText.text.indexOf('screenshot') != -1, 'no clipboard becomes a hint, not an exception');
    backend.VLog.enabled = false;
    backend.VLog.active = false;
    backend.VLog.lines = [];
  }

  static function testLeavingIsSingleShot():Void
  {
    final state = fresh();
    state.controls.BACK = true;
    state.update(0.016);
    check(FlxG.switchedToInt.length == 1, 'back leaves once: ' + FlxG.switchedToInt.join(','));
    state.update(0.016);
    state.update(0.016);
    check(FlxG.switchedToInt.length == 1, 'holding back cannot queue a second switch');
    // (which state it goes to is pinned from the source by
    // tests/test_deeplink_diagnostics.py, where the name is unambiguous)
  }

  static function testDestroyReleasesTheCamera():Void
  {
    final state = fresh();
    state.destroy();
    check(FlxG.cameras.removed.length == 1, 'the borrowed camera is taken back');
    check(state.reportCamera == null, 'and not left dangling behind the page');
    check(state.destroyed, 'the base state is destroyed too');
  }
}
