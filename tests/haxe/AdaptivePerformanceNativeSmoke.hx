import backend.ClientPrefs;
import debug.FrameProfiler;
import flixel.FlxG;
import play.PlayState;
import play.helpers.PlayStateAdaptivePerformance;

/** Native runtime smoke: real OpenFL System.gc(), with game/Flixel doubles. */
@:access(play.helpers.PlayStateAdaptivePerformance)
class AdaptivePerformanceNativeSmoke
{
  static function check(value:Bool, label:String):Void
  {
    if (!value) throw label;
  }

  static function main():Void
  {
    ClientPrefs.adaptivePerformance = true;
    ClientPrefs.noteSplashes = ClientPrefs.ratingPopups = ClientPrefs.camZooms = true;
    ClientPrefs.enableGC = false;
    #if cpp
    // The production PlayState applies this preference to hxcpp at song start.
    cpp.vm.Gc.enable(false);
    #end
    final state = new PlayState();
    FlxG.state = state;
    final adapter = new PlayStateAdaptivePerformance(state);
    var now:Float = 100;

    for (_ in 0...120)
    {
      adapter.sample(now);
      now += 1.0 / 30.0;
    }
    check(adapter.policy.splashesDisabled, 'sustained low FPS disables splashes');
    check(FrameProfiler.begins == 1 && FrameProfiler.ends == 1, 'real GC request completed and was profiled');
    check(state.added.length == 1 && state.added[0].text.indexOf('memory cleanup requested') >= 0,
      'notice reports the actual request');

    for (_ in 0...300)
    {
      adapter.sample(now);
      now += 1.0 / 30.0;
    }
    check(adapter.policy.ratingsDisabled && adapter.policy.cameraZoomsDisabled, 'later reductions work on the runtime');
    check(FrameProfiler.begins == 1 && FrameProfiler.ends == 1, 'GC cooldown prevents an early second request');
    check(ClientPrefs.noteSplashes && ClientPrefs.ratingPopups && ClientPrefs.camZooms && !ClientPrefs.enableGC,
      'neither the cosmetic preferences nor automatic-GC preference changed');
    adapter.destroy();
    check(FlxG.signals.postDraw.listeners.length == 0, 'listener removed on destruction');
    #if cpp
    cpp.vm.Gc.enable(true);
    Sys.println('AdaptivePerformanceNativeSmoke (hxcpp): PASS');
    #else
    Sys.println('AdaptivePerformanceNativeSmoke (Neko): PASS');
    #end
  }
}
