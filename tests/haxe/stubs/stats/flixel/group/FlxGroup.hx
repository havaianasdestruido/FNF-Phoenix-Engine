package flixel.group;

import flixel.FlxBasic;

class FlxTypedGroup<T:FlxBasic> extends FlxBasic
{
  public var members:Array<T> = [];
  public var length(get, never):Int;

  public function new()
  {
    super();
  }

  function get_length():Int
    return members.length;

  public function add(item:T):T
  {
    members.push(item);
    return item;
  }

  public function remove(item:T, splice:Bool = false):T
  {
    members.remove(item);
    return item;
  }

  public function clear():Void
  {
    members = [];
  }
}

typedef FlxGroup = FlxTypedGroup<FlxBasic>;
