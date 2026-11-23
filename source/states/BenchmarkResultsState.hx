package states;

import backend.BenchmarkKind;
import backend.BenchmarkKindTools;
import backend.ClientPrefs;
import backend.Paths;
import backend.ScreenLayout;
import backend.ViewportVisuals;
import flixel.FlxG;
import flixel.util.FlxAxes;
import lime.system.Clipboard;
import mobile.flixel.FlxVirtualPad;
import options.OptionsState;

/**
 * The page any benchmark lands on — gameplay (Gameplay / Visual / Logic),
 * synthetic or suite.
 *
 * One screen, no scrolling required on a normal display: the frame results
 * at the top (average FPS, 1% low, worst frame — the three numbers that
 * matter, plus update/render split for Visual/Logic), the device it ran on
 * below, and the path of the full `FrameProfiler` export (or the synthetic
 * score block). `A`/`Enter` copies the same text to the clipboard for a bug
 * report, `R` runs the same kind again (or reopens the Benchmark menu for a
 * suite), and `Esc`/`B` returns to the options/benchmark menu.
 *
 * The report itself is assembled in `backend.Benchmark.reportText()` from the
 * summary captured at the end of the run; nothing here re-measures anything,
 * and the screen never writes a file.
 */
class BenchmarkResultsState extends backend.MusicBeatState
{
  static inline final FONT_SIZE:Int = 14;
  static inline final SCROLL_SPEED:Float = 420;
  static inline final WHEEL_STEP:Float = 48;
  static inline final HINT_SECONDS:Float = 4.0;

  var bg:flixel.FlxSprite;
  var titleText:flixel.text.FlxText;
  var subtitleText:flixel.text.FlxText;
  var hintText:flixel.text.FlxText;
  var reportPanel:flixel.FlxSprite;
  var reportText:flixel.text.FlxText;
  var reportCamera:FlxCamera;

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
    if (subtitleText != null)
    {
      subtitleText.fieldWidth = FlxG.width;
      subtitleText.screenCenter(X);
    }
    layoutHint();
    layoutReport();
  }

  override function create()
  {
    final k:Null<BenchmarkKind> = backend.Benchmark.kind;
    final tag:String = k == null ? 'Device Benchmark' : BenchmarkKindTools.displayName(k).toUpperCase();
    final subtitle:String = subtitleFor(k);
    final suffix:String = k == null ? ' - Device Benchmark' : ' - ' + BenchmarkKindTools.windowTitle(k);
    backend.MusicBeatState.windowNameSuffix = suffix;
    persistentUpdate = true;

    super.create();

    bg = new flixel.FlxSprite().loadGraphic(Paths.image('menuDesat'));
    bg.color = 0xFF241F33;
    bg.antialiasing = ClientPrefs.globalAntialiasing;
    ViewportVisuals.cover(bg);
    add(bg);

    titleText = new flixel.text.FlxText(0, 12, FlxG.width, tag, 26);
    titleText.setFormat("VCR OSD Mono", 26, FlxColor.YELLOW, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    titleText.screenCenter(X);
    add(titleText);

    subtitleText = new flixel.text.FlxText(0, 44, FlxG.width, subtitle, 14);
    subtitleText.setFormat("VCR OSD Mono", 14, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    subtitleText.alpha = 0.85;
    subtitleText.screenCenter(X);
    add(subtitleText);

    reportPanel = new flixel.FlxSprite();
    reportPanel.makeGraphic(1, 1, 0xC0000000);
    add(reportPanel);

    reportText = new flixel.text.FlxText(0, 0, 1040, '', FONT_SIZE);
    reportText.setFormat(Paths.font("vcr.ttf"), FONT_SIZE, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    reportText.borderSize = 1;
    reportText.wordWrap = true;
    reportCamera = new FlxCamera();
    reportCamera.bgColor = 0x00000000;
    FlxG.cameras.add(reportCamera, false);
    reportText.cameras = [reportCamera];
    add(reportText);

    // Synthetic/suite are instant; the normal page lets the player rerun the same kind.
    final rerunLabel:String = (k == SYNTHETIC || k == SUITE) ? 'R: suite menu' : 'R: run again';
    baseHint = mobile.MobileControls.enabled
      ? 'A: copy the report   |   B: back'
      : 'Enter/A: copy   |   ' + rerunLabel + '   |   Esc/B: back   |   M: benchmarks';
    hintText = new flixel.text.FlxText(10, 10, FlxG.width - 20, baseHint, 18);
    hintText.setFormat("VCR OSD Mono", 18, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    add(hintText);

    rebuild();
    layoutHint();

    addVirtualPad(UP_DOWN, A_B);
    addVirtualPadCamera();
  }

  static function subtitleFor(k:Null<BenchmarkKind>):String
  {
    if (k == null) return 'fixed chart · botplay · mods disabled · ~60 s';
    return switch (k)
    {
      case GAMEPLAY: 'fixed chart · botplay · mods disabled · ~60 s';
      case VISUAL: 'visual stress · chords + holds + splashes · ~60 s';
      case LOGIC: 'logic stress · jacks + trills + 16ths · ~60 s';
      case SYNTHETIC: 'synthetic · JSON/sort/path/math/alloc · ~2 s · no audio';
      case SUITE: 'suite · synthetic now + visual/logic to complete · combined report';
    };
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
      else if (controls.ACCEPT || FlxG.keys.justPressed.C || FlxG.keys.justPressed.ENTER)
        copy();
      #if desktop
      else if (FlxG.keys.justPressed.R)
        rerun();
      else if (FlxG.keys.justPressed.M)
        openBenchmarkMenu();
      #end
      // Touch: also accept M via gamepad if present.
      if (FlxG.keys.justPressed.M)
        openBenchmarkMenu();
    }

    super.update(elapsed);
  }

  function rebuild():Void
  {
    report = backend.Benchmark.reportText();
    reportText.text = report;
    layoutReport();
  }

  function layoutReport():Void
  {
    if (reportText == null || reportPanel == null || reportCamera == null) return;
    final left:Float = ScreenLayout.contentLeft(FlxG.width) + 60;
    final top:Float = subtitleText == null ? 78 : subtitleText.y + subtitleText.height + 12;
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
      ? 'Copied. Paste it into your bug report - the .log path is in it too.'
      : 'This target has no clipboard, so screenshot this page instead.');
  }

  function rerun():Void
  {
    if (leaving) return;
    leaving = true;
    final k:Null<BenchmarkKind> = backend.Benchmark.kind;
    // Synthetic/suite reruns land on the menu so the player can pick the next chart;
    // gameplay kinds replay the same kind.
    if (k == SYNTHETIC || k == SUITE)
    {
      FlxG.switchState(() -> new BenchmarkMenuState());
      return;
    }
    backend.Benchmark.startKind(k == null ? GAMEPLAY : k);
  }

  function openBenchmarkMenu():Void
  {
    if (leaving) return;
    leaving = true;
    FlxG.switchState(() -> new BenchmarkMenuState());
  }

  function setHint(text:String):Void
  {
    hintText.text = text;
    hintTimer = (text == baseHint) ? 0 : HINT_SECONDS;
    layoutHint();
    layoutReport();
  }

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
    backend.Benchmark.exitRun();
    backend.Paths.playMenuMusic(true);
    FlxG.switchState(() -> new OptionsState());
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
