package objects;

import flixel.FlxObject;

class TouchTarget extends FlxObject
{
  public static var nextPressedTarget:FlxObject = null;

  public var target:FlxObject;
  public var onTap:Void->Void;

  public function new(?target:FlxObject, ?onTap:Void->Void)
  {
    super();
    this.target = target;
    this.onTap = onTap;
  }

  public static function justPressedOver(obj:FlxObject):Bool
  {
    if (nextPressedTarget != null && obj == nextPressedTarget)
    {
      nextPressedTarget = null;
      return true;
    }
    return false;
  }
}
