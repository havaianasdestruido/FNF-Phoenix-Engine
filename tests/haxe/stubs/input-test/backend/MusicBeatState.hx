package backend;

import flixel.FlxState;

/** The base state: the page only sets the window title suffix on it. */
class MusicBeatState extends FlxState
{
  public static var windowNameSuffix:String = '';

  public function new()
  {
    super();
  }
}
