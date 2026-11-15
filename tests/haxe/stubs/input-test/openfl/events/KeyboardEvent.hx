package openfl.events;

/** The two event names and the one field the page reads. */
class KeyboardEvent
{
  public static inline var KEY_DOWN:String = 'keyDown';
  public static inline var KEY_UP:String = 'keyUp';

  public var type:String;
  public var keyCode:Int;

  public function new(type:String, keyCode:Int = 0)
  {
    this.type = type;
    this.keyCode = keyCode;
  }
}
