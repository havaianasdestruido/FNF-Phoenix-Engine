package objects;

class StrumNote
{
  public var x:Float = 0;
  public var y:Float = 0;
  public var angle:Float = 0;
  public var direction:Float = 0;
  public var alpha:Float = 1;
  public var scale:StrumScale = new StrumScale();

  public function new() {}
}

class StrumScale
{
  public var x:Float = 1;
  public var y:Float = 1;

  public function new() {}
}
