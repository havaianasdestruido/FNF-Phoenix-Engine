package play;

import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxSprite;
import flixel.sound.FlxSound;
import flixel.util.FlxTimer;

/**
 * The slice of `PlayState` the resume-countdown helper touches: the pause
 * bookkeeping, the intro sounds, the script bridge and the member list.
 * Private fields stay private (the helper reaches them via `@:access`).
 */
class PlayState
{
  public var camGame = new FlxCamera();
  public var camHUD = new FlxCamera();
  public var members:Array<FlxBasic> = [];

  public var resumeCountdownActive:Bool = false;
  public var resumeCountdownWanted:Bool = false;
  public var resumeTimer:FlxTimer = null;
  public var paused:Bool = true;
  public var startingSong:Bool = false;
  public var canResync:Bool = true;
  public var playbackRate:Float = 1;

  public var resyncVocalsCalls:Int = 0;
  public var resetRPCCalls:Int = 0;
  public var createdSprites:Array<String> = [];
  public var scriptVariables:Map<String, Dynamic> = [];
  public var scriptLog:Array<String> = [];
  public var scriptsEnabled:Bool = false;
  /** Optional override for `callOnLuas` return values, event -> value. */
  public var scriptHandler:Null<String->Dynamic> = null;

  public static var isPixelStage:Bool = false;
  public static var stageUI:String = 'normal';

  var ffmpegMode:Bool = false;
  var startTimer:FlxTimer = new FlxTimer();
  // Public in the stub (the spec asserts on them); private in the real class.
  public var intro3:FlxSound = new FlxSound();
  public var intro2:FlxSound = new FlxSound();
  public var intro1:FlxSound = new FlxSound();
  public var introGo:FlxSound = new FlxSound();

  public function new() {}

  public function resyncVocals():Void
  {
    resyncVocalsCalls++;
  }

  public function resetRPC(?showTime:Bool = false):Void
  {
    resetRPCCalls++;
  }

  public function hasActiveScripts():Bool
  {
    return scriptsEnabled;
  }

  public function callOnLuas(event:String, ?args:Array<Dynamic> = null, ?ignoreStops:Bool = true, ?exclusions:Array<String> = null, ?excludeValues:Array<Dynamic> = null):Dynamic
  {
    scriptLog.push(event + (args != null ? ':' + args.join(',') : ''));
    return scriptHandler != null ? scriptHandler(event) : null;
  }

  public function setOnScripts(variable:String, arg:Dynamic):Void
  {
    scriptVariables.set(variable, arg);
  }

  public function add(basic:FlxBasic):FlxBasic
  {
    members.push(basic);
    return basic;
  }
}
