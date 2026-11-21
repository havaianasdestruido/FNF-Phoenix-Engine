package play;

import objects.StrumNote;

class PlayState
{
  public static var instance:PlayState = new PlayState();

  public var playbackRate:Float = 1;
  public var strumLineNotes:StrumGroup = new StrumGroup();
  public var modchartTweens:Map<String, Dynamic> = new Map();
  public var modchartTimers:Map<String, Dynamic> = new Map();

  public function new() {}

  public function callOnLuas(name:String, args:Array<Dynamic>):Void {}
}

class StrumGroup
{
  public var members:Array<StrumNote> = [for (_ in 0...8) new StrumNote()];
  public var length(get, never):Int;

  public function new() {}

  function get_length():Int return members.length;
}
