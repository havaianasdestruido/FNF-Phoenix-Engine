package backend;

class ScreenLayout
{
  /** The real helper shifts content in for cutouts; 0 keeps the layout maths checkable. */
  public static var leftInset:Float = 0;

  public static function contentLeft(width:Float):Float
    return leftInset;
}
