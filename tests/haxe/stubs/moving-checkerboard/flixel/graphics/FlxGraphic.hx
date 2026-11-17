package flixel.graphics;

/** Minimal stand-in for the texture handle `backend.Paths.image()` returns. */
class FlxGraphic
{
  /** Asset key the production code asked for, kept so a spec can read it back. */
  public var key:String;

  public function new(key:String)
  {
    this.key = key;
  }
}
