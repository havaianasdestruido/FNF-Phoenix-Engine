package psychlua;

import backend.StdFire;
#if LUA_ALLOWED
import hxluajit.Lua;
import psychlua.FunkinLua.State;
#end

/** The same stdfire namespace is installed in every softmod interpreter. */
class StdFireLibrary
{
  /** A fresh namespace per interpreter; HScript and Hython can call its fields. */
  public static function createNamespace():Dynamic
  {
    return {
      NativeTitleRename: StdFire.nativeTitleRename,
      NativeMSGBox: StdFire.nativeMSGBox,
      NativeWarn: StdFire.nativeWarn
    };
  }

  #if LUA_ALLOWED
  /** Lua needs real C closures inside a table; Convert.toLua cannot marshal functions. */
  public static function installLua(lua:State):Void
  {
    var api = createNamespace();
    Lua.createtable(lua, 0, 3);
    for (name in ["NativeTitleRename", "NativeMSGBox", "NativeWarn"])
    {
      // Convert's callback dispatcher identifies each closure by its upvalue.
      // The temporary global is removed after copying the closure into the table.
      var callbackName = 'stdfire.$name';
      Convert.addCallback(lua, callbackName, Reflect.field(api, name));
      Lua.pushstring(lua, name);
      Lua.getglobal(lua, callbackName);
      Lua.settable(lua, -3);
      Lua.pushnil(lua);
      Lua.setglobal(lua, callbackName);
    }
    Lua.setglobal(lua, "stdfire");
  }
  #end
}
