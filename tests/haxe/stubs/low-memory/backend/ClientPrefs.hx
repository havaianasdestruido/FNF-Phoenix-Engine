package backend;

/** The real override field names, with deliberately non-forced player choices. */
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
  public static var hideHud:Bool = false;
  public static var timeBarType:String = 'Time Left';
  public static var watermarkStyle:String = 'Vanilla';
  public static var botTxtStyle:String = 'Vanilla';
  public static var botWatermark:Bool = true;
  public static var botTxtFade:Bool = true;
  public static var smoothHealth:Bool = true;
  public static var iconBounceType:String = 'New Psych';
  public static var missRating:Bool = true;
  public static var doidoMisses:Bool = true;
  public static var comboStacking:Bool = true;
  public static var laneGlyphs:Bool = true;
  public static var visualBeatIndicator:Bool = true;
  public static var flashing:Bool = true;
  public static var flashIntensity:Float = 0.85;
  public static var reducedMotion:Bool = false;
  public static var cameraFxIntensity:Float = 0.9;
  public static var stageDim:Float = 0.4;
  public static var laneUnderlayAlpha:Float = 0.5;
  public static var highContrast:Bool = true;
  public static var tauntOnGo:Bool = true;
  public static var ghostTapAnim:Bool = true;
  public static var spaceVPose:Bool = true;
  public static var crossFadeMode:String = 'Mid-Fight Masses';
  public static var noteColorStyle:String = 'Quant-Based';
  public static var extraVocals:Bool = true;
  public static var pauseMusic:String = 'Tea Time';
  public static var menuMusicFade:Bool = true;
  public static var missSoundEnabled:Bool = true;
  public static var hitsoundVolume:Float = 0.65;
  public static var metronome:String = 'Every Beat';
  public static var hapticFeedback:String = 'Hits and Misses';
  public static var adaptivePerformance:Bool = false;
  public static var lessBotLag:Bool = false;
  public static var noSpawnFunc:Bool = false;
  public static var noHitFuncs:Bool = false;
  public static var noSkipFuncs:Bool = false;
  public static var menuFramerate:Int = 120;
  public static var focusLostFramerate:Int = 30;
  public static var showCommitWatermark:Bool = true;
  public static var show1PercentLows:Bool = true;
  public static var legacyFPSUI:Bool = true;
  public static var rainbowFPS:Bool = true;
  public static var loadingPieDial:Bool = true;
  public static var alphabetStyle:String = 'Font';
  public static var instantDialogueAdvance:Bool = false;
  public static var dimDialogueBackground:Bool = true;
  public static var hideDialogueBox:Bool = false;
  public static var debugPointingCursor:Bool = true;
  public static var screensaver:Bool = true;
  public static var androidNotifications:Bool = true;
  public static var checkForUpdates:Bool = true;
  public static var downScroll:Bool = true;
  public static var framerate:Int = 240;

  public static var savedValues:Map<String, Dynamic>;
  public static var savedProfile:String;
  public static var savedBaseline:String;

  /** Simulates saving player settings through the LowMemory save window. */
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
