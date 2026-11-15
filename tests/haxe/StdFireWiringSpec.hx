import sys.io.File;

/** Guards engine integration sites that need the full Flixel game to instantiate. */
class StdFireWiringSpec
{
  static function before(source:String, first:String, second:String, label:String):Void
  {
    var start = source.indexOf(first);
    var end = source.indexOf(second, start + first.length);
    if (start < 0 || end < 0 || start >= end) throw label;
  }

  static function main():Void
  {
    var lua = File.getContent('source/psychlua/FunkinLua.hx');
    before(lua, 'StdFireLibrary.installLua(lua)', 'LuaL.loadbuffer(lua, source', 'Lua installs stdfire before top-level code');
    var python = File.getContent('source/psychlua/PythonScript.hx');
    before(python, "set('stdfire', StdFireLibrary.createNamespace())", 'interp.execute(parser.parseString(code))',
      'Python installs stdfire before top-level code');

    var gameplay = File.getContent('source/psychlua/HScript.hx');
    before(gameplay, 'seedScope();', 'interp.execute(expr)', 'gameplay HScript seeds before execution');
    if (gameplay.indexOf("interp.variables.set('stdfire', StdFireLibrary.createNamespace())") < 0)
      throw 'gameplay/embedded HScript scope must contain stdfire';
    var state = File.getContent('source/psychlua/HaxeScript.hx');
    before(state, 'seedLibraries();', 'interp.execute(expr)', 'state HScript seeds before execution');
    if (state.indexOf("interp.variables.set('stdfire', StdFireLibrary.createNamespace())") < 0)
      throw 'menu/state HScript scope must contain stdfire';
    for (host in [gameplay, state])
      if (host.indexOf('allowClassAccess(Type.getClassName(resolved))') < 0)
        throw 'both HScript hosts must guard the class resolved by the compatibility fallback';

    var titles = File.getContent('source/backend/MusicBeatState.hx');
    if (titles.split('StdFire.engineTitleChanged(').length != 4 || titles.indexOf('Application.current.window.title =') >= 0)
      throw 'all three normal title updates must respect the stdfire override';

    var facade = File.getContent('source/backend/StdFire.hx');
    before(facade, '#elseif android', 'AndroidStdFire.showMessageBox(message, title)',
      'Android dialog must bypass SDL native NewStringUTF conversion');
    var titleFunction = facade.indexOf('static function setPlatformTitle');
    var androidStart = facade.indexOf('#elseif android', titleFunction);
    var androidEnd = facade.indexOf('#elseif (ios && cpp)', androidStart);
    if (titleFunction < 0 || androidStart < 0 || androidEnd < 0) throw 'Android title branch missing';
    var androidTitle = facade.substring(androidStart, androidEnd);
    if (androidTitle.indexOf('LimeNativeText.cacheTitle(app.window, title)') < 0
        || androidTitle.indexOf('LimeNativeText.setTitle(') >= 0)
      throw 'Android must cache the Lime title without SDL overwriting the Unicode Activity title';
    Sys.println('StdFire host wiring passed');
  }
}
