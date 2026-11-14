package backend;

class PlayerSettings
{
  public static var player1:PlayerSettings = new PlayerSettings();
  public var controls:Controls = new Controls();

  public function new() {}

  public static function reset():Void
  {
    player1 = new PlayerSettings();
  }
}
