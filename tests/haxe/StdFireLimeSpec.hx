import backend.StdFire;
import lime.app.Application;
import sys.io.File;

/** Real Lime/SDL CFFI regression for hxcpp's smart Unicode strings. */
class StdFireLimeSpec
{
  static function check(condition:Bool, message:String):Void
  {
    if (!condition) throw message;
  }

  static function main():Void
  {
    var app = new Application();
    var window = app.createWindow({title: 'Initial', width: 320, height: 200, context: {hardware: false}});
    check(window != null, 'software SDL window created');
    backend.LimeNativeText.cacheTitle(window, 'Activity 🌍');
    check(window.title == 'Activity 🌍', 'Android cache-only update changes Lime getter');
    window.title = 'Engine'; // The engine continues to use Lime directly.
    var title = 'Título 世界 🔥';
    check(StdFire.nativeTitleRename(title), 'Unicode title accepted');
    check(window.title == title, 'Lime caches exact Unicode title');
    check(Reflect.field(StdFire, 'lastSoftmodTitle') == null, 'softmod title state is not exposed through native reflection');
    check(Reflect.field(StdFire, 'savedTitle') == null, 'saved title state is not exposed through native reflection');
    check(Reflect.field(StdFire, 'lastTitleTarget') == null, 'window reference is not exposed through native reflection');
    check(StdFire.nativeTitleRename(null) && window.title == 'Engine', 'reset restores a still-current softmod title');
    check(StdFire.nativeTitleRename(title), 'Unicode title accepted again');
    window.title = 'New engine';
    check(window.title == 'New engine', 'direct engine title update takes precedence');
    check(StdFire.nativeTitleRename(null), 'reset after engine update accepted');
    check(window.title == 'New engine', 'reset preserves a later engine title');
    check(!StdFire.nativeTitleRename('Bad\x00title'), 'NUL title rejected');
    check(Reflect.field(StdFire, 'desktopWarningMutex') == null, 'worker lock is not exposed to scripts');
    check(Reflect.field(backend.LimeNativeText, 'setTitleMethod') == null, 'native CFFI pointer is not exposed to scripts');

    var message = 'Mensagem 世界 🔥';
    var dialogTitle = 'Aviso 🌍';
    check(StdFire.nativeMSGBox(message, dialogTitle), 'Unicode message accepted');
    var log = Sys.getEnv('PHOENIX_TEST_LIME_ALERT_LOG');
    check(log != null && File.getContent(log) == dialogTitle + '\n' + message,
      'SDL receives the exact UTF-8 dialog title and message');
    Sys.println('StdFire real Lime Unicode integration passed');
  }
}
