package flixel.system;

// Minimal stand-in for the shader uniform that OpenFL's shader macro generates.
class FlxShader
{
  public var uDownscroll:{value:Array<Bool>};

  public function new()
  {
    uDownscroll = {value: []};
  }
}
