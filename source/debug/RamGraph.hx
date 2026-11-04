package debug;

import backend.ClientPrefs;
import backend.Paths;
import backend.ScreenLayout;
import debug.mem.GetTotalMemory;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.util.FlxColor;
import openfl.display.Shape;
import utils.MemoryUtil;

/** Compact gameplay-only RAM history, sampled twice a second when enabled. */
class RamGraph extends FlxSpriteGroup
{
  static inline var PANEL_WIDTH:Int = 252;
  static inline var PANEL_HEIGHT:Int = 76;
  static inline var PLOT_LEFT:Int = 8;
  static inline var PLOT_TOP:Int = 22;
  static inline var PLOT_BOTTOM:Int = 68;
  static inline var BAR_WIDTH:Int = 4;
  static inline var BAR_PITCH:Int = 5;
  static inline var SAMPLE_COUNT:Int = 47;
  static inline var SAMPLE_INTERVAL:Float = 0.5;

  var graph:FlxSprite;
  var currentText:FlxText;
  var rangeText:FlxText;
  var history:RamGraphHistory;
  var drawing:Shape;
  var timer:Float = 0;
  var enabled:Bool = false;

  public function new(x:Float, y:Float)
  {
    super(x, y);
    scrollFactor.set();
    history = new RamGraphHistory(SAMPLE_COUNT);
    drawing = new Shape();
    graph = new FlxSprite().makeGraphic(PANEL_WIDTH, PANEL_HEIGHT, FlxColor.TRANSPARENT, true);
    graph.scrollFactor.set();
    add(graph);

    currentText = new FlxText(8, 4, 130, '', 13);
    currentText.setFormat(Paths.font('vcr.ttf'), 13, FlxColor.WHITE);
    currentText.scrollFactor.set();
    add(currentText);

    rangeText = new FlxText(138, 6, 106, '', 10);
    rangeText.setFormat(Paths.font('vcr.ttf'), 10, FlxColor.WHITE, FlxTextAlign.RIGHT);
    rangeText.scrollFactor.set();
    add(rangeText);
    visible = false;
  }

  /** Apply the pause-menu setting immediately, including while gameplay is paused. */
  public function setEnabled(value:Bool):Void
  {
    if (enabled == value) return;
    enabled = value;
    visible = value;
    timer = 0;
    if (value)
    {
      history.clear();
      reposition();
      sample();
    }
  }

  override public function update(elapsed:Float):Void
  {
    super.update(elapsed);
    if (!enabled) return;
    reposition();
    timer += elapsed;
    if (timer >= SAMPLE_INTERVAL)
    {
      // Do not invent duplicate samples after a long frame or pause.
      timer %= SAMPLE_INTERVAL;
      sample();
    }
  }

  function reposition():Void
  {
    x = ScreenLayout.contentLeft(FlxG.width) + 8;
    var top:Float = 52;
    // FPSCounter is an OpenFL sibling of the game, so convert its screen bounds
    // to game coordinates before placing the graph below it (including debug text).
    var fps = Main.fpsVar;
    var scale = FlxG.scaleMode.scale;
    if (ClientPrefs.showFPS && fps != null && fps.visible && scale.x > 0 && scale.y > 0)
    {
      var left = FlxG.game.x + x * scale.x;
      var right = left + PANEL_WIDTH * scale.x;
      if (fps.x < right && fps.x + fps.width > left)
        top = Math.max(top, (fps.y + fps.height - FlxG.game.y) / scale.y + 4);
    }
    y = Math.min(top, Math.max(0, FlxG.height - PANEL_HEIGHT));
  }

  function sample():Void
  {
    // This is the same counter as FPSCounter: process RSS on cpp, managed heap elsewhere.
    var memory:Float = GetTotalMemory.getCurrentRSS();
    history.add(memory);
    if (history.length == 0) return;
    var bounds = history.bounds();
    currentText.text = 'RAM ' + MemoryUtil.formatMemory(history.get(history.length - 1));
    rangeText.text = Math.floor(bounds.min / 1048576) + '-' + Math.ceil(bounds.max / 1048576) + 'MB';
    redraw(bounds.min, bounds.max);
  }

  function redraw(min:Float, max:Float):Void
  {
    var g = drawing.graphics;
    g.clear();
    g.lineStyle(1, 0xFFFFFF, 0.25);
    g.beginFill(0x000000, 0.75);
    g.drawRoundRect(0.5, 0.5, PANEL_WIDTH - 1, PANEL_HEIGHT - 1, 10, 10);
    g.endFill();
    g.lineStyle(1, 0xFFFFFF, 0.16);
    for (i in 1...4)
    {
      var gridY = PLOT_TOP + (PLOT_BOTTOM - PLOT_TOP) * i / 4;
      g.moveTo(PLOT_LEFT, gridY);
      g.lineTo(PANEL_WIDTH - PLOT_LEFT, gridY);
    }
    g.lineStyle();
    var firstX = PLOT_LEFT + (SAMPLE_COUNT - history.length) * BAR_PITCH;
    var previousY:Float = 0;
    for (i in 0...history.length)
    {
      var normalized = (history.get(i) - min) / (max - min);
      var y = PLOT_BOTTOM - normalized * (PLOT_BOTTOM - PLOT_TOP);
      // Colors describe relative height in the displayed range, not system capacity.
      var color:Int = normalized < 0.5
        ? (Std.int(510 * normalized) << 16) | 0xFF00 | Std.int(136 * (1 - normalized * 2))
        : 0xFF0000 | (Std.int(255 - 400 * (normalized - 0.5)) << 8) | Std.int(120 * (normalized - 0.5));
      g.beginFill(color, 0.8);
      g.drawRect(firstX + i * BAR_PITCH, y, BAR_WIDTH, PLOT_BOTTOM - y);
      g.endFill();
    }
    g.lineStyle(2, 0x7DF9FF, 1);
    for (i in 0...history.length)
    {
      var y = PLOT_BOTTOM - (history.get(i) - min) / (max - min) * (PLOT_BOTTOM - PLOT_TOP);
      var x = firstX + i * BAR_PITCH + BAR_WIDTH / 2;
      if (i == 0) g.moveTo(x, y);
      else
      {
        for (step in 1...6)
        {
          var t = step / 5;
          g.lineTo(x - BAR_PITCH + BAR_PITCH * t, RamGraphHistory.interpolate(previousY, y, t));
        }
      }
      previousY = y;
    }
    if (history.length > 0)
    {
      g.lineStyle(1, 0x7DF9FF, 1);
      g.beginFill(0xFFFFFF);
      g.drawCircle(firstX + (history.length - 1) * BAR_PITCH + BAR_WIDTH / 2, previousY, 2);
      g.endFill();
    }
    graph.pixels.fillRect(graph.pixels.rect, 0x00000000);
    graph.pixels.draw(drawing);
    graph.dirty = true;
  }
}
