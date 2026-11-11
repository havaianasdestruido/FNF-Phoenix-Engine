package backend;

/** Startup recovery is deliberately separate from the player's save and mod list. */
class RecoveryBoot
{
  public static inline var THRESHOLD:Int = 2;
  public static var failures(default, null):Int = 0;
  public static var disableMods:Bool = false;
  public static var freshPrefs:Bool = false;
  public static var defaultDisplay:Bool = false;
  static var crashed:Bool = false;
  static var markerPath:String = '';

  public static function begin():Void
  {
    failures = 0;
    crashed = false;
    #if sys
    try
    {
      var storage:String = lime.system.System.applicationStorageDirectory;
      if (!sys.FileSystem.exists(storage)) sys.FileSystem.createDirectory(storage);
      markerPath = haxe.io.Path.join([storage, 'phoenix-startup-status.json']);
      var previous:Dynamic = null;
      if (sys.FileSystem.exists(markerPath)) previous = haxe.Json.parse(sys.io.File.getContent(markerPath));
      if (previous != null && previous.dirty == true && Std.isOfType(previous.failures, Int))
        failures = Std.int(Math.min(100, Math.max(0, previous.failures))) + 1;
      sys.io.File.saveContent(markerPath, haxe.Json.stringify({dirty: true, failures: failures}));
    }
    catch (e:Dynamic) trace('Startup recovery tracking unavailable: $e');
    #end
  }

  /** A file cannot have children, so mod lookups cannot find loose files here. */
  public static function disabledModsPath():String
    return markerPath.length > 0 ? markerPath + '/' : 'mods/.phoenix-recovery-disabled/';

  public static function markCrash():Void crashed = true;

  public static function finish(exitCode:Int):Void
  {
    #if sys
    if (exitCode != 0 || crashed || markerPath.length == 0) return;
    try sys.io.File.saveContent(markerPath, haxe.Json.stringify({dirty: false, failures: 0}))
    catch (e:Dynamic) trace('Could not clear startup recovery marker: $e');
    #end
  }
}
