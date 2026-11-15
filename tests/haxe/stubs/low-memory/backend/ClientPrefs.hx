package backend;

/** The real override field names, with deliberately mixed player choices. */
class ClientPrefs
{
  public static var memoryProfile:String = MemoryProfiles.OFF;
  public static var memoryProfileBaseline:String = '';
  public static var lowMemoryMode:Bool = false;
  public static var lowQuality:Bool = false;
  public static var noteSplashes:Bool = true;
  public static var oppNoteSplashes:Bool = true;
  public static var maxSplashLimit:Int = 16;
  public static var shaders:Bool = true;
  public static var globalAntialiasing:Bool = true;
  public static var camZooms:Bool = true;
  public static var movingMenuCheckerboard:Bool = true;
  public static var charsAndBG:Bool = true;
  public static var enableGC:Bool = false;
  public static var cacheOnGPU:Bool = false;
  public static var preloadNextSong:Bool = true;
  public static var enableColorShader:Bool = true;
  public static var distantNotes:Bool = true;
  public static var alphabetAntialiasing:Bool = true;
  public static var simplePopups:Bool = false;
  public static var ratingPopups:Bool = true;
  public static var comboPopups:Bool = true;
  public static var showMS:Bool = true;
  public static var earlyLateRatings:Bool = true;
  public static var scoreZoom:Bool = true;
  public static var showNPS:Bool = true;
  public static var showComboInfo:Bool = true;
  public static var showRendered:Bool = true;
  public static var opponentLightStrum:Bool = true;
  public static var botLightStrum:Bool = true;
  public static var playerLightStrum:Bool = true;
  public static var showFPS:Bool = true;
  public static var showRamUsage:Bool = true;
  public static var showMaxRamUsage:Bool = true;
  public static var showRamGraph:Bool = true;
  public static var debugInfo:Bool = true;
  public static var frameProfiler:Bool = true;
  public static var tipTexts:Bool = true;
  public static var platformWatermark:Bool = true;
  public static var discordRPC:Bool = true;
  public static var downScroll:Bool = true;

  public static var savedValues:Map<String, Dynamic>;
  public static var savedProfile:String;
  public static var savedBaseline:String;

  public static function saveSettings():Void
  {
    LowMemory.beginSave();
    savedValues = new Map<String, Dynamic>();
    for (field in MemoryProfiles.managedKeys()) savedValues.set(field, Reflect.field(ClientPrefs, field));
    savedProfile = memoryProfile;
    savedBaseline = memoryProfileBaseline;
    LowMemory.endSave();
  }
}
