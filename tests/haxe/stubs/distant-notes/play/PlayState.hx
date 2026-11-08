package play;

import flixel.FlxCamera;
import shaders.DistantNoteShader;

class PlayState
{
  public var camHUD = new FlxCamera();
  public var camNotes:FlxCamera;
  public var distantNoteShader:DistantNoteShader;

  public function new() {}
}
