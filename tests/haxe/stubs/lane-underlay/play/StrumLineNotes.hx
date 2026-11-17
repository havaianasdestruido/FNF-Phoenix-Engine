package play;

import flixel.FlxBasic;
import objects.StrumNote;

/** The strum group stand-in, like `FlxTypedGroup` exposes it. */
class StrumLineNotes extends FlxBasic
{
  public var members:Array<StrumNote> = [];

  public function new()
  {
    super();
  }
}
