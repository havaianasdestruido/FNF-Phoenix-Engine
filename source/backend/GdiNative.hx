package backend;

/** Internal hxcpp bridge for Windows GDI effects. Public callers use GDIEffects. */
#if (cpp && windows)
@:buildXml('<include name="../../../../source/backend/native/gdi_build.xml" />')
@:cppFileCode('#include "phoenix_gdi.h"')
class GdiNative
{
  @:functionCode('return phoenixGdiInitialize();')
  public static function initialize():Bool
    return false;

  @:functionCode('phoenixGdiShutdown();')
  public static function shutdown():Void
  {
  }

  @:functionCode('phoenixGdiSetElapsedTime(elapsed);')
  public static function setElapsedTime(elapsed:Float):Void
  {
  }

  @:functionCode('phoenixGdiSetPaused(paused);')
  public static function setPaused(paused:Bool):Void
  {
  }

  @:functionCode('return phoenixGdiRegisterEffect(name.c_str());')
  public static function registerEffect(name:String):Bool
    return false;

  @:functionCode('phoenixGdiUnregisterEffect(name.c_str());')
  public static function unregisterEffect(name:String):Void
  {
  }

  @:functionCode('phoenixGdiSetEffectEnabled(name.c_str(), enabled);')
  public static function setEffectEnabled(name:String, enabled:Bool):Void
  {
  }

  @:functionCode('return phoenixGdiGetEffectEnabled(name.c_str());')
  public static function getEffectEnabled(name:String):Bool
    return false;

  @:functionCode('phoenixGdiSetEffectWait(name.c_str(), waitMs);')
  public static function setEffectWait(name:String, waitMs:Float):Void
  {
  }

  @:functionCode('phoenixGdiSetEffectTitleText(name.c_str(), text.c_str());')
  public static function setEffectTitleText(name:String, text:String):Void
  {
  }

  @:functionCode('phoenixGdiDrawIcons();')
  public static function drawIcons():Void
  {
  }

  @:functionCode('phoenixGdiScreenBlink();')
  public static function screenBlink():Void
  {
  }

  @:functionCode('phoenixGdiScreenGlitches();')
  public static function screenGlitches():Void
  {
  }

  @:functionCode('phoenixGdiScreenTunnel();')
  public static function screenTunnel():Void
  {
  }

  @:functionCode('phoenixGdiScreenShake();')
  public static function screenShake():Void
  {
  }

  @:functionCode('phoenixGdiSetCustomTitleText(text.c_str());')
  public static function setCustomTitleText(text:String):Void
  {
  }

  /* ---- HPPD payloads (see docs/GDI_HPPD.md) ---- */

  /** Trigger an HPPD payload by ID (1..63, 69..72, or 101..131 for Death Month). */
  @:functionCode('return phoenixHppdTrigger(id);')
  public static function hppdTrigger(id:Int):Bool
    return false;

  /** Stop every running HPPD payload at its next frame check. */
  @:functionCode('phoenixHppdStopAll();')
  public static function hppdStopAll():Void
  {
  }

  /** Whether an HPPD payload is currently running. */
  @:functionCode('return phoenixHppdIsRunning(id);')
  public static function hppdIsRunning(id:Int):Bool
    return false;

  /** Whether an HPPD payload ID is a heavy (serialized) payload. */
  @:functionCode('return phoenixHppdIsHeavy(id);')
  public static function hppdIsHeavy(id:Int):Bool
    return false;

  /** Number of ported HPPD payloads (light + heavy + Death Month). */
  @:functionCode('return phoenixHppdCount();')
  public static function hppdCount():Int
    return 0;
}
#else
/** Unsupported targets compile to safe no-ops with the same signatures. */
class GdiNative
{
  public static function initialize():Bool
    return false;

  public static function shutdown():Void
  {
  }

  public static function setElapsedTime(elapsed:Float):Void
  {
  }

  public static function setPaused(paused:Bool):Void
  {
  }

  public static function registerEffect(name:String):Bool
    return false;

  public static function unregisterEffect(name:String):Void
  {
  }

  public static function setEffectEnabled(name:String, enabled:Bool):Void
  {
  }

  public static function getEffectEnabled(name:String):Bool
    return false;

  public static function setEffectWait(name:String, waitMs:Float):Void
  {
  }

  public static function setEffectTitleText(name:String, text:String):Void
  {
  }

  public static function drawIcons():Void
  {
  }

  public static function screenBlink():Void
  {
  }

  public static function screenGlitches():Void
  {
  }

  public static function screenTunnel():Void
  {
  }

  public static function screenShake():Void
  {
  }

  public static function setCustomTitleText(text:String):Void
  {
  }

  /* ---- HPPD payloads (see docs/GDI_HPPD.md) ---- */

  public static function hppdTrigger(id:Int):Bool
    return false;

  public static function hppdStopAll():Void
  {
  }

  public static function hppdIsRunning(id:Int):Bool
    return false;

  public static function hppdIsHeavy(id:Int):Bool
    return false;

  public static function hppdCount():Int
    return 0;
}
#end