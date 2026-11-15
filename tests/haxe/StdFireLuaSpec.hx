import backend.ModSecurity;
import backend.ScriptSecurityScanner;
import backend.StdFire;
import hxluajit.Lua;
import hxluajit.LuaL;
import lime.app.Application;
import play.PlayState;
import psychlua.FunkinLua;
import psychlua.FunkinLua.State;
import psychlua.StdFireLibrary;
import utils.PlatformUtil;

/** Runs real LuaJIT with production Convert, a sandbox, and actual native callbacks. */
class StdFireLuaSpec
{
  static function check(condition:Bool, message:String):Void
  {
    if (!condition) throw message;
  }

  static function execute(lua:State, code:String):Void
  {
    var result = LuaL.dostring(lua, code);
    if (result != Lua.OK) throw 'Lua error: ${Lua.tostring(lua, -1)}';
  }

  static function waitForWarning(message:String):Void
  {
    // The Linux notification helper runs off the game thread and can coalesce
    // consecutive requests, so wait for the last requested text, not a count.
    do
    {
      check(PlatformUtil.delivered.wait(5), 'notification worker timed out');
    }
    while (PlatformUtil.lastMessage != message);
  }

  static function newState():State
  {
    var lua = LuaL.newstate();
    LuaL.openlibs(lua);
    execute(lua, ModSecurity.luaBootstrap([]));
    var owner = new FunkinLua();
    owner.lua = lua;
    PlayState.instance.luaArray.push(owner);
    FunkinLua.lastCalledScript = owner;
    StdFireLibrary.installLua(lua);
    return lua;
  }

  static function main():Void
  {
    Application.current = new Application();
    PlayState.instance = new PlayState();
    StdFire.engineTitleChanged('Engine');
    var lua = newState();
    var code = 'assert(type(stdfire) == "table")\n'
      + 'assert(type(stdfire.NativeTitleRename) == "function")\n'
      + 'assert(type(stdfire.NativeMSGBox) == "function")\n'
      + 'assert(type(stdfire.NativeWarn) == "function")\n'
      + 'assert(_G["stdfire.NativeWarn"] == nil)\n'
      + 'assert(not stdfire.NativeMSGBox(nil))\n'
      + 'assert(not stdfire.NativeWarn("  "))\n'
      + 'assert(stdfire.NativeTitleRename("Lua 🔥"))\n'
      + 'assert(stdfire.NativeMSGBox("Lua message"))\n'
      + 'assert(stdfire.NativeMSGBox("Second", "Lua dialog"))\n'
      + 'assert(stdfire.NativeWarn("Lua warning"))\n'
      + 'assert(stdfire.NativeWarn("Second warning", "Lua title"))\n';
    check(ScriptSecurityScanner.scan(code, 'lua').length == 0, 'sandbox accepts Lua API');
    execute(lua, code);
    check(Application.current.window.title == 'Lua 🔥', 'Lua title applied');
    check(Application.current.window.alertMessage == 'Second' && Application.current.window.alertTitle == 'Lua dialog', 'Lua dialog arguments');
    waitForWarning('Second warning');
    check(PlatformUtil.lastMessage == 'Second warning' && PlatformUtil.lastTitle == 'Lua title', 'Lua warning arguments');
    execute(lua, 'assert(stdfire.NativeTitleRename(nil))');
    check(Application.current.window.title == 'Engine', 'Lua nil resets title');

    // Namespaces are per-state, even though the dispatcher stores shared callbacks.
    execute(lua, 'stdfire.NativeWarn = nil');
    var second = newState();
    execute(second, 'assert(type(stdfire.NativeWarn) == "function"); assert(stdfire.NativeWarn("second state"))');
    waitForWarning('second state');
    check(PlatformUtil.lastMessage == 'second state', 'second state keeps its callback');
    Lua.close(second);
    Lua.close(lua);
    Sys.println('StdFire LuaJIT integration passed');
  }
}
