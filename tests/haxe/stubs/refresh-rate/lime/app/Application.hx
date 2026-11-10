package lime.app;

/** Minimal stand-in for the parts of Lime that backend.MonitorRefreshRate reads. */
class Application
{
  public static var current:Application = null;

  public var window:Window = null;

  public function new() {}
}

class Window
{
  public var displayMode:DisplayMode = null;

  public function new() {}
}

class DisplayMode
{
  public var refreshRate:Int;

  public function new(refreshRate:Int)
  {
    this.refreshRate = refreshRate;
  }
}
