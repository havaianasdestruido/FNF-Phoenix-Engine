package backend;

/** The preference surface backend.DiagnosticsReport reads. */
class ClientPrefs
{
  public static var resolution:String = '1280x720';
  public static var framerate:Int = 60;
  public static var widescreen:Bool = false;
  public static var lowQuality:Bool = false;
  public static var globalAntialiasing:Bool = true;
  public static var shaders:Bool = true;
  public static var cacheOnGPU:Bool = false;
  public static var enableGC:Bool = true;
  public static var noteSpawnTime:Float = 1;
  public static var noteSplashes:Bool = true;
  public static var maxSplashLimit:Int = 16;
  public static var downScroll:Bool = false;
  public static var middleScroll:Bool = false;
  public static var distantNotes:Bool = false;
  public static var ghostTapping:Bool = true;
  public static var noteSkin:String = 'Default';
  public static var splashType:String = 'Default';
  public static var vlogEnabled:Bool = false;
  public static var frameProfiler:Bool = false;
  public static var debugInfo:Bool = false;
  public static var showRamGraph:Bool = false;
  public static var checkForUpdates:Bool = true;
  public static var discordRPC:Bool = true;
  public static var deeplinkEnabled:Bool = false;
  public static var antiCheatEnable:Bool = false;
}
