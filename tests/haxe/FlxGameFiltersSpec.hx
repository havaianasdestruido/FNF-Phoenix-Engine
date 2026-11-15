
import openfl.filters.BitmapFilter;
import openfl.filters.BlurFilter;
import openfl.filters.GlowFilter;

/**
 * Contract for the `FlxGame` filter patch.
 *
 * `source/source-haxelib-patches/flixel/FlxGame.hx` cannot be compiled on its
 * own — it imports `backend.ClientPrefs`, `play.PlayState` and the rest of the
 * engine — so this spec exercises a `Sprite` subclass that carries the exact
 * accessors the patch adds (`FlxGameFiltersMirror`), and `run-screen-filters.sh`
 * additionally greps the patch file for those declarations. Together they catch
 * both "the behaviour regressed" and "the patch was dropped".
 */
class FlxGameFiltersSpec
{
  static var failures:Int = 0;

  static function check(condition:Bool, message:String):Void
  {
    if (!condition)
    {
      failures++;
      throw 'FlxGameFiltersSpec: $message';
    }
  }

  static function equal(actual:Dynamic, expected:Dynamic, message:String):Void
  {
    final ok:Bool = (actual == expected)
      || (actual != null && expected != null && Std.string(actual) == Std.string(expected));
    if (!ok) throw 'FlxGameFiltersSpec: $message (expected $expected, got $actual)';
  }

  public static function main():Void
  {
    assignmentAppliesImmediately();
    assignedArrayIsCopied();
    theGetterHandsBackTheLiveArray();
    disabledFiltersAreNotPushedToTheDisplayObject();
    setFiltersRoundTrips();
    trace('FlxGameFiltersSpec: ok');
  }

  /**
   * `FlxG.game.filters = [...]` has to reach the renderer without waiting for
   * the next draw tick, because two script calls in the same frame would
   * otherwise clobber each other.
   */
  static function assignmentAppliesImmediately():Void
  {
    final game = new FlxGameFiltersMirror();
    final blur = new BlurFilter(2, 2);
    game.filters = [blur];

    equal(game.displayFilters().length, 1, 'the assignment reaches the DisplayObject at once');
    check(Std.isOfType(game.displayFilters()[0], BlurFilter), 'and it is the filter that was assigned');
  }

  /**
   * The setter keeps a copy, like `FlxCamera.filters`, so a script that hands
   * over its own array can keep using it.
   */
  static function assignedArrayIsCopied():Void
  {
    final game = new FlxGameFiltersMirror();
    final mine:Array<BitmapFilter> = [new BlurFilter()];
    game.filters = mine;
    mine.push(new GlowFilter());

    equal(game.filters.length, 1, 'the engine keeps its own copy of the array');
    check(game.filters != mine, 'the arrays are not the same object');
  }

  /** Pushing into `FlxG.game.filters` is how `ScreenFilters.add()` appends. */
  static function theGetterHandsBackTheLiveArray():Void
  {
    final game = new FlxGameFiltersMirror();
    game.filters = [new BlurFilter()];
    game.filters.push(new GlowFilter());

    equal(game.filters.length, 2, 'the pushed filter survives');
    // The push only reaches the DisplayObject on the next apply, which the draw
    // loop does every frame; calling it by hand is what the loop does.
    game.applyGameFiltersNow();
    equal(game.displayFilters().length, 2, 'the loop apply picks the push up');
  }

  /** `filtersEnabled = false` has to keep winning over the array, every frame. */
  static function disabledFiltersAreNotPushedToTheDisplayObject():Void
  {
    final game = new FlxGameFiltersMirror();
    game.filters = [new BlurFilter()];
    game.filtersEnabled = false;
    game.applyGameFiltersNow();
    equal(game.displayFilters().length, 0, 'a disabled game object renders unfiltered');

    game.filtersEnabled = true;
    game.applyGameFiltersNow();
    equal(game.displayFilters().length, 1, 'and switching it back restores the filter');
  }

  /** The API `setFilters()` already had keeps working for existing callers. */
  static function setFiltersRoundTrips():Void
  {
    final game = new FlxGameFiltersMirror();
    game.setFilters([new GlowFilter()]);
    equal(game.filters.length, 1, 'setFilters writes the property');
    equal(game.displayFilters().length, 1, 'and applies it');

    game.setFilters([]);
    equal(game.filters.length, 0, 'setFilters([]) clears the filters');
    equal(game.displayFilters().length, 0, 'and clears them on the display object');
  }
}
