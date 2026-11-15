import backend.StdFire;
import lime.app.Application;
import psychlua.StdFireLibrary;
import js.Syntax;

class StdFireBrowserSpec
{
  static function check(condition:Bool, message:String):Void
  {
    if (!condition) throw message;
  }

  static function main():Void
  {
    // Minimal DOM with deterministic timers: no browser or external JS library required.
    Syntax.code("(function() {
      var timers = {}, next = 0;
      var body = { children: [], appendChild: function(e) { e.parentNode = this; this.children.push(e); },
        removeChild: function(e) { this.children = this.children.filter(function(x) { return x !== e; }); e.parentNode = null; } };
      var doc = { title: 'Original tab', body: body, createElement: function() {
        return { style: {}, parentNode: null, attributes: {}, setAttribute: function(k,v) { this.attributes[k] = v; } }; } };
      globalThis.window = { document: doc, lastAlert: null, cleared: 0, alert: function(m) { this.lastAlert = m; },
        setTimeout: function(fn, ms) { if (ms !== 3500) throw 'duration'; timers[++next] = fn; return next; },
        clearTimeout: function(id) { delete timers[id]; this.cleared++; },
        fire: function(id) { var fn = timers[id]; delete timers[id]; if (fn) fn(); }, lastTimer: function() { return next; } };
      globalThis.document = doc;
    })()");

    Application.current = new Application();
    StdFire.engineTitleChanged('Engine');
    var api:Dynamic = StdFireLibrary.createNamespace();
    check(api.NativeTitleRename('Nova aba 🔥'), 'browser title accepted');
    check(js.Browser.document.title == 'Nova aba 🔥', 'document title changed');
    check(Application.current.window.title == 'Nova aba 🔥', 'Lime title cache stays in sync');
    StdFire.engineTitleChanged('Next song');
    check(js.Browser.document.title == 'Nova aba 🔥', 'engine title update respects override');
    check(api.NativeTitleRename(null), 'reset title');
    check(js.Browser.document.title == 'Next song', 'latest engine title restored');
    Application.current = null;
    check(api.NativeTitleRename('No Lime window'), 'document-only title fallback');
    check(js.Browser.document.title == 'No Lime window', 'fallback changes tab title');
    check(api.NativeTitleRename(null), 'reset through document-only fallback');

    check(api.NativeMSGBox('Browser alert', 'Browser ignores title'), 'alert accepted');
    check(Syntax.code('window.lastAlert') == 'Browser alert', 'window.alert receives only message');
    check(!api.NativeMSGBox(null), 'null alert rejected');

    var injected = '<img src=x onerror=alert(1)> ⚠';
    check(api.NativeWarn(injected, 'Ignored'), 'warning accepted');
    check(Syntax.code('document.body.children.length') == 1, 'one toast appended');
    check(Syntax.code('document.body.children[0].textContent') == injected, 'text is not interpreted as HTML');
    check(Syntax.code('document.body.children[0].attributes.role') == 'status', 'accessible live status');
    check(api.NativeWarn('Replacement'), 'replacement accepted');
    check(Syntax.code('document.body.children.length') == 1, 'no stacked toast elements');
    check(Syntax.code('window.cleared') == 1, 'previous timeout cancelled');
    check(Syntax.code('document.body.children[0].textContent') == 'Replacement', 'toast text updated');
    Syntax.code('window.fire(window.lastTimer())');
    check(Syntax.code('document.body.children.length') == 0, 'toast disappears');
    check(!api.NativeWarn('  '), 'blank warning rejected');
    Syntax.code('document.body = null');
    check(!api.NativeWarn('Missing body'), 'missing body handled without a modal');
    Syntax.code('console.log("StdFire browser passed")');
  }
}
