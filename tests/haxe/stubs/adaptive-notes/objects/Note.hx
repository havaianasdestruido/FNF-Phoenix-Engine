package objects;
import play.objects.SustainSplash;
class Note
{
  public var alive:Bool = true;
  public var active:Bool = true;
  public var visible:Bool = true;
  public var ignoreNote:Bool = false;
  public var pendingKill:Bool = false;
  public var isSustainNote:Bool = false;
  public var mustPress:Bool = true;
  public var strumTime:Float = 1000;
  public var y:Float = 0;
  public var sustainLength:Float = 250;
  public var parentSL:Float = 250;
  public var noteData:Int = 0;
  public var noteHoldSplash:SustainSplash;
  public function new() {}
  public function kill():Void alive = false;
}
