package backend;

import flixel.system.FlxAssets.FlxShader as OriginalFlxShader;

// Minimal stand-in for the engine's GLSL ES fix layer. The real class extends
// FlxShader and only overrides __initGL, so for uniform-wiring purposes the
// constructor signature is all that matters here.
class FlxFixedShader extends OriginalFlxShader
{
  public function new(?save:Bool)
  {
    super();
  }
}
