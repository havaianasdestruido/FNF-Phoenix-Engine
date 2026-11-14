package states;
import flixel.util.typeLimit.NextState;
class LoadingState extends flixel.FlxState
{
  public var target:NextState;
  public var stopMusic:Bool;
  public var directory:String;
  public function new(target:NextState, stopMusic:Bool, directory:String)
  {
    super(); this.target = target; this.stopMusic = stopMusic; this.directory = directory;
  }
}
