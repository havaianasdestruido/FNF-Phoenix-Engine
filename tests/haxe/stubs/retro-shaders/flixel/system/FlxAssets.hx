package flixel.system;

/**
 * Stand-in for the OpenFL/Flixel shader base.
 *
 * The real `FlxShader` gets one field per GLSL uniform from the
 * `@:glFragmentSource` macro, so a hand-written stub would silently accept a
 * uniform name the GLSL never declares. `run-retro-shaders.sh` therefore
 * generates `backend/FlxFixedShader.hx` (which extends this class) from the
 * `uniform` declarations it finds in the shader sources, and this file only has
 * to exist so `shaders.Effect` resolves its `FlxShader` import.
 */
class FlxShader
{
  public function new() {}
}
