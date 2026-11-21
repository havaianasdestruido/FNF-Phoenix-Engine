package states;

import backend.BenchmarkKind;
import backend.BenchmarkKindTools;
import backend.ClientPrefs;
import backend.Paths;
import backend.ScreenLayout;
import backend.ViewportVisuals;
import flixel.FlxG;
import mobile.flixel.FlxVirtualPad;
import options.OptionsState;

/**
 * The hub that the expanded benchmark opens from Options -> Optimization.
 *
 * One row per `BenchmarkKind` (Gameplay / Visual Stress / Logic Stress /
 * Synthetic / Full Suite) plus the device/system summary that the results
 * screen normally shows. Each row explains what it measures, how long it
 * takes, and which subsystem it leans on, so a player can pick \"the one that
 * lags\" instead of waiting 60 s to learn the same thing three times.
 *
 * The menu reuses the `Alphabet` list from the other option screens and
 * honors `RecoveryBoot.modsDisabled()` only for its own display — the real
 * mod suppression is armed by `backend.Benchmark.startKind()` per run.
 * `SYNTHETIC` finishes immediately; the three gameplay kinds go through
 * `LoadingState -> PlayState` with a `FrameProfiler` session and land on
 * `BenchmarkResultsState`.
 */
class BenchmarkMenuState extends backend.MusicBeatState
{
  static inline final ROW_HEIGHT:Float = 48;

  var bg:flixel.FlxSprite;
  var titleText:flixel.text.FlxText;
  var subtitleText:flixel.text.FlxText;
  var infoText:flixel.text.FlxText;
  var hintText:flixel.text.FlxText;

  var entries:Array<BenchmarkKind> = [
    GAMEPLAY, VISUAL, LOGIC, SYNTHETIC, SUITE
  ];
  var curSelected:Int = 0;
  var grpEntries:flixel.group.FlxTypedGroup<objects.Alphabet>;
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
    layoutInfo();
    layoutHint();
  }

  override function create()
  {
    backend.MusicBeatState.windowNameSuffix = " - Benchmarks";
    persistentUpdate = true;
    super.create();

    bg = new flixel.FlxSprite().loadGraphic(Paths.image('menuDesat'));
    bg.color = 0xFF241F33;
    bg.antialiasing = ClientPrefs.globalAntialiasing;
    ViewportVisuals.cover(bg);
    add(bg);

    titleText = new flixel.text.FlxText(0, 10, FlxG.width, 'BENCHMARKS', 28);
    titleText.setFormat("VCR OSD Mono", 28, FlxColor.YELLOW, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    titleText.screenCenter(X);
    add(titleText);

    subtitleText = new flixel.text.FlxText(0, 42, FlxG.width, 'pick what to measure — all mods disabled · botplay', 14);
    subtitleText.setFormat("VCR OSD Mono", 14, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    subtitleText.alpha = 0.85;
    subtitleText.screenCenter(X);
    add(subtitleText);

    grpEntries = new flixel.group.FlxTypedGroup<objects.Alphabet>();
    add(grpEntries);

    for (i in 0...entries.length)
    {
      final k:BenchmarkKind = entries[i];
      final label:String = BenchmarkKindTools.displayName(k).toUpperCase();
      final entry:objects.Alphabet = new objects.Alphabet(0, 0, label, true);
      entry.isMenuItem = true;
      entry.targetY = i;
      entry.y = 100 + i * ROW_HEIGHT;
      entry.x = (FlxG.width - entry.width) / 2;
      grpEntries.add(entry);
    }

    infoText = new flixel.text.FlxText(20, FlxG.height - 110, FlxG.width - 40, '', 16);
    infoText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    infoText.wordWrap = true;
    add(infoText);

    hintText = new flixel.text.FlxText(10, FlxG.height - 30, FlxG.width - 20, '', 16);
    hintText.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    add(hintText);

    changeSelection(0);
    layoutInfo();
    layoutHint();

    addVirtualPad(UP_DOWN, A_B);
    addVirtualPadCamera();
  }

  override function update(elapsed:Float)
  {
    if (!leaving)
    {
      if (controls.UI_UP_P) changeSelection(-1);
      else if (controls.UI_DOWN_P) changeSelection(1);

      if (controls.BACK || FlxG.keys.justPressed.ESCAPE)
        leave();
      else if (controls.ACCEPT || FlxG.keys.justPressed.ENTER)
        launch(entries[curSelected]);
    }
    super.update(elapsed);
  }

  function changeSelection(delta:Int):Void
  {
    if (delta != 0)
      FlxG.sound.play(Paths.sound('scrollMenu'));

    curSelected = (curSelected + delta) % entries.length;
    if (curSelected < 0) curSelected += entries.length;

    for (i in 0...grpEntries.length)
    {
      final e:objects.Alphabet = grpEntries.members[i];
      e.targetY = i - curSelected;
      e.alpha = i == curSelected ? 1.0 : 0.55;
    }

    final k:BenchmarkKind = entries[curSelected];
    // Two-line description: what it measures + duration/hint.
    final desc:String = BenchmarkKindTools.description(k);
    final hint:String = BenchmarkKindTools.runHint(k);
    infoText.text = desc + '\n' + hint;
    layoutInfo();

    final isSynthetic:Bool = k == SYNTHETIC || k == SUITE;
    final verb:String = isSynthetic ? 'A: run  ·  B: back' : 'A: play  ·  B: back';
    hintText.text = mobile.MobileControls.enabled ? verb : verb + '  |  ↑↓: pick';
    layoutHint();
  }

  function layoutInfo():Void
  {
    if (infoText == null) return;
    infoText.fieldWidth = FlxG.width - 40;
    infoText.y = Math.max(100 + entries.length * ROW_HEIGHT + 12, FlxG.height - 110);
    infoText.x = 20;
  }

  function layoutHint():Void
  {
    if (hintText == null) return;
    hintText.fieldWidth = FlxG.width - 20;
    hintText.y = FlxG.height - hintText.height - 10;
    hintText.x = 10;
  }

  function launch(kind:BenchmarkKind):Void
  {
    if (leaving) return;
    leaving = true;
    FlxG.sound.play(Paths.sound('confirmMenu'));
    ClientPrefs.saveSettings();
    // The prompt that the old single-benchmark row showed is folded into the
    // menu itself — each kind's hint already says how long it takes and that
    // nothing is saved. Go straight to the run.
    backend.Benchmark.startKind(kind);
  }

  function leave():Void
  {
    if (leaving) return;
    leaving = true;
    FlxG.sound.play(Paths.sound('cancelMenu'));
    FlxG.switchState(() -> new OptionsState());
  }
}
