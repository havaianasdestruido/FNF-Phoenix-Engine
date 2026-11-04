package backend;

class Conductor
{
  public static var bpm:Float = 100;

  public static function changeBPM(newBpm:Float):Void
  {
    bpm = newBpm;
  }
}
