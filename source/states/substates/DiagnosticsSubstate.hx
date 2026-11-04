package states.substates;

import backend.Diagnostics;
import backend.MusicBeatSubstate;
import backend.Paths;
import backend.ScreenLayout;
import backend.ViewportVisuals;
import flixel.text.FlxText;

/**
 * Read-only viewer for the "Copy diagnostics" block.
 *
 * Opened from `Options -> Misc -> "Copy Diagnostics"` after the report was
 * copied. It exists because a phone may not hand the clipboard to the game,
 * and because the player should be able to read *what* is about to be pasted
 * before it leaves the machine: the text is already redacted by
 * `backend.DiagnosticsReport`, and this screen is where that can be checked.
 *
 * The panel is exactly the clipboard text, scrolled, never edited.
 * ACCEPT/BACK copies it once more and closes.
 */
class DiagnosticsSubstate extends MusicBeatSubstate
{
  static inline final FONT_SIZE:Int = 12;
  static inline final LINE_HEIGHT:Float = 14;
  static inline final MARGIN:Int = 28;
  /** Header + hint lines above the report, inside the panel. */
  static inline final TOP_INSET:Int = 58;

  /** Text shown; the same string that was copied. */
  final report:String;
  /** Result message from `Diagnostics.copyToClipboard`, shown in the header. */
  final message:String;

  var background:FlxSprite;
  var panel:FlxSprite;
  var header:FlxText;
  var hint:FlxText;
  var body:FlxText;
  var scroll:Float = 0;

  /**
   * @param report  the diagnostics block to display
   * @param message the short result line ("Diagnostics copied…"), may be null
   */
  public function new(report:String, ?message:String)
  {
    super();
    this.report = report == null ? '' : report;
    this.message = message;
  }

  override function create():Void
  {
    background = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
    background.scrollFactor.set();
    add(background);

    panel = new FlxSprite().makeGraphic(1, 1, 0xFF181818);
    panel.scrollFactor.set();
    add(panel);

    header = new FlxText(0, 0, 0, 'Diagnostics (read-only)', 24);
    header.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.WHITE, FlxTextAlign.LEFT,
      FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    header.scrollFactor.set();
    add(header);

    // The result of the copy stays visible on the screen that proves the text;
    // a failed clipboard now has an obvious "copy again" hint instead.
    final copied:Bool = Diagnostics.lastClipboardOk;
    final hintText:String = (copied ? 'Copied to the clipboard.' : 'Clipboard unavailable — read or retry here.')
      + '\nACCEPT/BACK: copy again & close   UP/DOWN: scroll';
    hint = new FlxText(0, 0, 0, hintText, 14);
    hint.setFormat(Paths.font('vcr.ttf'), 14, copied ? FlxColor.GRAY : 0xFFFFA040, FlxTextAlign.RIGHT);
    hint.scrollFactor.set();
    add(hint);

    body = new FlxText(0, 0, 0, report, FONT_SIZE);
    body.setFormat(Paths.font('vcr.ttf'), FONT_SIZE, FlxColor.WHITE, FlxTextAlign.LEFT);
    body.scrollFactor.set();
    add(body);

    layout();
    addVirtualPad(UP_DOWN, A_B);
    super.create();
  }

  override public function onResize(width:Int, height:Int):Void
  {
    super.onResize(width, height);
    layout();
  }

  /** Places the panel and rewraps the report for the current window. */
  function layout():Void
  {
    if (body == null) return;

    ViewportVisuals.fill(background);

    final contentWidth:Int = Std.int(FlxG.width - MARGIN * 2);
    final contentHeight:Int = Std.int(FlxG.height - MARGIN * 2);

    panel.x = MARGIN - 10;
    panel.y = MARGIN - 10;
    panel.setGraphicSize(contentWidth + 20, contentHeight + 20);
    panel.updateHitbox();

    // Keep the text inside the letterboxed content area on widescreen.
    // contentLeft() returns a Float (it is a fraction of the viewport), and
    // FlxText.x is a Float, so no Int round-trip is needed here.
    final left:Float = ScreenLayout.contentLeft(FlxG.width) + MARGIN;

    header.x = left;
    header.y = MARGIN;

    hint.fieldWidth = contentWidth;
    hint.x = left;
    hint.y = MARGIN;
    hint.alignment = FlxTextAlign.RIGHT;

    body.fieldWidth = contentWidth;
    body.x = left;
    body.updateHitbox();
    clampScroll();
  }

  /** Largest scroll offset that still shows the end of the report. */
  function maxScroll():Float
    return Math.max(0, body.height - Math.max(0, FlxG.height - MARGIN * 2 - TOP_INSET));

  function clampScroll():Void
  {
    scroll = FlxMath.bound(scroll, 0, maxScroll());
    body.y = MARGIN + TOP_INSET - scroll;
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);

    final speed:Float = 600 * elapsed;
    if (controls.UI_DOWN) scroll += speed;
    if (controls.UI_UP) scroll -= speed;

    // Mouse wheel is what a desktop player reaches for first. `wheel` is
    // read-only in Flixel and cleared by it after each frame, so this only
    // reads the delta instead of consuming it.
    if (FlxG.mouse.wheel != 0) scroll -= FlxG.mouse.wheel * LINE_HEIGHT * 3;
    clampScroll();

    if (controls.BACK || controls.ACCEPT)
    {
      // Retry the clipboard here: the first copy may have failed before the
      // OS was ready, and this is the screen where the player notices it.
      Diagnostics.writeClipboard(report);
      FlxG.sound.play(Paths.sound('cancelMenu'));
      close();
    }
  }
}
