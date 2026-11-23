package lime.app;

/**
 * Minimal Application stand-in: a single current window double whose alerts
 * are recorded, mirroring lime's Application.current.
 */
class Application
{
  /** The global current application, as in lime. */
  public static var current:Application = new Application();

  /** Backing window double; specs read `current.window.alerts`. */
  public var window:Window;

  public function new()
  {
    window = new Window();
  }
}
