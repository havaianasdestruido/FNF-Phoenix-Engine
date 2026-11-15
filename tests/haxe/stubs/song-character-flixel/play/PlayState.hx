package play;

import flixel.FlxBasic;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import objects.Character;
import objects.Character.Boyfriend;

class PlayState
{
  public static var opponentChart:Bool = false;
  public static var isPixelStage:Bool = false;
  public static var shouldDrainHealth:Bool = false;
  public static var instance:PlayState = null;
  public static var SONG:Dynamic = {song:'test'};
  public var playbackRate:Float = 1;
  public var metadataOnlyCharacters:Bool = false;
  public var songCharacterVisuals:Bool = false;
  public var singDurMult:Float = 1;
  public var GF_X:Float = 0;
  public var GF_Y:Float = 0;
  public var boyfriend:Boyfriend;
  public var dad:Character;
  public var gf:Character;
  public var boyfriendMap:Map<String, Boyfriend> = [];
  public var dadMap:Map<String, Character> = [];
  public var gfMap:Map<String, Character> = [];
  public var boyfriendGroup:FlxSpriteGroup = new FlxSpriteGroup();
  public var dadGroup:FlxSpriteGroup = new FlxSpriteGroup();
  public var gfGroup:FlxSpriteGroup = new FlxSpriteGroup();
  public var bfNoteskin:String = '';
  public var dadNoteskin:String = '';
  public var iconP1:IconStub = new IconStub();
  public var iconP2:IconStub = new IconStub();
  public var botplayTxt:FlxText = null;
  public var scoreTxt:FlxText = null;
  public var opponentDrain:Bool = false;
  public var healthDrainAmount:Float = 0.023;
  public var healthDrainFloor:Float = 0.1;
  public var charChangeTimes:Array<Float> = [];
  public var charChangeNames:Array<String> = [];
  public var charChangeTypes:Array<Int> = [];
  public var strumLineNotes:FlxTypedGroup<StrumStub> = new FlxTypedGroup<StrumStub>();
  public var notes:FlxTypedGroup<NoteStub> = new FlxTypedGroup<NoteStub>();
  public var sustainNotes:FlxTypedGroup<NoteStub> = new FlxTypedGroup<NoteStub>();
  public var scriptNames:Map<String, String> = [];
  public var reloads:Int = 0;

  public function new() {}
  public function setOnLuas(key:String, value:String):Void scriptNames.set(key, value);
  public function reloadHealthBarColors(dad:Array<Int>, bf:Array<Int>):Void reloads++;
}

class IconStub
{
  public var current:String = '';
  public function new() {}
  public function changeIcon(value:String):Void current = value;
}

class StrumStub extends FlxBasic
{
  public var player:Int;
  public var skin:String = '';
  public var useRGBShader:Bool = true;
  public function new(player:Int) { super(); this.player = player; }
  public function updateNoteSkin(value:String):Void skin = value;
}

class NoteStub extends FlxBasic
{
  public function new() super();
  public function updateRGBColors():Void {}
}
