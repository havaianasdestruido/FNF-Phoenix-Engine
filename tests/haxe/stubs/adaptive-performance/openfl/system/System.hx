package openfl.system;
class System
{
  public static var collections:Int = 0;
  public static var fail:Bool = false;
  public static function gc():Void
  {
    collections++;
    if (fail) throw 'test GC failure';
  }
}
