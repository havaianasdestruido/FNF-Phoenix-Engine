package shaders;

import flixel.FlxG;
import play.PlayState;

/**
 * Frame clock for time-driven shader effects.
 *
 * Effects that animate (`OldTVEffect`, `TVStaticEffect`, `RippleEffect`,
 * `VCRFuzzEffect`) need `elapsed` every frame. Inside a song that clock is
 * `PlayState.shaderUpdates`, which is what the older effects use and which dies
 * with the state. Those effects therefore cannot be built outside `PlayState`,
 * and the title screen / menus are exactly where a TV-static or old-TV filter
 * belongs.
 *
 * This routes the callback to `PlayState.shaderUpdates` while a song is live and
 * to `FlxG.signals.postUpdate` anywhere else, so the same effect class works in
 * every state. Callbacks added outside a song are dropped on the next state
 * switch (`preStateSwitch`, before the incoming state's `create()`), which keeps
 * a menu effect from outliving its screen.
 *
 * Usage:
 * ```haxe
 * shaders.EffectTicker.add(update);   // in the effect's constructor
 * shaders.EffectTicker.remove(update); // if the effect is torn down early
 * ```
 */
class EffectTicker
{
  /** Whether the `postUpdate` / `preStateSwitch` hooks are installed. */
  static var installed:Bool = false;

  /** Callbacks created outside a live `PlayState`, driven by `postUpdate`. */
  static var outside:Array<Float->Void> = [];

  /**
   * Starts ticking `update` once per frame.
   *
   * @param update Callback taking the frame's `elapsed`.
   */
  public static function add(update:Float->Void):Void
  {
    if (update == null) return;

    // A song is live: reuse its clock so the effect freezes with the game and
    // is released with the state.
    final game:PlayState = PlayState.instance;
    if (game != null && FlxG.state == game)
    {
      game.shaderUpdates.push(update);
      return;
    }

    if (!installed)
    {
      installed = true;
      FlxG.signals.postUpdate.add(tick);
      FlxG.signals.preStateSwitch.add(clear);
    }
    outside.push(update);
  }

  /**
   * Stops ticking a callback `add()` registered. Only callbacks on the
   * `postUpdate` path are listed here; song-scoped ones leave with `PlayState`.
   *
   * @param update The same callback passed to `add()`.
   */
  public static function remove(update:Float->Void):Void
  {
    outside.remove(update);
  }

  /** How many callbacks are on the out-of-song path (tests and diagnostics). */
  public static function count():Int
  {
    return outside.length;
  }

  static function tick():Void
  {
    final elapsed:Float = FlxG.elapsed;
    // Indexed loop: no Array iterator allocation per frame, and a callback that
    // removes itself during the tick cannot skip its neighbour.
    var i:Int = 0;
    while (i < outside.length)
    {
      final update:Float->Void = outside[i];
      if (update != null) update(elapsed);
      i++;
    }
  }

  static function clear():Void
  {
    // The state that asked for these effects is gone.
    outside = [];
  }
}
