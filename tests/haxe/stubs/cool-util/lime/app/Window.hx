package lime.app;

/**
 * Minimal Window stand-in: alert() records the message/title instead of
 * showing a native dialog.
 */
class Window
{
  /** Alerts raised via alert(), in call order. */
  public var alerts:Array<{message:String, title:String}> = [];

  public function new() {}

  /** Records the alert for the spec to inspect. */
  public function alert(message:String, title:String):Void
  {
    alerts.push({message: message, title: title});
  }
}
