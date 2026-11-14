package backend;

class Controls
{
  public var UI_UP:Bool = false;
  public var UI_DOWN:Bool = false;
  public var UI_UP_P:Bool = false;
  public var UI_DOWN_P:Bool = false;
  public var UI_LEFT_P:Bool = false;
  public var UI_RIGHT_P:Bool = false;
  public var ACCEPT:Bool = false;
  public var ACCEPT_P:Bool = false;
  public var BACK:Bool = false;
  public var RESET:Bool = false;

  public function new() {}

  public function clear():Void
  {
    UI_UP = UI_DOWN = UI_UP_P = UI_DOWN_P = UI_LEFT_P = UI_RIGHT_P = false;
    ACCEPT = ACCEPT_P = BACK = RESET = false;
  }
}
