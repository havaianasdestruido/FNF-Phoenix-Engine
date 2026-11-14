package backend;

/** Minimal stand-in for the preference fields `backend.WindowMode` touches. */
class ClientPrefs
{
  public static var windowMode:String = 'Windowed';
  public static var saveRequested:Bool = false;

  public static function saveSettings():Void
  {
    ClientPrefs.saveRequested = true;
  }
}
