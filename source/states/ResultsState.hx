package states;

import backend.ClientPrefs;
import backend.CoolUtil;
import backend.MusicBeatState;
import backend.Paths;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.text.FlxTextAlign;
import flixel.text.FlxTextBorderStyle;
import flixel.util.FlxColor;
import mobile.MobileControls;
import play.PlayState;

/** Post-song / post-week summary. Enter/accept or back returns to the menu. */
class ResultsState extends MusicBeatState
{
  static inline final ACCENT:Int = 0xFFFFD166;
  static inline final PANEL:Int = 0xD9181B2B;
  static inline final MUTED:Int = 0xFFB9C0D4;

  final result:ResultsData;
  final storyResults:Bool;
  var leaving:Bool = false;
  var bg:FlxSprite;
  var header:FlxText;
  var subheader:FlxText;
  var footer:FlxText;

  public function new(result:ResultsData, storyResults:Bool)
  {
    super();
    this.result = result;
    this.storyResults = storyResults;
  }

  override function create():Void
  {
    MusicBeatState.windowNameSuffix = ' - Results';
    super.create();

    bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
    bg.color = 0xFF171927;
    bg.alpha = 0.82;
    bg.antialiasing = ClientPrefs.globalAntialiasing;
    bg.setGraphicSize(FlxG.width, FlxG.height);
    bg.updateHitbox();
    add(bg);

    final side:Float = Math.max(22, FlxG.width * 0.035);
    header = new FlxText(side, 16, FlxG.width - side * 2, storyResults ? 'WEEK RESULTS' : 'SONG RESULTS', 28);
    header.setFormat(Paths.font('vcr.ttf'), 28, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    add(header);

    subheader = new FlxText(side, 52, FlxG.width - side * 2, '${result.title}  -  ${result.difficulty}', 17);
    subheader.setFormat(Paths.font('vcr.ttf'), 17, ACCENT, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    add(subheader);

    addMetricCards(side);
    addJudgementsAndHistogram(side);

    footer = new FlxText(side, FlxG.height - 34, FlxG.width - side * 2,
      MobileControls.enabled ? 'A: continue   B: menu' : 'ENTER / SPACE: continue     ESC: menu', 15);
    footer.setFormat(Paths.font('vcr.ttf'), 15, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    add(footer);

    addVirtualPad(NONE, A_B);
    addVirtualPadCamera();
  }

  function panel(x:Float, y:Float, width:Float, height:Float):FlxSprite
  {
    final sprite = new FlxSprite(x, y);
    sprite.makeGraphic(1, 1, PANEL);
    sprite.setGraphicSize(Std.int(width), Std.int(height));
    sprite.updateHitbox();
    add(sprite);
    return sprite;
  }

  function text(x:Float, y:Float, width:Float, value:String, size:Int, color:Int, align:FlxTextAlign = FlxTextAlign.LEFT):FlxText
  {
    final item = new FlxText(x, y, width, value, size);
    item.setFormat(Paths.font('vcr.ttf'), size, color, align, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    item.borderSize = 1;
    add(item);
    return item;
  }

  function addMetricCards(side:Float):Void
  {
    final gap:Float = 12;
    final cardWidth:Float = (FlxG.width - side * 2 - gap * 3) / 4;
    final values:Array<Array<String>> = [
      ['SCORE', PlayState.formatNumber(result.score)],
      ['ACCURACY', '${CoolUtil.floorDecimal(result.accuracy, 2)}%'],
      ['MAX COMBO', PlayState.formatNumber(result.maxCombo)],
      ['PEAK NPS', PlayState.formatNumber(result.peakNPS)]
    ];
    for (i in 0...values.length)
    {
      final x = side + i * (cardWidth + gap);
      panel(x, 88, cardWidth, 80);
      text(x + 8, 99, cardWidth - 16, values[i][0], 13, MUTED, FlxTextAlign.CENTER);
      text(x + 8, 126, cardWidth - 16, values[i][1], 21, i == 1 ? ACCENT : FlxColor.WHITE, FlxTextAlign.CENTER);
    }
  }

  function addJudgementsAndHistogram(side:Float):Void
  {
    final top:Float = 184;
    final panelHeight:Float = FlxG.height - top - 58;
    final gap:Float = 12;
    final contentWidth:Float = FlxG.width - side * 2;
    final judgeWidth:Float = Math.min(320, contentWidth * 0.34);
    final histX:Float = side + judgeWidth + gap;
    final histWidth:Float = contentWidth - judgeWidth - gap;

    panel(side, top, judgeWidth, panelHeight);
    text(side + 14, top + 12, judgeWidth - 28, 'JUDGEMENTS', 17, ACCENT);
    final rows:Array<Array<Dynamic>> = [
      ['Perfect', result.perfects, 0xFFFFE37B],
      ['Sick', result.sicks, 0xFF91E9A8],
      ['Good', result.goods, 0xFF80D8FF],
      ['Bad', result.bads, 0xFFFFA65C],
      ['Poor', result.poors, 0xFFFF758C],
      ['Miss', result.misses, 0xFFE15C6C]
    ];
    var rowY:Float = top + 48;
    for (row in rows)
    {
      text(side + 16, rowY, judgeWidth - 64, row[0], 15, FlxColor.WHITE);
      text(side + judgeWidth - 58, rowY, 42, Std.string(row[1]), 15, row[2], FlxTextAlign.RIGHT);
      rowY += Math.min(34, (panelHeight - 70) / rows.length);
    }
    final tierY:Float = top + panelHeight - 44;
    text(side + 14, tierY, judgeWidth - 28, 'FC TIER: ${result.fcTier}', 17, ACCENT);

    panel(histX, top, histWidth, panelHeight);
    text(histX + 14, top + 12, histWidth - 28, 'HIT OFFSETS  (late  <-  ms  ->  early)', 17, ACCENT);
    drawHistogram(histX + 16, top + 48, histWidth - 32, panelHeight - 96);
  }

  function drawHistogram(x:Float, y:Float, width:Float, height:Float):Void
  {
    final bins:Array<Int> = [for (_ in 0...13) 0];
    for (offset in result.hitOffsets)
    {
      if (Math.isNaN(offset)) continue;
      final index:Int = Std.int(Math.floor((offset + 10) / 20)) + 6;
      bins[Std.int(Math.max(0, Math.min(bins.length - 1, index)))]++;
    }

    var maxCount:Int = 0;
    for (count in bins) if (count > maxCount) maxCount = count;
    final baseline:Float = y + height - 27;
    final gap:Float = 4;
    final barWidth:Float = (width - gap * (bins.length - 1)) / bins.length;
    final chartHeight:Float = Math.max(25, height - 52);

    final axis = new FlxSprite(x, baseline);
    axis.makeGraphic(Std.int(width), 1, 0xFF7B8399);
    add(axis);

    for (i in 0...bins.length)
    {
      final barHeight:Float = maxCount == 0 ? 0 : bins[i] / maxCount * chartHeight;
      final bar = new FlxSprite(x + i * (barWidth + gap), baseline - barHeight);
      bar.makeGraphic(Std.int(Math.max(1, barWidth)), Std.int(Math.max(1, barHeight)), i == 6 ? ACCENT : 0xFF65C7E8);
      if (barHeight <= 0) bar.visible = false;
      add(bar);
      final center:Int = (i - 6) * 20;
      final label:String = i == 0 ? '<-110' : (i == bins.length - 1 ? '>110' : Std.string(center));
      text(x + i * (barWidth + gap) - 3, baseline + 5, barWidth + 6, label, 9, MUTED, FlxTextAlign.CENTER);
      if (bins[i] > 0)
        text(x + i * (barWidth + gap) - 3, baseline - barHeight - 18, barWidth + 6, Std.string(bins[i]), 10, FlxColor.WHITE, FlxTextAlign.CENTER);
    }
    if (result.hitOffsets.length == 0)
      text(x, baseline - chartHeight / 2, width, 'No player hit timing recorded', 15, MUTED, FlxTextAlign.CENTER);
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);
    if (leaving) return;
    if (controls.BACK || FlxG.keys.justPressed.ESCAPE)
      leaveToMenu();
    else if (controls.ACCEPT || FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE)
      leaveToMenu();
  }

  function leaveToMenu():Void
  {
    if (leaving) return;
    leaving = true;
    Paths.playMenuMusic(true);
    if (storyResults)
      FlxG.switchState(new StoryMenuState());
    else
      FlxG.switchState(new FreeplayState());
  }
}
