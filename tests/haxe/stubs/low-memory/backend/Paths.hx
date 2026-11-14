package backend;

class Paths
{
  public static var unused:Int = 0;
  public static var stored:Int = 0;
  public static var compacted:Int = 0;
  public static function clearUnusedMemory():Void unused++;
  public static function clearStoredMemory():Void stored++;
  public static function compress():Void compacted++;
  public static function reset():Void { unused = 0; stored = 0; compacted = 0; }
}
