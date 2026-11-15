import backend.StdFire;
import lime.app.Application;
import psychlua.StdFireLibrary;
#if android
import lime.system.JNI;
#end

class StdFireSpec
{
  static function check(condition:Bool, message:String):Void
  {
    if (!condition) throw message;
  }

  static function main():Void
  {
    Application.current = new Application();
    var window = Application.current.window;
    var api:Dynamic = StdFireLibrary.createNamespace();
    check(Reflect.isFunction(api.NativeTitleRename), 'title function in namespace');
    check(Reflect.isFunction(api.NativeMSGBox), 'message function in namespace');
    check(Reflect.isFunction(api.NativeWarn), 'warning function in namespace');
    check(api != StdFireLibrary.createNamespace(), 'each interpreter gets its own namespace');

    StdFire.engineTitleChanged('Engine title');
    check(window.title == 'Engine title', 'normal title applied');
    check(api.NativeTitleRename('Fogo 🔥'), 'override accepted');
    check(window.title == 'Fogo 🔥', 'override applied exactly');
    StdFire.engineTitleChanged('Next song');
    check(window.title == 'Fogo 🔥', 'normal engine updates must not erase override');
    Application.current = new Application();
    window = Application.current.window;
    StdFire.engineTitleChanged('Recreated window');
    check(window.title == 'Fogo 🔥', 'override reapplied to a recreated window');
    check(api.NativeTitleRename('Another title'), 'override can be changed');
    check(api.NativeTitleRename(null), 'null restores latest engine title');
    check(window.title == 'Recreated window', 'restore uses latest, not stale, engine title');
    check(api.NativeTitleRename(null), 'reset without override is harmless');
    check(!api.NativeTitleRename('Bad\x00title'), 'embedded NUL title rejected');
    check(window.title == 'Recreated window', 'invalid title leaves the window alone');

    check(!api.NativeMSGBox(null), 'null message rejected');
    check(!api.NativeMSGBox('Bad\x00message'), 'embedded NUL message rejected');
    check(!api.NativeMSGBox('Message', 'Bad\x00title'), 'embedded NUL dialog title rejected');
    check(api.NativeMSGBox('Olá 世界 🔥', 'Dialog title 🌍'), 'dialog accepted');
    #if android
    check(JNI.calls[JNI.calls.length - 1] == 'showMessageBoxUtf8:Olá 世界 🔥|Dialog title 🌍',
      'Android dialog receives exact UTF-8 byte arrays');
    #else
    check(window.alertMessage == 'Olá 世界 🔥' && window.alertTitle == 'Dialog title 🌍', 'dialog text and title forwarded');
    #end
    check(api.NativeMSGBox('Default title'), 'optional dialog title');
    #if android
    check(JNI.calls[JNI.calls.length - 1] == 'showMessageBoxUtf8:Default title|Phoenix Engine', 'default dialog title');
    #else
    check(window.alertTitle == 'Phoenix Engine', 'default dialog title');
    #end

    check(!api.NativeWarn(null), 'null warning rejected');
    check(!api.NativeWarn('  '), 'empty warning rejected');
    check(!api.NativeWarn('Bad\x00message'), 'embedded NUL warning rejected');
    check(!api.NativeWarn('Warning', 'Bad\x00title'), 'embedded NUL warning title rejected');
    #if android
    check(api.NativeWarn('Aviso 🔥', 'Ignored on Android'), 'toast accepted');
    check(JNI.calls[JNI.calls.length - 1] == 'showToastUtf8:Aviso 🔥', 'toast receives exact UTF-8 text');
    check(JNI.calls.indexOf('setAppTitleUtf8:Fogo 🔥') >= 0, 'activity title forwarded as UTF-8 bytes');
    JNI.accept = false;
    check(!api.NativeWarn('Declined'), 'JNI toast refusal returned');
    check(!api.NativeMSGBox('Declined'), 'JNI dialog refusal returned');
    check(!api.NativeTitleRename('Declined'), 'failed rename returned');
    JNI.accept = true;
    #else
    check(!api.NativeWarn('Unsupported in interpreter'), 'unsupported warning never becomes a dialog');
    #end

    Application.current = null;
    #if !android
    check(!api.NativeMSGBox('No window'), 'missing window does not crash');
    check(!api.NativeTitleRename('No window'), 'missing window cannot be renamed');
    #else
    // Android targets the Activity, which can outlive the Lime window object.
    check(api.NativeMSGBox('No Lime window'), 'Android dialog uses the Activity bridge');
    #end
    Sys.println('StdFire facade passed');
  }
}
