package shaders;

class DistantNoteShader
{
  public var uDownscroll = {value: [false]};
  public var uPivot = {value: [0.42]};
  public var uSpread = {value: [0.8]};

  public function new(downscroll:Bool = false)
  {
    uDownscroll.value = [downscroll];
  }
}
