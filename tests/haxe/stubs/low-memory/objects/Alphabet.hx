package objects;

/** Minimal `Alphabet` test double tracking live reload passes. */
class Alphabet
{
  public static var reloads:Int = 0;

  public var text:String = '';

  public function new() {}

  /** Records a live reload of all active `Alphabet` instances. */
  public static function reloadAll():Void
  {
    reloads++;
  }
}
