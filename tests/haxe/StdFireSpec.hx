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

    // Engine code continues to use Lime directly; stdfire does not intercept it.
    window.title = 'Engine title';
    check(api.NativeTitleRename('Fogo 🔥'), 'softmod title accepted');
    check(window.title == 'Fogo 🔥', 'softmod title applied exactly');
    check(api.NativeTitleRename('Another title'), 'softmod title can be changed');
    check(api.NativeTitleRename(null), 'null restores a still-current softmod title');
    check(window.title == 'Engine title', 'reset restores the observed previous title');
    check(api.NativeTitleRename(null), 'reset without a softmod title is harmless');

    check(api.NativeTitleRename('Temporary'), 'temporary title accepted');
    window.title = 'Next song';
    check(window.title == 'Next song', 'direct engine update takes precedence');
    check(api.NativeTitleRename(null), 'reset after engine update is harmless');
    check(window.title == 'Next song', 'reset must not overwrite a later engine title');

    check(api.NativeTitleRename('First softmod title'), 'first title accepted');
    window.title = 'New engine title';
    check(api.NativeTitleRename('Second softmod title'), 'second title accepted');
    check(api.NativeTitleRename(null), 'reset after another softmod title');
    check(window.title == 'New engine title', 'new softmod write captures the latest observed title');

    check(api.NativeTitleRename('Old window title'), 'old window title accepted');
    Application.current = new Application();
    window = Application.current.window;
    window.title = 'Recreated window';
    check(api.NativeTitleRename(null), 'reset after window replacement is harmless');
    check(window.title == 'Recreated window', 'reset does not alter a replacement window');
    check(api.NativeTitleRename('Same title'), 'title on first window accepted');
    Application.current = new Application();
    window = Application.current.window;
    window.title = 'Same title';
    check(api.NativeTitleRename(null) && window.title == 'Same title',
      'replacement window is not reset even when its title happens to match');
    window.title = 'Recreated window';
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
    check(api.NativeTitleRename('Before rejected request'), 'title before rejected request accepted');
    JNI.accept = false;
    check(!api.NativeWarn('Declined'), 'JNI toast refusal returned');
    check(!api.NativeMSGBox('Declined'), 'JNI dialog refusal returned');
    check(!api.NativeTitleRename('Declined'), 'failed rename returned');
    JNI.accept = true;
    check(api.NativeTitleRename(null) && window.title == 'Recreated window',
      'failed rename leaves the previous restore point intact');
    #else
    check(!api.NativeWarn('Unsupported in interpreter'), 'unsupported warning never becomes a dialog');
    #end

    check(api.NativeTitleRename('Before window closes'), 'last window title accepted');
    Application.current = null;
    check(!api.NativeTitleRename(null), 'cannot safely restore while the current title is unavailable');
    #if !android
    check(!api.NativeMSGBox('No window'), 'missing window does not crash');
    check(!api.NativeTitleRename('No window'), 'missing window cannot be renamed');
    #else
    // Android targets the Activity, which can outlive the Lime window object.
    check(api.NativeMSGBox('No Lime window'), 'Android dialog uses the Activity bridge');
    check(api.NativeTitleRename('No Lime window'), 'Android can rename without a Lime window');
    check(!api.NativeTitleRename(null), 'unobservable Android title cannot be restored safely');
    #end
    Sys.println('StdFire facade passed');
  }
}
