package flixel;

import flixel.input.gamepad.FlxGamepad;
import flixel.input.keyboard.FlxKey;
import openfl.events.KeyboardEvent;

/** The stage's key events. Listeners are kept so the spec can type and can catch a leaked one. */
class FlxStage
{
  var listeners:Map<String, Array<KeyboardEvent->Void>> = [];

  public function new() {}

  public function addEventListener(type:String, listener:KeyboardEvent->Void):Void
  {
    if (!listeners.exists(type)) listeners.set(type, []);
    listeners.get(type).push(listener);
  }

  public function removeEventListener(type:String, listener:KeyboardEvent->Void):Void
  {
    final list:Array<KeyboardEvent->Void> = listeners.get(type);
    if (list == null) return;
    var index:Int = list.length;
    while (index-- > 0)
      if (Reflect.compareMethods(list[index], listener)) list.splice(index, 1);
  }

  /** Spec helper: delivers one key event the way OpenFL does, outside the update loop. */
  public function key(type:String, keyCode:Int):Void
  {
    final list:Array<KeyboardEvent->Void> = listeners.get(type);
    if (list == null) return;
    for (listener in list.copy())
      listener(new KeyboardEvent(type, keyCode));
  }

  /** Spec helper: listeners still registered, over every event type. */
  public function listenerCount():Int
  {
    var count:Int = 0;
    for (list in listeners)
      count += list.length;
    return count;
  }
}

class FlxSoundFrontEnd
{
  public var muteKeys:Array<FlxKey> = [];
  public var volumeDownKeys:Array<FlxKey> = [];
  public var volumeUpKeys:Array<FlxKey> = [];

  /** Spec output: every sound the page asked for. */
  public var played:Array<String> = [];

  public function new() {}

  public function play(sound:String):Void
    played.push(sound);
}

class FlxGamepadManager
{
  /** Spec input: the pad in each slot; `null` is an empty slot, as in Flixel. */
  public var pads:Array<FlxGamepad> = [];

  public function new() {}

  public function getByID(id:Int):FlxGamepad
    return id >= 0 && id < pads.length ? pads[id] : null;
}

class FlxTouch
{
  public var touchPointID:Int;
  public var screenX:Int;
  public var screenY:Int;

  /** `false` on the frame after the finger lifted: Flixel keeps it listed once more. */
  public var pressed:Bool = true;

  public function new(touchPointID:Int, screenX:Int, screenY:Int)
  {
    this.touchPointID = touchPointID;
    this.screenX = screenX;
    this.screenY = screenY;
  }
}

class FlxTouchManager
{
  public var list:Array<FlxTouch> = [];

  public function new() {}
}

class FlxMouse
{
  public var visible:Bool = false;
  public var pressed:Bool = false;
  public var screenX:Int = 0;
  public var screenY:Int = 0;

  public function new() {}
}

class FlxG
{
  public static var width:Int = 1280;
  public static var height:Int = 720;
  public static var updateFramerate:Int = 60;

  public static var stage:FlxStage = new FlxStage();
  public static var sound:FlxSoundFrontEnd = new FlxSoundFrontEnd();
  public static var gamepads:FlxGamepadManager = new FlxGamepadManager();
  public static var touches:FlxTouchManager = new FlxTouchManager();
  public static var mouse:FlxMouse = new FlxMouse();

  /** Spec output: the class of every state the page switched to. */
  public static var switched:Array<String> = [];

  public static function switchState(nextState:Void->FlxState):Void
    switched.push(Type.getClassName(Type.getClass(nextState())));

  /** Spec helper: a fresh game, so one case cannot leak into the next. */
  public static function reset():Void
  {
    width = 1280;
    height = 720;
    updateFramerate = 60;
    stage = new FlxStage();
    sound = new FlxSoundFrontEnd();
    gamepads = new FlxGamepadManager();
    touches = new FlxTouchManager();
    mouse = new FlxMouse();
    switched = [];
  }
}
