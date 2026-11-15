package play;

import psychlua.FunkinLua;

class PlayState
{
  public static var instance:PlayState;
  public var luaArray:Array<FunkinLua> = [];

  public function new() {}
}
