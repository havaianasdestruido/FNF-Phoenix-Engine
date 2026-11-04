package play.helpers;

import objects.Note.EventNote;
import play.PlayState;

class PlayStateEvents
{
  public static function eventPushed(state:PlayState, event:EventNote):Void
  {
    switch (event.event)
    {
      case 'Change Character':
        var charType:Int = 0;
        switch (event.value1.toLowerCase())
        {
          case 'gf' | 'girlfriend' | '1': charType = 2;
          case 'dad' | 'opponent' | '0': charType = 1;
          default:
            var parsed:Null<Int> = Std.parseInt(event.value1);
            charType = parsed == null ? 0 : parsed;
        }
        state.charChangeTimes.push(event.strumTime);
        state.charChangeNames.push(event.value2);
        state.charChangeTypes.push(charType);
      case 'Change Note Multiplier':
        var multiplier:Float = Std.parseFloat(event.value1);
        if (Math.isNaN(multiplier)) multiplier = 1;
        state.multiChangeEvents[0].push(event.strumTime);
        state.multiChangeEvents[1].push(multiplier);
    }
  }

  public static function sortByTime(state:PlayState, a:Dynamic, b:Dynamic):Int
  {
    if (a.strumTime < b.strumTime) return -1;
    if (a.strumTime > b.strumTime) return 1;
    return 0;
  }
}
