import openfl.display.Sprite;
import openfl.filters.BitmapFilter;

/**
 * Mirror of the accessors the `FlxGame` patch
 * (`source/source-haxelib-patches/flixel/FlxGame.hx`) adds.
 *
 * `FlxGame` itself pulls in half the engine, so the spec cannot instantiate it;
 * this class is a `Sprite` with the same three members and the same bodies, and
 * `run-screen-filters.sh` checks the patch file actually declares them.
 * Keep this in sync with the patch.
 */
class FlxGameFiltersMirror extends Sprite
{
  public var filtersEnabled:Bool = true;

  var _filters:Array<BitmapFilter>;

  @:noCompletion override function get_filters():Array<BitmapFilter>
  {
    return _filters;
  }

  @:noCompletion override function set_filters(Value:Array<BitmapFilter>):Array<BitmapFilter>
  {
    _filters = Value == null ? null : Value.copy();
    applyGameFiltersNow();
    return Value;
  }

  @:noCompletion public function applyGameFiltersNow():Void
  {
    @:privateAccess super.filters = filtersEnabled ? _filters : null;
  }

  public function setFilters(filters:Array<BitmapFilter>):Void
  {
    this.filters = filters;
  }

  /**
   * What the renderer actually sees. `super.filters` is the only way to read it
   * once the accessors above are overridden; the spec uses it to prove the
   * filters reach the DisplayObject (and stop reaching it when disabled).
   */
  @:noCompletion public function displayFilters():Array<BitmapFilter>
  {
    return @:privateAccess super.filters;
  }
}
