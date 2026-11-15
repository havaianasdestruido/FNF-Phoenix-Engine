package openfl.display;

import openfl.filters.BitmapFilter;

/**
 * Minimal DisplayObject stand-in with the behaviour that matters to the filter
 * API, copied from openfl's own accessors: assigning `filters` clones every
 * filter (and clears the list when handed an empty array or null), and the
 * getter hands back a *copy*, so pushing into what it returned loses the
 * filter. That is why `ScreenFilters` rebuilds the array for this kind of
 * target instead of mutating it.
 */
class Sprite
{
  public var x:Float = 0;
  public var y:Float = 0;
  public var width:Float = 0;
  public var height:Float = 0;

  var __filters:Array<BitmapFilter> = null;

  public var filters(get, set):Array<BitmapFilter>;

  public function new() {}

  public function addChild(child:Dynamic):Dynamic
    return child;

  @:noCompletion function get_filters():Array<BitmapFilter>
    return __filters == null ? [] : __filters.copy();

  @:noCompletion function set_filters(value:Array<BitmapFilter>):Array<BitmapFilter>
  {
    if (value != null && value.length > 0)
    {
      final cloned:Array<BitmapFilter> = [];
      for (filter in value) cloned.push(untyped filter.clone());
      __filters = cloned;
    }
    else if (__filters != null)
    {
      __filters = null;
    }
    return value;
  }
}
