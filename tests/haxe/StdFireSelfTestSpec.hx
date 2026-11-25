import backend.StdFire;
import backend.StdFireSelfTest;
import backend.StdFireSelfTest.StdFireCheckStatus;
import lime.app.Application;

/**
 * Runs the exact checks behind the Super Secret Debug Menu's stdfire page
 * against the platform doubles in `tests/haxe/stubs/stdfire`.
 *
 * No Flixel or game build is needed: `backend.StdFireSelfTest` is the page's
 * logic, so this spec proves that every documented `stdfire` behaviour is
 * covered, that the pass restores the window title, and that the interactive
 * rows are the only ones that wait for a press.
 */
class StdFireSelfTestSpec
{
  static function check(condition:Bool, message:String):Void
  {
    if (!condition) throw message;
  }

  static function statusOf(test:StdFireSelfTest, id:String):StdFireCheckStatus
  {
    final found = test.find(id);
    if (found == null) throw 'missing self-test row: ' + id;
    return found.status;
  }

  /** Every row the debug page promises, including both real-display checks. */
  static final EXPECTED_ROWS:Array<String> = [
    'namespace-functions',
    'namespace-wiring',
    'title-reset-noop',
    'title-round-trip',
    'title-reject-nul',
    'title-engine-precedence',
    'msgbox-reject-null',
    'msgbox-reject-nul',
    'msgbox-reject-nul-title',
    'msgbox-show',
    'warn-reject-null',
    'warn-reject-blank',
    'warn-reject-nul',
    'warn-reject-nul-title',
    'warn-show'
  ];

  static function main():Void
  {
    Application.current = new Application();
    Application.current.window.title = 'Engine title';

    final test:StdFireSelfTest = new StdFireSelfTest();
    for (id in EXPECTED_ROWS)
      check(test.find(id) != null, 'self-test must cover ' + id);
    check(test.checks.length == EXPECTED_ROWS.length, 'no undocumented rows');
    check(test.count(StdFireCheckStatus.Passed) == 0 && test.count(StdFireCheckStatus.Failed) == 0, 'nothing runs before the page asks');

    // The automatic pass is what create() runs: it must not show a dialog or a
    // toast, and it must leave the window exactly as it found it.
    check(test.runAutomatic() == 0, 'the automatic pass reports no failures');
    check(Application.current.window.title == 'Engine title', 'automatic pass restores the window title');
    check(test.count(StdFireCheckStatus.Pending) == 2, 'only the two display rows wait for a press');
    check(statusOf(test, 'title-round-trip') == StdFireCheckStatus.Passed, 'title set/read/restore is verified');
    check(statusOf(test, 'title-reject-nul') == StdFireCheckStatus.Passed, 'NUL titles are verified as rejected');
    check(statusOf(test, 'title-engine-precedence') == StdFireCheckStatus.Passed, 'engine title precedence is verified');
    check(statusOf(test, 'msgbox-reject-null') == StdFireCheckStatus.Passed, 'a null dialog message is rejected');
    check(statusOf(test, 'msgbox-reject-nul') == StdFireCheckStatus.Passed, 'a NUL dialog message is rejected');
    check(statusOf(test, 'msgbox-reject-nul-title') == StdFireCheckStatus.Passed, 'a NUL dialog caption is rejected');

    // An id that no longer exists must not throw from the page's input handler.
    check(test.runCheck('no-such-row') == StdFireCheckStatus.Pending, 'an unknown id is a harmless pending row');

    // stdfire itself must be back to "no active softmod title" after the pass,
    // otherwise a real mod's later reset would behave differently.
    check(StdFire.nativeTitleRename(null), 'the pass leaves no stale title restore point');
    check(Application.current.window.title == 'Engine title', 'the no-op reset changes nothing');

    // The dialog row really goes through the facade: the stub records what a
    // platform dialog would have shown.
    test.runCheck('msgbox-show');
    check(statusOf(test, 'msgbox-show') == StdFireCheckStatus.Passed, 'the message box row reports acceptance');
    #if android
    // Android reports through the JNI bridge; the stub accepts by default.
    #else
    check(Application.current.window.alertMessage == StdFireSelfTest.DIALOG_MESSAGE,
      'the dialog receives the exact Unicode message');
    check(Application.current.window.alertTitle == StdFireSelfTest.DIALOG_TITLE,
      'the dialog receives the caption');
    #end
    check(Application.current.window.title == 'Engine title', 'showing a dialog leaves the title alone');

    // Targets without a warning backend must report SKIP, never FAIL: the
    // documented contract there is a false return, not a bug in the page.
    test.runCheck('warn-show');
    #if (html5 || android || (cpp && (windows || ios || (linux && !android) || (mac && !ios))))
    check(statusOf(test, 'warn-show') == StdFireCheckStatus.Passed, 'the warning row reports acceptance where a backend exists');
    #else
    check(statusOf(test, 'warn-show') == StdFireCheckStatus.Skipped, 'the warning row is skipped where no backend exists');
    #end

    // "Run everything" must finish with no failure and cover every row.
    check(test.runAll() == 0, 'a full pass reports no failures');
    check(test.count(StdFireCheckStatus.Passed) + test.count(StdFireCheckStatus.Skipped) == test.checks.length, 'every row ends PASS or SKIP');
    check(Application.current.window.title == 'Engine title', 'a full pass leaves the title alone');
    check(StdFire.nativeTitleRename(null) && Application.current.window.title == 'Engine title',
      'a full pass leaves no stale restore point');

    // A second automatic pass must be stable (no stale restore points).
    check(test.runAutomatic() == 0, 'the automatic pass repeats cleanly');
    check(Application.current.window.title == 'Engine title', 'the repeated pass restores the title');

    // The same file is typechecked for html5, where Sys does not exist.
    #if sys
    Sys.println('StdFire self-test passed');
    #else
    trace('StdFire self-test passed');
    #end
  }
}
