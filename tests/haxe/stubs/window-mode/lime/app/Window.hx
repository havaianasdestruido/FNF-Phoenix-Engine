package lime.app;

/** Minimal stand-in for the Lime window `backend.WindowMode` and `WindowModeSpec` touch. */
class Window
{
  // Match Lime's accessor-only properties: a Dynamic field write on hxcpp
  // does not invoke their setters, unlike a real reflected property access.
  var _borderless:Bool = false;
  var _fullscreen:Bool = false;
  public var borderless(get, set):Bool;
  public var fullscreen(get, set):Bool;

  function get_borderless():Bool return _borderless;
  function set_borderless(value:Bool):Bool return _borderless = value;
  function get_fullscreen():Bool return _fullscreen;
  function set_fullscreen(value:Bool):Bool return _fullscreen = value;

  public function new() {}
}
