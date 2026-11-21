/** Minimal `Main` test double exposing OpenFL overlay siblings. */
class Main
{
  public static var fpsVar:FakeOverlay = new FakeOverlay();
  public static var commitWatermark:FakeOverlay = new FakeOverlay();
}

/** Simple display-object stand-in with a `visible` flag. */
class FakeOverlay
{
  public var visible:Bool = true;
  public function new() {}
}
