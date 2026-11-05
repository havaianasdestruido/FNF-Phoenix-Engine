package states;

import backend.ClientPrefs;
import backend.DiagnosticsReport;
import backend.MusicBeatState;
import backend.Paths;
import backend.ScreenLayout;
import backend.ViewportVisuals;
import flixel.util.FlxAxes;
import lime.system.Clipboard;
import mobile.flixel.FlxVirtualPad;

/**
 * The read-only diagnostics page — the destination of `phoenix://diagnostics`.
 *
 * It shows one snapshot of `backend.DiagnosticsReport` (build, hardware,
 * runtime, files, mods, settings, last log lines) sized so a single screenshot
 * carries the whole story, which is the point: support can send one link, the
 * player taps it, and screenshots what opens.
 *
 * Nothing here changes. The page does not write a file, does not touch
 * preferences or save data, and unlike the other menus it deliberately does
 * *not* call `Paths.clearStoredMemory()`/`clearUnusedMemory()` on entry —
 * freeing assets would rewrite the very memory numbers the screenshot is meant
 * to show. `R` re-reads the snapshot, `copy` puts the same text on the
 * clipboard for a bug report, and Back leaves through the Main Menu.
 *
 * Navigation here is decided by `backend.deeplink.DeepLinks`, which only
 * dispatches from an idle Title or Main Menu, so the page never interrupts
 * gameplay, an edit session or the settings.
 */
class DiagnosticsState extends MusicBeatState
{
  /** Small enough that a whole snapshot fits one screenshot at 1280x720. */
  static inline final FONT_SIZE:Int = 14;

  /** Keyboard scroll speed, in pixels per second. */
  static inline final SCROLL_SPEED:Float = 420;

  /** Lines the mouse wheel moves per notch. */
  static inline final WHEEL_STEP:Float = 48;

  /** How long a copy result stays on the hint line before the keys return. */
  static inline final HINT_SECONDS:Float = 4.0;

  var bg:FlxSprite;
  var titleText:FlxText;
  var hintText:FlxText;
  var reportPanel:FlxSprite;
  var reportText:FlxText;
  var reportCamera:FlxCamera;

  /** The snapshot this page is showing, kept so copy and refresh stay in sync. */
  var report:String = '';
  var baseHint:String = '';
  var hintTimer:Float = 0;
  var scrollOffset:Float = 0;
  var maxScroll:Float = 0;
  var leaving:Bool = false;

  override public function onResize(width:Int, height:Int):Void
  {
    super.onResize(width, height);
    ViewportVisuals.cover(bg);
    if (titleText != null)
    {
      titleText.fieldWidth = FlxG.width;
      titleText.screenCenter(X);
    }
    if (hintText != null)
      layoutHint();
    layoutReport();
  }

  override function create()
  {
    MusicBeatState.windowNameSuffix = " - Diagnostics";
    persistentUpdate = true;

    super.create();

    bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
    bg.color = FlxColor.GRAY;
    bg.antialiasing = ClientPrefs.globalAntialiasing;
    ViewportVisuals.cover(bg);
    add(bg);

    titleText = new FlxText(0, 12, FlxG.width, 'PHOENIX DIAGNOSTICS (read-only)', 26);
    titleText.setFormat("VCR OSD Mono", 26, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    titleText.screenCenter(X);
    add(titleText);

    reportPanel = new FlxSprite();
    reportPanel.makeGraphic(1, 1, 0xC0000000);
    add(reportPanel);

    reportText = new FlxText(0, 0, 1040, '', FONT_SIZE);
    reportText.setFormat(Paths.font("vcr.ttf"), FONT_SIZE, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    reportText.borderSize = 1;
    reportText.wordWrap = true;
    reportCamera = new FlxCamera();
    reportCamera.bgColor = 0x00000000;
    FlxG.cameras.add(reportCamera, false);
    reportText.cameras = [reportCamera];
    add(reportText);

    baseHint = mobile.MobileControls.enabled
      ? 'Press UP/DOWN to read, A to copy, B to go back.'
      : 'UP/DOWN or mouse wheel: read   |   C: copy the text   |   R: refresh   |   ESC: back to the menu';
    hintText = new FlxText(10, 10, FlxG.width - 20, baseHint, 18);
    hintText.setFormat("VCR OSD Mono", 18, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    add(hintText);

    rebuild();
    layoutHint();

    addVirtualPad(UP_DOWN, A_B);
    addVirtualPadCamera();
  }

  override function update(elapsed:Float)
  {
    var scrollDelta:Float = 0;
    if (controls.UI_UP) scrollDelta -= SCROLL_SPEED * elapsed;
    if (controls.UI_DOWN) scrollDelta += SCROLL_SPEED * elapsed;
    if (FlxG.mouse.wheel != 0) scrollDelta -= FlxG.mouse.wheel * WHEEL_STEP;
    if (scrollDelta != 0 && maxScroll > 0)
    {
      scrollOffset = FlxMath.bound(scrollOffset + scrollDelta, 0, maxScroll);
      reportCamera.scroll.y = scrollOffset;
    }

    if (hintTimer > 0)
    {
      hintTimer -= elapsed;
      if (hintTimer <= 0) setHint(baseHint);
    }

    if (!leaving)
    {
      if (controls.BACK || FlxG.keys.justPressed.ESCAPE)
        leave();
      else if (controls.ACCEPT || FlxG.keys.justPressed.C)
        copy();
      else if (FlxG.keys.justPressed.R)
        rebuild();
    }

    super.update(elapsed);
  }

  /**
   * Reads a fresh snapshot. Deliberately one-shot instead of per frame: the
   * numbers on a support screenshot have to describe the moment it was taken,
   * rebuilding text every frame would fight the scroll position, and re-reading
   * the log tail constantly is I/O nobody asked for.
   */
  function rebuild():Void
  {
    report = DiagnosticsReport.build();
    reportText.text = report;
    layoutReport();
  }

  function layoutReport():Void
  {
    if (reportText == null || reportPanel == null || reportCamera == null) return;
    final left:Float = ScreenLayout.contentLeft(FlxG.width) + 60;
    final top:Float = titleText == null ? 70 : titleText.y + titleText.height + 12;
    final width:Int = Std.int(Math.max(320, Math.min(1160, FlxG.width - 120)));
    final footerTop:Float = hintText == null ? FlxG.height - 70 : FlxG.height - 84;
    final height:Int = Std.int(Math.max(140, footerTop - top - 10));
    reportPanel.setPosition(left, top);
    reportPanel.setGraphicSize(width, height);
    reportPanel.updateHitbox();
    reportText.fieldWidth = width - 32;
    reportText.x = 16;
    reportText.y = 12;
    reportCamera.setPosition(Std.int(left), Std.int(top));
    reportCamera.setSize(width, height);
    maxScroll = Math.max(0, reportText.height + 24 - height);
    scrollOffset = FlxMath.bound(scrollOffset, 0, maxScroll);
    reportCamera.scroll.y = scrollOffset;
  }

  /** Puts the same text a screenshot would carry on the clipboard. */
  function copy():Void
  {
    var copied:Bool = true;
    try
    {
      Clipboard.text = report;
    }
    catch (e:Dynamic)
      copied = false;
    setHint(copied
      ? 'Copied. Paste it straight into your bug report - nothing was saved to a file.'
      : 'This target has no clipboard, so screenshot this page instead.');
  }

  function setHint(text:String):Void
  {
    hintText.text = text;
    hintTimer = (text == baseHint) ? 0 : HINT_SECONDS;
    layoutHint();
    layoutReport();
  }

  /** Keeps the one-line footer inside the window whatever it says. */
  function layoutHint():Void
  {
    if (hintText == null) return;
    hintText.fieldWidth = FlxG.width - 20;
    hintText.y = FlxG.height - hintText.height - 12;
  }

  function leave():Void
  {
    if (leaving) return;
    leaving = true;
    FlxG.switchState(MainMenuState.new);
  }

  override function destroy():Void
  {
    if (reportCamera != null)
    {
      FlxG.cameras.remove(reportCamera);
      reportCamera = null;
    }
    super.destroy();
  }
}
