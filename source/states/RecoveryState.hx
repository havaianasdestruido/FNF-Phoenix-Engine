package states;

import backend.RecoveryBoot;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.FlxG;

/** Uses only built-in Flixel text, before preferences or mod assets are read. */
class RecoveryState extends FlxState
{
  var selected:Int = 0;
  var rows:Array<FlxText> = [];
  var choices:Array<Bool> = [true, false, false];
  var labels:Array<String> = ['Start with all mods disabled', 'Start with fresh prefs', 'Start with default resolution / framerate', 'Start normally'];

  override public function create():Void
  {
    super.create();
    FlxG.mouse.visible = true;
    var title = new FlxText(60, 50, 1160, 'Safe Mode: ${RecoveryBoot.failures} unclean starts detected', 28);
    add(title);
    var help = new FlxText(60, 105, 1160, 'Select recovery options, then press Enter on Start. Arrow keys / Space, or click / tap.\nChanges apply for this session; saved files are not deleted.', 20);
    add(help);
    for (i in 0...4)
    {
      var row = new FlxText(80, 200 + i * 70, 1100, '', 24);
      rows.push(row);
      add(row);
    }
    var start = new FlxText(80, 500, 1100, '', 24);
    rows.push(start);
    add(start);
    refresh();
  }

  function refresh():Void
  {
    for (i in 0...rows.length)
    {
      var label = i < 3 ? (choices[i] ? '[X] ' : '[ ] ') + labels[i] : (i == 3 ? labels[3] : 'Start with selected options');
      rows[i].text = (selected == i ? '> ' : '  ') + label;
    }
  }

  function activate():Void
  {
    if (selected < 3) choices[selected] = !choices[selected];
    else
    {
      if (selected == 4)
      {
        RecoveryBoot.disableMods = choices[0];
        RecoveryBoot.freshPrefs = choices[1];
        RecoveryBoot.defaultDisplay = choices[2];
      }
      FlxG.mouse.visible = false;
      #if (mobile && MODS_ALLOWED)
      if (!mobile.CopyState.checkExistingFiles()) FlxG.switchState(mobile.CopyState.new);
      else
      #end
      FlxG.switchState(InitState.new);
    }
    refresh();
  }

  override public function update(elapsed:Float):Void
  {
    super.update(elapsed);
    if (FlxG.keys.justPressed.UP) selected = (selected + 4) % 5;
    if (FlxG.keys.justPressed.DOWN) selected = (selected + 1) % 5;
    if (FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE) activate();
    #if !mobile
    if (FlxG.mouse.justPressed)
      for (i in 0...rows.length)
        if (FlxG.mouse.overlaps(rows[i])) { selected = i; activate(); break; }
    #else
    for (touch in FlxG.touches.list)
      if (touch.justPressed)
        for (i in 0...rows.length)
          if (touch.overlaps(rows[i])) { selected = i; activate(); break; }
    #end
    refresh();
  }
}
