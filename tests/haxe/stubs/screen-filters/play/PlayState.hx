package play;

import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxSprite;

/**
 * State stand-in: the cameras, the shared `variables` map and the modchart
 * lookups `ScreenFilters`/`ChainableEffects` resolve names through.
 */
class PlayState
{
  public static var instance:PlayState = null;

  public var camGame:FlxCamera;
  public var camHUD:FlxCamera;
  public var camOther:FlxCamera;
  public var camNotes:FlxCamera = null;
  public var variables:Map<String, Dynamic> = new Map();
  public var modchartSprites:Map<String, FlxSprite> = new Map();
  public var members:Array<FlxBasic> = [];
  /** Stands in for the real `boyfriend` field, which is a sprite tag scripts use. */
  public var boyfriend:FlxSprite = null;

  public function new()
  {
    camGame = new FlxCamera();
    camHUD = new FlxCamera();
    camOther = new FlxCamera();
    instance = this;
  }

  public function getLuaObject(tag:String, ?text:Bool = true):Dynamic
    return modchartSprites.get(tag);

  public function add(Object:FlxBasic):FlxBasic
  {
    members.push(Object);
    return Object;
  }

  public function insert(Position:Int, Object:FlxBasic):FlxBasic
  {
    members.insert(Position, Object);
    return Object;
  }

  public function remove(Object:FlxBasic, Splice:Bool = true):FlxBasic
  {
    members.remove(Object);
    return Object;
  }
}
