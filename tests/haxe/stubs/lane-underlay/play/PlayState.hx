package play;

import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxSprite;

/**
 * The slice of `PlayState` the lane-underlay helper touches: the note camera
 * pair, the overlay slot, the member list and the player strums. Member
 * helpers reproduce `FlxGroup`'s `add`/`insert`/`remove` semantics, including
 * the `null` holes a non-splicing `remove()` leaves behind.
 */
class PlayState
{
  public var camGame = new FlxCamera();
  public var camHUD = new FlxCamera();
  public var camNotes:FlxCamera = null;
  public var laneUnderlayOverlay:FlxSprite;

  public var strumLineNotes:StrumLineNotes = new StrumLineNotes();

  public var members:Array<FlxBasic> = [];

  public static var middleScroll:Bool = false;
  public static var STRUM_X:Float = 48;
  public static var STRUM_X_MIDDLESCROLL:Float = -278;

  public function new() {}

  public function add(basic:FlxBasic):FlxBasic
  {
    if (members.indexOf(basic) >= 0) return basic;
    final hole:Int = members.indexOf(null);
    if (hole >= 0) members[hole] = basic;
    else members.push(basic);
    return basic;
  }

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

  public function remove(basic:FlxBasic, splice:Bool = false):FlxBasic
  {
    final index:Int = members.indexOf(basic);
    if (index < 0) return null;
    if (splice) members.splice(index, 1);
    else members[index] = null;
    return basic;
  }
}
