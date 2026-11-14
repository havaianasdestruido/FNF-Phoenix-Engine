package flixel.util;

/**
 * Stand-in for `flixel.util.FlxSignal`: `add`/`remove`/`dispatch` with the same
 * shape, so `shaders.EffectTicker` can be driven from a spec. The real signal is
 * an abstract over a callback list; what the production code uses is only
 * `add()`, and the spec calls `dispatch()` to stand in for the frame.
 */
class FlxSignal
{
  var listeners:Array<Void->Void> = [];

  public function new() {}

  public function add(listener:Void->Void):Void
  {
    if (listener != null && listeners.indexOf(listener) < 0) listeners.push(listener);
  }

  public function remove(listener:Void->Void):Void
  {
    listeners.remove(listener);
  }

  public function dispatch():Void
  {
    for (listener in listeners.copy())
      listener();
  }

  /** How many listeners are attached (spec only; the real signal hides this). */
  public function count():Int
  {
    return listeners.length;
  }
}
