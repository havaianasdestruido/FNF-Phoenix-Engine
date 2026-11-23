import psychlua.FunkinLua;
import psychlua.TweenValueValidation;
import psychlua.callbacks.TweenCallbacks;
import play.PlayState;

/** Compile and exercise the Lua tween boundary against lightweight Flixel stubs. */
class TweenCallbacksSpec
{
  static function check(condition:Bool, message:String):Void
  {
    if (!condition) throw message;
  }

  static function invoke(name:String, args:Array<Dynamic>):Void
  {
    final callback:Dynamic = FunkinLua.functions.get(name);
    check(callback != null, '$name callback registered');
    Reflect.callMethod(null, callback, args);
  }

  static function main():Void
  {
    final funk = new FunkinLua();
    TweenCallbacks.register(funk);

    final initialCalls:Int = FlxTween.calls;
    final strum = PlayState.instance.strumLineNotes.members[0];
    strum.y = 240;
    invoke('noteTweenY', ['safe-y', 0, '125.5', 0.1, 'linear']);
    check(FlxTween.calls == initialCalls + 1, 'a numeric-string note y goal creates a tween');
    check(Reflect.field(FlxTween.lastValues, 'y') == 125.5, 'the note y goal is normalized before Flixel sees it');

    invoke('noteTweenY', ['nan-y', 0, Math.NaN, 0.1, 'linear']);
    check(FlxTween.calls == initialCalls + 1, 'a NaN note y goal is rejected');

    strum.y = Math.POSITIVE_INFINITY;
    invoke('noteTweenY', ['bad-start-y', 0, 10, 0.1, 'linear']);
    check(FlxTween.calls == initialCalls + 1, 'a non-finite note y start property is rejected');

    funk.nextTarget = {y: 0.0};
    invoke('doTweenY', ['safe-object-y', 'target', 80, 0.1, 'linear']);
    check(FlxTween.calls == initialCalls + 2, 'a numeric object y goal creates a tween');

    funk.nextTarget = {y: 0.0};
    invoke('startTween', ['safe-generic-y', 'target', {y: '42'}, 0.1, null]);
    check(FlxTween.calls == initialCalls + 3, 'startTween validates and accepts numeric-string goals');
    check(Reflect.field(FlxTween.lastValues, 'y') == 42.0, 'startTween normalizes generic tween goals');

    funk.nextTarget = {y: 0.0};
    invoke('startTween', ['bad-generic-y', 'target', {y: Math.NEGATIVE_INFINITY}, 0.1, null]);
    check(FlxTween.calls == initialCalls + 3, 'startTween rejects non-finite goals');

    Sys.println('TweenCallbacksSpec: PASS');
  }
}
