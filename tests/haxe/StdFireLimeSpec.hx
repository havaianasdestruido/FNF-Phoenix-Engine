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
    StdFire.engineTitleChanged('Engine 🌍');
    check(window.title == 'Engine 🌍', 'engine title reaches Lime intact');
    var title = 'Título 世界 🔥';
    check(StdFire.nativeTitleRename(title), 'Unicode title accepted');
    check(window.title == title, 'Lime caches exact Unicode title');
    check(Reflect.field(StdFire, 'titleOverride') == null, 'active override is not exposed through native reflection');
    check(Reflect.field(StdFire, 'engineTitle') == null, 'engine title state is not exposed through native reflection');
    StdFire.engineTitleChanged('New engine 🌍');
    check(window.title == title, 'engine title update preserves override');
    check(StdFire.nativeTitleRename(null), 'reset accepted');
    check(window.title == 'New engine 🌍', 'reset restores latest Unicode engine title');
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
