class FlxG
{
  public static var mouse:MouseState = new MouseState();
}

class MouseState
{
  public var justPressed:Bool = false;
  public var justPressedMiddle:Bool = false;
  public var justPressedRight:Bool = false;
  public var pressed:Bool = false;
  public var pressedMiddle:Bool = false;
  public var pressedRight:Bool = false;
  public var justReleased:Bool = false;
  public var justReleasedMiddle:Bool = false;
  public var justReleasedRight:Bool = false;

  public function new() {}
}
