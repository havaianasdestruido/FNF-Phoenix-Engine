package lime.app;

/** Minimal stand-in for the Lime application/window `backend.WindowMode` reads. */
class Application
{
  public static var current:Application = null;

  public var window:Window = null;

  public function new() {}
}

class Window
{
  public var borderless:Bool = false;
  public var fullscreen:Bool = false;

  public function new() {}
}
