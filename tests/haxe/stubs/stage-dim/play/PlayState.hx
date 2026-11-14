package play;

import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxSprite;

/**
 * The slice of `PlayState` the stage-dim helper touches: the camera pair, the
 * overlay slot and the member list (`FlxState` is a container). The member
 * helpers reproduce `FlxGroup`'s real `add`/`insert`/`remove` semantics — the
 * overlay's ordering guarantees depend on them, including the `null` holes that
 * `remove()` without splicing leaves behind.
 */
class PlayState
{
  public var camGame = new FlxCamera();
  public var camHUD = new FlxCamera();
  public var stageDimOverlay:FlxSprite;

  public var members:Array<FlxBasic> = [];

  public function new() {}

  /** `FlxGroup.add()`: reuses the first `null` slot, otherwise appends. */
  public function add(basic:FlxBasic):FlxBasic
  {
    if (members.indexOf(basic) >= 0) return basic;
    final hole:Int = members.indexOf(null);
    if (hole >= 0) members[hole] = basic;
    else members.push(basic);
    return basic;
  }

  /** `FlxGroup.insert()`: reuses a `null` slot only at the exact position. */
  public function insert(position:Int, basic:FlxBasic):FlxBasic
  {
    if (members.indexOf(basic) >= 0) return basic;
    if (position < members.length && members[position] == null)
    {
      members[position] = basic;
      return basic;
    }
    final clamped:Int = position < 0 ? 0 : (position > members.length ? members.length : position);
    members.insert(clamped, basic);
    return basic;
  }

  /** `FlxGroup.remove(basic, splice)`: a hole is left unless `splice` is set. */
  public function remove(basic:FlxBasic, splice:Bool = false):FlxBasic
  {
    final index:Int = members.indexOf(basic);
    if (index < 0) return null;
    if (splice) members.splice(index, 1);
    else members[index] = null;
    return basic;
  }
}
