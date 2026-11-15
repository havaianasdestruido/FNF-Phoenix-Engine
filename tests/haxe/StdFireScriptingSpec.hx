import backend.StdFire;
import backend.ScriptSecurityScanner;
import lime.app.Application;
import psychlua.StdFireLibrary;

/** Runs the actual project-pinned Hython and hscript-improved interpreters. */
class StdFireScriptingSpec
{
  static function check(condition:Bool, message:String):Void
  {
    if (!condition) throw message;
  }

  static function main():Void
  {
    Application.current = new Application();
    StdFire.engineTitleChanged('Engine');

    var py = new paopao.hython.Interp();
    py.allowClassResolve = false; // Same setting as a sandboxed Python mod.
    py.setVar('stdfire', StdFireLibrary.createNamespace());
    var pyResults:Array<Dynamic> = [];
    py.setVar('record', function(value:Dynamic) pyResults.push(value));
    var pythonCode = 'record(stdfire.NativeTitleRename("Python title"))\n'
      + 'record(stdfire.NativeMSGBox("Python message", "Python dialog"))\n'
      + 'record(stdfire.NativeWarn("Python warning"))\n';
    check(ScriptSecurityScanner.scan(pythonCode, 'python').length == 0, 'sandbox accepts Python API');
    py.execute(new paopao.hython.Parser().parseString(pythonCode));
    check(pyResults[0] == true, 'Hython calls title method');
    check(pyResults[1] == true, 'Hython calls dialog method with custom title');
    #if (cpp && linux)
    check(pyResults[2] == true, 'Hython receives native warning result');
    #else
    check(pyResults[2] == false, 'Hython receives unsupported warning result');
    #end
    check(Application.current.window.title == 'Python title', 'Hython changed title');
    check(Application.current.window.alertMessage == 'Python message' && Application.current.window.alertTitle == 'Python dialog',
      'Hython forwarded dialog arguments');
    py.execute(new paopao.hython.Parser().parseString('record(stdfire.NativeTitleRename(None))\n'));
    check(pyResults[3] == true && Application.current.window.title == 'Engine', 'Hython None restores engine title');

    var hx = new hscript.Interp();
    hx.importEnabled = false; // Same setting as a sandboxed standalone HScript mod.
    hx.variables.set('stdfire', StdFireLibrary.createNamespace());
    var hxResults:Array<Dynamic> = [];
    hx.variables.set('record', function(value:Dynamic) hxResults.push(value));
    var hscriptCode = 'record(stdfire.NativeTitleRename("HScript title"));\n'
      + 'record(stdfire.NativeMSGBox("HScript message", "HScript dialog"));\n'
      + 'record(stdfire.NativeWarn("HScript warning"));';
    check(ScriptSecurityScanner.scan(hscriptCode, 'hscript').length == 0, 'sandbox accepts HScript API');
    hx.execute(new hscript.Parser().parseString(hscriptCode));
    check(hxResults[0] == true, 'HScript calls title method');
    check(hxResults[1] == true, 'HScript calls dialog method');
    #if (cpp && linux)
    check(hxResults[2] == true, 'HScript receives native warning result');
    #else
    check(hxResults[2] == false, 'HScript receives unsupported warning result');
    #end
    check(Application.current.window.title == 'HScript title', 'HScript changed title');
    check(Application.current.window.alertTitle == 'HScript dialog', 'HScript forwarded dialog title');
    hx.execute(new hscript.Parser().parseString('record(stdfire.NativeTitleRename(null));'));
    check(hxResults[3] == true && Application.current.window.title == 'Engine', 'HScript null restores engine title');
    Sys.println('StdFire Hython and HScript integration passed');
  }
}
