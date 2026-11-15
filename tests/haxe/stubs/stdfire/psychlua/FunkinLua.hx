package psychlua;

#if LUA_ALLOWED
import hxluajit.Types;
typedef State = cpp.RawPointer<Lua_State>;
#end

/** Minimal owner used to exercise the real Convert callback dispatcher. */
class FunkinLua
{
  public static var lastCalledScript:FunkinLua;
  public var lua:State;
  public var sandboxed:Bool = true;
  public var securityAllowlist:Array<String> = [];
  public var securityModName:String = 'test';
  public var scriptName:String = 'mods/test/scripts/stdfire.lua';
  public var callbacks:Map<String, Dynamic> = [];

  public function new() {}

  public function reportSecurityRuntime(capability:String):String return capability;
  public function allowClassAccess(name:String):Bool return false;
}
