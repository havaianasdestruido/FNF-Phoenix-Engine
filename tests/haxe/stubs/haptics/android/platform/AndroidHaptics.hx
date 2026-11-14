package android.platform;

/** Records bridge calls so the spec can run without JNI or a device. */
class AndroidHaptics
{
  public static var pulses:Array<Int> = [];
  public static var cancels:Int = 0;

  public static function vibrate(durationMs:Int = 50):Void
    pulses.push(durationMs);

  public static function cancel():Void
    cancels++;

  public static function reset():Void
  {
    pulses = [];
    cancels = 0;
  }
}
