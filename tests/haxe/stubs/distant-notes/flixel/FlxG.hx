package flixel;

class FlxG
{
  public static var cameras = new Cameras();
}

private class Cameras
{
  public var list:Array<FlxCamera> = [];

  public function new() {}

  public function add(camera:FlxCamera, defaultTarget:Bool):Void
  {
    list.push(camera);
  }

  public function insert(camera:FlxCamera, position:Int, defaultTarget:Bool):Void
  {
    list.insert(position, camera);
  }
}
