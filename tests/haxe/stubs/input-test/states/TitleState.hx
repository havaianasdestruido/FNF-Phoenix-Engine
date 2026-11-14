package states;

import flixel.input.keyboard.FlxKey;

/** Where the engine keeps the player's volume shortcuts (see ClientPrefs.reloadVolumeKeys). */
class TitleState extends backend.MusicBeatState
{
  public static var muteKeys:Array<FlxKey> = [ZERO];
  public static var volumeDownKeys:Array<FlxKey> = [NUMPADMINUS, MINUS];
  public static var volumeUpKeys:Array<FlxKey> = [NUMPADPLUS, PLUS];
}
