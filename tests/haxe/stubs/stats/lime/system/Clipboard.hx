package lime.system;

class Clipboard
{
  public static var writes:Int = 0;
  public static var fail:Bool = false;
  static var stored:String = null;

  public static var text(get, set):String;

  static function get_text():String
    return stored;

  static function set_text(value:String):String
  {
    if (fail) throw 'simulated clipboard failure';
    writes++;
    stored = value;
    return value;
  }

  public static function reset():Void
  {
    writes = 0;
    fail = false;
    stored = null;
  }
}
