package flixel.util.typeLimit;
import flixel.FlxState;
// Mirrors Flixel's instance/class/factory representation and creation semantics.
abstract NextState(Dynamic)
{
  @:from public static function fromState(state:FlxState):NextState return cast state;
  @:from public static function fromMaker(factory:()->FlxState):NextState return cast factory;
  public function createInstance():FlxState
  {
    if (this is FlxState) return cast this;
    if (this is Class) return Type.createInstance(this, []);
    return cast this();
  }
}
