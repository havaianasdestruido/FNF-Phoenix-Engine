package states;

import backend.ClientPrefs;
import backend.MusicBeatSubstate;
import backend.Paths;
import backend.ScreenLayout;
import backend.StdFireSelfTest;
import backend.StdFireSelfTest.StdFireCheck;
import backend.StdFireSelfTest.StdFireCheckStatus;
import backend.ViewportVisuals;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import mobile.flixel.FlxVirtualPad;

/**
 * The `stdfire` self-test page, opened from the Super Secret Debug Menu.
 *
 * One row per documented `stdfire` behaviour (the interpreter namespace,
 * `NativeTitleRename`, `NativeMSGBox`, `NativeWarn`), each with the status it
 * reached and the sentence describing what was observed. The verification
 * itself lives in `backend.StdFireSelfTest` so the Haxe spec runs exactly the
 * same checks without a game build; this class only drives it and draws it.
 *
 * Entering the page immediately runs the checks that show nothing (namespace,
 * title writes - which always restore the previous title, and the invalid-input
 * rejections). The two rows that display something real are left as READY:
 * select one and press ACCEPT, or press R to run everything including the modal
 * dialog. The modal box blocks the game until dismissed, which is why it is
 * never opened without a deliberate press.
 *
 * Opened as a substate of the debug menu, so Back closes the page and hands the
 * camera back to the menu it came from. Nothing is saved or written to disk.
 */
class StdFireTestState extends MusicBeatSubstate
{
  /** Vertical pitch of one check row. */
  static inline final ROW_HEIGHT:Float = 26;

  static inline final ROW_FONT:Int = 16;
  static inline final DETAIL_FONT:Int = 16;
  static inline final HINT_FONT:Int = 15;

  static final COLOR_PASS:FlxColor = 0xFF7CFC00;
  static final COLOR_FAIL:FlxColor = 0xFFFF5C5C;
  static final COLOR_SKIP:FlxColor = 0xFFB4B4B4;
  static final COLOR_PENDING:FlxColor = 0xFFFFD75C;

  /** The checks themselves, shared with `tests/haxe/StdFireSelfTestSpec.hx`. */
  final selfTest:StdFireSelfTest = new StdFireSelfTest();

  var bg:FlxSprite;
  var titleText:FlxText;
  var summaryText:FlxText;
  var subtitleText:FlxText;
  var highlight:FlxSprite;
  var detailPanel:FlxSprite;
  var detailText:FlxText;
  var hintText:FlxText;
  var rowLabels:Array<FlxText> = [];
  var rowStatuses:Array<FlxText> = [];

  /** Which row ACCEPT runs. */
  var selected:Int = 0;

  /** True while a pass is running, so input cannot start a second one. */
  var running:Bool = false;

  var leaving:Bool = false;

  /** Frames of grace so the press that opened the page cannot run a row. */
  var inputDelay:Float = 0.12;

  /** Title seen on entry; the page restores it if a check ever leaves it behind. */
  var entryTitle:Null<String> = null;

  public function new()
  {
    super();
    // A debug page must not be replaceable by a mod's data/states script.
    scriptsAllowed = false;
  }

  override public function onResize(width:Int, height:Int):Void
  {
    super.onResize(width, height);
    layout();
  }

  override function create():Void
  {
    // Draw on the same camera as the debug menu that opened this page.
    cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
    super.create();

    entryTitle = StdFireSelfTest.currentTitle();

    bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
    bg.color = 0xFF1B1B1B;
    bg.antialiasing = ClientPrefs.globalAntialiasing;
    ViewportVisuals.cover(bg);
    add(bg);

    titleText = new FlxText(0, 12, 0, 'STDFIRE SELF-TEST', 26);
    titleText.setFormat(Paths.font('vcr.ttf'), 26, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    titleText.borderSize = 2;
    add(titleText);

    summaryText = new FlxText(0, 20, 0, '', 16);
    summaryText.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    summaryText.borderSize = 1;
    add(summaryText);

    subtitleText = new FlxText(0, 46, 0,
      'Calls every stdfire function on this device. Nothing is saved, and the title checks always restore the previous title.', 15);
    subtitleText.setFormat(Paths.font('vcr.ttf'), 15, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    subtitleText.borderSize = 1;
    subtitleText.alpha = 0.85;
    add(subtitleText);

    // Added before the rows so the selection bar stays behind their text.
    highlight = new FlxSprite();
    highlight.makeGraphic(1, 1, 0x33FFFFFF);
    add(highlight);

    for (i in 0...selfTest.checks.length)
    {
      final label:FlxText = new FlxText(0, 0, 0, selfTest.checks[i].label, ROW_FONT);
      label.setFormat(Paths.font('vcr.ttf'), ROW_FONT, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
      label.borderSize = 1;
      add(label);
      rowLabels.push(label);

      final status:FlxText = new FlxText(0, 0, 0, '', ROW_FONT);
      status.setFormat(Paths.font('vcr.ttf'), ROW_FONT, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
      status.borderSize = 1;
      add(status);
      rowStatuses.push(status);
    }

    detailPanel = new FlxSprite();
    detailPanel.makeGraphic(1, 1, 0xB0000000);
    add(detailPanel);

    detailText = new FlxText(0, 0, 0, '', DETAIL_FONT);
    detailText.setFormat(Paths.font('vcr.ttf'), DETAIL_FONT, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    detailText.borderSize = 1;
    detailText.wordWrap = true;
    add(detailText);

    hintText = new FlxText(0, 0, 0, '', HINT_FONT);
    hintText.setFormat(Paths.font('vcr.ttf'), HINT_FONT, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    hintText.borderSize = 1;
    hintText.text = mobile.MobileControls.enabled
      ? 'UP/DOWN: pick a row   |   A: run it   |   B: back'
      : 'UP/DOWN: pick   |   ENTER: run the selected row   |   R: run everything   |   ESC: back';
    add(hintText);

    addVirtualPad(UP_DOWN, A_B);
    addVirtualPadCamera();

    selfTest.runAutomatic();
    refresh();
  }

  override function update(elapsed:Float):Void
  {
    if (!leaving && !running)
    {
      if (inputDelay > 0)
      {
        // The ACCEPT that opened this page may still be down on the first frame.
        inputDelay -= elapsed;
      }
      else
      {
        if (controls.UI_UP_P) changeSelection(-1);
        else if (controls.UI_DOWN_P) changeSelection(1);

        if (controls.BACK || FlxG.keys.justPressed.ESCAPE)
        {
          leave();
          return;
        }
        else if (controls.ACCEPT)
          runSelected();
        else if (FlxG.keys.justPressed.R)
          runEverything();
      }
    }
    super.update(elapsed);
  }

  override function destroy():Void
  {
    // Last-resort cleanup: a check that failed halfway can never leave the
    // player looking at the test marker titles forever.
    if (entryTitle != null && StdFireSelfTest.currentTitle() != entryTitle)
      StdFireSelfTest.restoreTitle(entryTitle);
    super.destroy();
  }

  /** Moves the selection, wrapping in both directions. */
  function changeSelection(delta:Int):Void
  {
    if (rowLabels.length == 0) return;
    if (delta != 0) FlxG.sound.play(Paths.sound('scrollMenu'));
    selected = (selected + delta) % rowLabels.length;
    if (selected < 0) selected += rowLabels.length;
    refresh();
  }

  /** Runs only the selected row (which may show a dialog/warning). */
  function runSelected():Void
  {
    final check:StdFireCheck = selfTest.checks[selected];
    if (check == null) return;
    FlxG.sound.play(Paths.sound(check.interactive ? 'confirmMenu' : 'scrollMenu'));
    running = true;
    final status:StdFireCheckStatus = selfTest.runCheck(check.id);
    running = false;
    if (status == StdFireCheckStatus.Failed) FlxG.sound.play(Paths.sound('cancelMenu'));
    refresh();
  }

  /** Runs every row, including the two that display something real. */
  function runEverything():Void
  {
    FlxG.sound.play(Paths.sound('confirmMenu'));
    running = true;
    selfTest.runAll();
    running = false;
    if (selfTest.failures() > 0) FlxG.sound.play(Paths.sound('cancelMenu'));
    refresh();
  }

  /** Closes the page and hands the camera back to the debug menu. */
  function leave():Void
  {
    if (leaving) return;
    leaving = true;
    FlxG.sound.play(Paths.sound('cancelMenu'));
    close();
  }

  /** Rewrites every row and the detail panel from the last results. */
  function refresh():Void
  {
    if (detailText == null) return;

    summaryText.text = 'RESULT:   ' + selfTest.summary();

    for (i in 0...selfTest.checks.length)
    {
      final check:StdFireCheck = selfTest.checks[i];
      final label:FlxText = rowLabels[i];
      final status:FlxText = rowStatuses[i];
      final color:FlxColor = statusColor(check.status);
      final alpha:Float = i == selected ? 1.0 : 0.72;

      label.text = (i == selected ? '> ' : '  ') + check.label;
      label.color = color;
      label.alpha = alpha;

      status.text = statusLabel(check);
      status.color = color;
      status.alpha = alpha;
    }

    final check:StdFireCheck = selfTest.checks[selected];
    detailText.text = check == null ? '' : check.description + '\n\n' + check.detail;
    detailText.alpha = 0.95;

    layout();
  }

  /** Positions everything for the current viewport; safe before `create()` finishes. */
  function layout():Void
  {
    if (bg == null || titleText == null || summaryText == null || subtitleText == null || highlight == null
      || detailPanel == null || detailText == null || hintText == null || rowLabels.length == 0)
      return;

    final left:Float = ScreenLayout.contentLeft(FlxG.width) + 60;
    final width:Float = Math.min(1160, FlxG.width - 120);
    final rowsTop:Float = 88;

    ViewportVisuals.cover(bg);

    titleText.x = left;
    titleText.y = 12;

    summaryText.fieldWidth = width;
    summaryText.x = left;
    summaryText.y = 20;

    subtitleText.fieldWidth = width;
    subtitleText.x = left;
    subtitleText.y = 46;

    for (i in 0...rowLabels.length)
    {
      final label:FlxText = rowLabels[i];
      label.fieldWidth = width - 130;
      label.x = left + 14;
      label.y = rowsTop + i * ROW_HEIGHT + 3;

      final status:FlxText = rowStatuses[i];
      status.fieldWidth = 100;
      status.x = left + width - 114;
      status.y = label.y;
    }

    highlight.setPosition(left, rowsTop + selected * ROW_HEIGHT);
    highlight.setGraphicSize(Std.int(width), Std.int(ROW_HEIGHT - 4));
    highlight.updateHitbox();

    // The hint is laid out first: wrapping it changes its height, and the
    // detail panel ends just above the footer.
    hintText.fieldWidth = FlxG.width - 20;
    hintText.x = 10;
    final hintTop:Float = FlxG.height - hintText.height - 10;
    hintText.y = hintTop;

    final detailTop:Float = rowsTop + rowLabels.length * ROW_HEIGHT + 12;
    final detailHeight:Float = Math.max(80, hintTop - 14 - detailTop);

    detailPanel.setPosition(left, detailTop);
    detailPanel.setGraphicSize(Std.int(width), Std.int(detailHeight));
    detailPanel.updateHitbox();

    detailText.fieldWidth = width - 28;
    detailText.x = left + 14;
    detailText.y = detailTop + 10;
  }

  /** Row color for a result; PENDING/READY stay amber so unrun rows stand out. */
  static function statusColor(status:StdFireCheckStatus):FlxColor
  {
    if (status == StdFireCheckStatus.Passed) return COLOR_PASS;
    if (status == StdFireCheckStatus.Failed) return COLOR_FAIL;
    if (status == StdFireCheckStatus.Skipped) return COLOR_SKIP;
    return COLOR_PENDING;
  }

  /** Short status tag shown at the right edge of a row. */
  static function statusLabel(check:StdFireCheck):String
  {
    if (check.status == StdFireCheckStatus.Passed) return 'PASS';
    if (check.status == StdFireCheckStatus.Failed) return 'FAIL';
    if (check.status == StdFireCheckStatus.Skipped) return 'SKIP';
    return check.interactive ? 'READY' : 'PENDING';
  }
}
