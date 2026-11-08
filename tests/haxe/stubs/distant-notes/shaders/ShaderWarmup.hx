package shaders;

class ShaderWarmup
{
  public static var tracked:Int = 0;

  public static function track(shader:Dynamic):Void
  {
    tracked++;
  }
}
