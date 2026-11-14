package backend;

/** Minimal stand-in for the resolution scaling helpers `backend.WindowMode` calls. */
class CoolUtil
{
  public static var resW:Float = 1;
  public static var resH:Float = 1;

  public static function resetResScale(wid:Int = 1280, height:Int = 720):Void
  {
    CoolUtil.resW = wid;
    CoolUtil.resH = height;
  }
}
