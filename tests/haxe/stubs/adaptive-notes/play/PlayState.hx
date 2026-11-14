package play;
import objects.Character;
import objects.Note;
import objects.NoteSplash;
import objects.StrumNote;
import play.objects.SustainSplash;
class PlayState
{
  public static var middleScroll:Bool = false;
  public static var opponentChart:Bool = false;
  public static var isStoryMode:Bool = false;
  public static var STRUM_X:Float = 48;
  public static var STRUM_X_MIDDLESCROLL:Float = -278;
  public var adaptiveSplashesDisabled:Bool = false;
  public var notes:FlxTypedGroup<Note> = new FlxTypedGroup();
  public var sustainNotes:FlxTypedGroup<Note> = new FlxTypedGroup();
  public var killNotes:Array<Note> = [];
  public var grpHoldSplashes:FlxTypedGroup<SustainSplash> = new FlxTypedGroup();
  public var grpNoteSplashes:FlxTypedGroup<NoteSplash> = new FlxTypedGroup();
  public var playerStrums:FlxTypedGroup<StrumNote> = new FlxTypedGroup();
  public var opponentStrums:FlxTypedGroup<StrumNote> = new FlxTypedGroup();
  public var strumLineNotes:FlxTypedGroup<StrumNote> = new FlxTypedGroup();
  public var splashesPerFrame:Array<Int> = [0, 0, 0, 0];
  public var playbackRate:Float = 1;
  public var skipArrowStartTween:Bool = false;
  public var dadNoteskin:String = '';
  public var bfNoteskin:String = '';
  public var dad:Character = new Character();
  public var boyfriend:Character = new Character();
  public var gfGroup:FlxObject = new FlxObject();
  public var dadGroup:FlxObject = new FlxObject();
  public var boyfriendGroup:FlxObject = new FlxObject();
  public var members:Array<FlxObject> = [];
  public function new()
  {
    playerStrums.add(new StrumNote());
    opponentStrums.add(new StrumNote());
  }
  public function insert(index:Int, obj:FlxObject):Void members.push(obj);
}
