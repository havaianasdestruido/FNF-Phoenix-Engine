package backend;

/**
 * Engine-side wiring for `backend.LuaDiagnostics`: where its lines go and
 * what turns the verbose level on. Kept apart from the diagnostics rules so
 * those stay dependency-free (see `tests/haxe/LuaDiagnosticsSpec.hx`).
 */
class LuaDiagnosticsSetup
{
  /**
   * Called once from `Main`, after `RuntimeFlags.load()` and `VLog.init()`.
   * `savedPreference` is `ClientPrefs.luaVerbose` as read straight from the
   * save file, because `ClientPrefs.loadPrefs()` has not run yet. A Safe Mode
   * boot passes `false` and leaves it to the `sync()` in `InitState`.
   */
  public static function init(savedPreference:Bool):Void
  {
    LuaDiagnostics.sink = writeLine;
    sync(savedPreference);

    // A C++ build is where players expect Lua. When the VM was left out, say
    // so at boot instead of leaving every .lua file silently ignored.
    #if (cpp && !LUA_ALLOWED)
    if (!LuaDiagnostics.verbose) LuaDiagnostics.emit(LuaDiagnostics.buildSupportLine());
    #end
  }

  /**
   * Re-evaluate the verbose switch. Any one of these turns it on: the
   * option, `flags.ini` (`[scripts] verboseLua = true`), the
   * `PHOENIX_LUA_VERBOSE` environment variable, or a build made with
   * `-DLUA_VERBOSE`.
   */
  public static function sync(?preference:Null<Bool>):Void
  {
    final wanted:Bool = preference == null ? ClientPrefs.luaVerbose : preference;
    var reason:Null<String> = null;
    #if LUA_VERBOSE
    reason = 'built with -DLUA_VERBOSE';
    #end
    if (reason == null && wanted) reason = 'Options -> Misc -> Verbose Lua Logging';
    if (reason == null && RuntimeFlags.getBool(LuaDiagnostics.FLAG_VERBOSE, false)) reason = 'flags.ini [scripts] verboseLua';
    #if sys
    if (reason == null && LuaDiagnostics.isTruthy(Sys.getEnv(LuaDiagnostics.ENV_VERBOSE)))
      reason = LuaDiagnostics.ENV_VERBOSE + ' environment variable';
    #end
    LuaDiagnostics.setVerbose(reason != null, reason);
  }

  static function writeLine(line:String):Void
  {
    #if sys
    Sys.println(line);
    // VLog.log is a no-op until a vlog session is running.
    VLog.log('LUA', line);
    #else
    // No stdout: trace() reaches the browser/debugger console, and the VLog
    // trace hook records it when a session is running.
    trace(line);
    #end
  }
}
