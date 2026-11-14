package lime.app;

/** Minimal stand-in for the Lime application/window `backend.WindowMode` reads. */
class Application
{
  public static var current:Application = null;

  public var window:Window = null;

  public function new() {}
}
