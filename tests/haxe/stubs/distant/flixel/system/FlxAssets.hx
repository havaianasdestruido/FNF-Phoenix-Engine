package flixel.system;

// Minimal stand-in for the shader uniform that OpenFL's shader macro generates.
class FlxShader
{
  public var uPivot:{value:Array<Float>};
  public var uSpread:{value:Array<Float>};
  public var uDownscroll:{value:Array<Bool>};

  public function new()
  {
    uPivot = {value: []};
    uSpread = {value: []};
    uDownscroll = {value: []};
  }
}
