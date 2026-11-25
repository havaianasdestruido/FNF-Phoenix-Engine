package backend;

import psychlua.StdFireLibrary;

/**
 * How one stdfire self-test row ended.
 */
enum abstract StdFireCheckStatus(String)
{
  /** The page has not run this check during this visit. */
  var Pending = 'PENDING';

  /** The behaviour matched the documented `stdfire` contract. */
  var Passed = 'PASS';

  /** The behaviour contradicted the documented `stdfire` contract. */
  var Failed = 'FAIL';

  /** The running target cannot exercise this behaviour at all. */
  var Skipped = 'SKIP';
}

/**
 * What one check reports back: its final status and the sentence the page
 * shows under the row.
 */
typedef StdFireCheckOutcome = {
  /** Final state of the check. */
  var status:StdFireCheckStatus;

  /** One sentence describing what was actually observed. */
  var detail:String;
}

/**
 * One `stdfire` behaviour, its last result, and the closure that verifies it.
 */
typedef StdFireCheck = {
  /** Stable identifier used by the debug page and the Haxe spec. */
  var id:String;

  /** Short row label. */
  var label:String;

  /** What the check does, shown while the row is selected. */
  var description:String;

  /** True when running it displays a real dialog/warning instead of only validating input. */
  var interactive:Bool;

  /** Last reported status. */
  var status:StdFireCheckStatus;

  /** Last reported detail; never null after construction. */
  var detail:String;

  /** The verification itself. Not displayed. */
  var run:Void->StdFireCheckOutcome;
}

/**
 * Runs every function of the `stdfire` softmod API against the running target.
 *
 * This is the logic behind `states.StdFireTestState`, the page the Super Secret
 * Debug Menu opens. It lives here, away from Flixel, so the Haxe specs can run
 * exactly the same checks without a game build.
 *
 * The checks mirror `website/docs/modding/stdfire.md`:
 *
 * - the interpreter namespace contains the three callables and points at
 *   `backend.StdFire`;
 * - `NativeTitleRename` applies Unicode titles exactly, restores the observed
 *   previous title, rejects NUL characters, and leaves a later engine write
 *   alone when reset;
 * - `NativeMSGBox` and `NativeWarn` reject null/blank/NUL input without showing
 *   anything, and accept a real Unicode message on targets that have a backend.
 *
 * Side effects are deliberate but bounded: the title checks write the game
 * window/tab title and always restore what they found, so a screenshot taken
 * afterwards shows the normal title again. The two interactive checks display a
 * real message box (which blocks until dismissed) and a real warning, and only
 * run when the page asks for them or the player presses "run everything".
 */
class StdFireSelfTest
{
  /** Marker title used by the set/read-back check. */
  public static inline final TITLE_SAMPLE:String = 'Phoenix stdfire 🔥';

  /**
   * ASCII-only title that imitates a normal engine write. Android's SDL bridge
   * cannot round-trip supplementary characters, and the real engine titles are
   * ASCII, so this marker keeps that check representative instead of corrupting
   * the Activity label.
   */
  public static inline final ENGINE_TITLE_SAMPLE:String = 'Engine update (stdfire test)';

  /** Message shown by the interactive message-box check. */
  public static inline final DIALOG_MESSAGE:String = 'stdfire self-test: the native message box works. 🔥';

  /** Caption passed to the interactive message-box check. */
  public static inline final DIALOG_TITLE:String = 'Phoenix stdfire self-test';

  /** Message shown by the interactive warning check. */
  public static inline final WARNING_MESSAGE:String = 'stdfire self-test: the native warning works. 🔥';

  /** Every check, in display order. Built once in the constructor. */
  public var checks(default, null):Array<StdFireCheck> = [];

  /** True while a pass is in flight; a second pass cannot start from re-entrant input. */
  var running:Bool = false;

  public function new()
  {
    add('namespace-functions', 'Namespace: three callables',
      'StdFireLibrary.createNamespace() must install NativeTitleRename, NativeMSGBox and NativeWarn as callables,'
      + ' and every interpreter must get its own namespace object.',
      false, namespaceFunctions);

    add('namespace-wiring', 'Namespace: wired to the platform',
      'A title set and reset through StdFireLibrary.createNamespace() must reach the real window or tab, which'
      + ' proves the installed callable is the live backend.StdFire implementation and not a stale copy.',
      false, namespaceWiring);

    add('title-reset-noop', 'Title: reset without a softmod title',
      'NativeTitleRename(null) with no previous stdfire title is documented as a successful no-op.'
      + ' This also clears any stale restore point before the other checks run.',
      false, titleResetNoop);

    add('title-round-trip', 'Title: Unicode set, read back, restore',
      'NativeTitleRename("' + TITLE_SAMPLE + '") must be accepted, the window/tab must show exactly that text,'
      + ' and NativeTitleRename(null) must restore the title observed before the check.',
      false, titleRoundTrip);

    add('title-reject-nul', 'Title: embedded NUL rejected',
      'Native title APIs take NUL-terminated strings, so a title containing \\x00 must be rejected (return false)'
      + ' instead of being silently truncated, and the current title must not change.',
      false, titleRejectNul);

    add('title-engine-precedence', 'Title: a later engine write survives reset',
      'After a softmod title, a direct engine title write must win: NativeTitleRename(null) then leaves the'
      + ' newer engine title alone instead of restoring the softmod text.',
      false, titleEnginePrecedence);

    add('msgbox-reject-null', 'Message box: null message rejected',
      'NativeMSGBox(null) must return false without showing a dialog.',
      false, msgBoxRejectsNull);

    add('msgbox-reject-nul', 'Message box: embedded NUL rejected',
      'A message containing \\x00 must be rejected (return false) instead of being converted into a'
      + ' truncated or corrupted native string.',
      false, msgBoxRejectsNul);

    add('msgbox-reject-nul-title', 'Message box: embedded NUL caption rejected',
      'A valid message with a caption containing \\x00 must be rejected as a whole, so an invalid caption'
      + ' never opens a dialog.',
      false, msgBoxRejectsNulTitle);

    add('msgbox-show', 'Message box: show a real Unicode dialog',
      'NativeMSGBox("' + DIALOG_MESSAGE + '", "' + DIALOG_TITLE + '") opens the platform dialog.'
      + ' A true result means the request was accepted, not that the OS drew it, so read the dialog on screen too.',
      true, msgBoxShow);

    add('warn-reject-null', 'Warning: null message rejected',
      'NativeWarn(null) must return false and never fall back to a message box.',
      false, warnRejectsNull);

    add('warn-reject-blank', 'Warning: blank message rejected',
      'A whitespace-only warning carries no information, so it must return false instead of showing an'
      + ' empty toast/banner.',
      false, warnRejectsBlank);

    add('warn-reject-nul', 'Warning: embedded NUL rejected',
      'A warning containing \\x00 must be rejected (return false) instead of being converted into a truncated'
      + ' or corrupted native string.',
      false, warnRejectsNul);

    add('warn-reject-nul-title', 'Warning: embedded NUL caption rejected',
      'A valid warning with a caption containing \\x00 must be rejected as a whole.',
      false, warnRejectsNulTitle);

    add('warn-show', 'Warning: show a real Unicode warning',
      'NativeWarn("' + WARNING_MESSAGE + '") shows the short, non-modal platform warning.'
      + ' A true result means accepted or queued; desktop helpers may still be suppressed by the OS.',
      true, warnShow);
  }

  /**
   * Runs every check that does not display a dialog or a warning.
   *
   * @return how many of the executed checks failed
   */
  public function runAutomatic():Int
  {
    return runChecks(false);
  }

  /**
   * Runs every check, including the interactive message box and warning. When a
   * platform dialog is modal this blocks until the player dismisses it.
   *
   * @return how many executed checks failed
   */
  public function runAll():Int
  {
    return runChecks(true);
  }

  /**
   * Runs a single check by id.
   *
   * @param id identifier from `checks`
   * @return the status it ended in, or `Pending` when the id is unknown
   */
  public function runCheck(id:String):StdFireCheckStatus
  {
    final check:StdFireCheck = find(id);
    return check == null ? Pending : execute(check);
  }

  /**
   * @param status status to count
   * @return how many checks currently report that status
   */
  public function count(status:StdFireCheckStatus):Int
  {
    var total:Int = 0;
    for (check in checks)
      if (check.status == status) total++;
    return total;
  }

  /** @return how many executed checks failed. */
  public function failures():Int
  {
    return count(Failed);
  }

  /** @return one line of counts for the page header, e.g. "5 PASS 0 FAIL 9 TO RUN 1 SKIP". */
  public function summary():String
  {
    return count(Passed) + ' PASS   ' + count(Failed) + ' FAIL   ' + count(Pending) + ' TO RUN   '
      + count(Skipped) + ' SKIP';
  }

  /** @return the check with this id, or null. */
  public function find(id:String):StdFireCheck
  {
    for (check in checks)
      if (check.id == id) return check;
    return null;
  }

  /**
   * Reads the running window/tab title the same way stdfire does.
   *
   * @return the observable title, or null on targets without one (Flash/AIR)
   */
  public static function currentTitle():Null<String>
  {
    #if html5
    return js.Browser.document == null ? null : js.Browser.document.title;
    #elseif flash
    return null;
    #else
    final app = lime.app.Application.current;
    return app == null || app.window == null ? null : app.window.title;
    #end
  }

  /**
   * Writes a title directly, the way the engine (not stdfire) does.
   *
   * @param title text to set; null is ignored
   * @return true when the write was possible on this target
   */
  public static function writeTitle(title:Null<String>):Bool
  {
    if (title == null) return false;
    #if html5
    final app = lime.app.Application.current;
    if (app != null && app.window != null)
    {
      app.window.title = title;
      return currentTitle() == title;
    }
    if (js.Browser.document == null) return false;
    js.Browser.document.title = title;
    return true;
    #elseif flash
    return false;
    #else
    final app = lime.app.Application.current;
    if (app == null || app.window == null) return false;
    app.window.title = title;
    return true;
    #end
  }

  /**
   * Best-effort restore used by failure paths and by the page on the way out.
   * Android's native title bridge is stdfire's job, so this restores an
   * already-observed engine title exactly as the engine itself would.
   *
   * @param title title to put back; null is ignored
   */
  public static function restoreTitle(title:Null<String>):Void
  {
    if (title == null) return;
    try
    {
      writeTitle(title);
    }
    catch (e:Dynamic) {} // A closing window must not turn cleanup into a crash.
  }

  /** @return true when this build has a native dialog backend (everything but Flash/AIR). */
  static function messageBoxSupported():Bool
  {
    #if flash
    return false;
    #else
    return true;
    #end
  }

  /** @return true when this build reaches one of `StdFire.nativeWarn`'s backends. */
  static function warningSupported():Bool
  {
    #if (html5 || android || (cpp && (windows || ios || (linux && !android) || (mac && !ios))))
    return true;
    #else
    return false;
    #end
  }

  static function success(detail:String):StdFireCheckOutcome
  {
    return {status: Passed, detail: detail};
  }

  static function failure(detail:String):StdFireCheckOutcome
  {
    return {status: Failed, detail: detail};
  }

  static function skip(detail:String):StdFireCheckOutcome
  {
    return {status: Skipped, detail: detail};
  }

  /** Renders null (and empty) titles without printing "null". */
  static function describe(title:Null<String>):String
  {
    return title == null ? 'no title' : '"' + title + '"';
  }

  /** Appends one row and stores its closure. */
  function add(id:String, label:String, description:String, interactive:Bool, run:Void->StdFireCheckOutcome):Void
  {
    checks.push({
      id: id,
      label: label,
      description: description,
      interactive: interactive,
      status: Pending,
      detail: interactive ? 'Not run yet. Run this row to show it on this device.' : 'Not run yet.',
      run: run
    });
  }

  /** Executes checks, optionally skipping the two that display something. */
  function runChecks(includeInteractive:Bool):Int
  {
    if (running) return failures();
    running = true;
    // Haxe has no finally clause: the flag is cleared on both exits by hand.
    try
    {
      for (check in checks)
      {
        if (!includeInteractive && check.interactive) continue;
        execute(check);
      }
    }
    catch (e:Dynamic)
    {
      running = false;
      throw e;
    }
    running = false;
    return failures();
  }

  /** Runs one check and records its outcome; a throwing platform call becomes a failure. */
  function execute(check:StdFireCheck):StdFireCheckStatus
  {
    if (check == null || check.run == null) return Pending;
    var outcome:StdFireCheckOutcome = null;
    try
    {
      outcome = check.run();
    }
    catch (e:Dynamic)
    {
      outcome = failure('The call threw: ' + Std.string(e));
    }
    if (outcome == null) outcome = failure('The check returned no result.');
    check.status = outcome.status;
    check.detail = outcome.detail == null || outcome.detail.length == 0 ? 'No detail reported.' : outcome.detail;
    return check.status;
  }

  // ---------------------------------------------------------------------------
  // Namespace
  // ---------------------------------------------------------------------------

  function namespaceFunctions():StdFireCheckOutcome
  {
    final first:Dynamic = StdFireLibrary.createNamespace();
    final second:Dynamic = StdFireLibrary.createNamespace();
    for (name in ['NativeTitleRename', 'NativeMSGBox', 'NativeWarn'])
    {
      if (!Reflect.isFunction(Reflect.field(first, name))) return failure('$name is not callable in the namespace.');
      if (!Reflect.isFunction(Reflect.field(second, name))) return failure('$name is missing from a second namespace.');
    }
    if (first == second) return failure('Two interpreters received the same namespace object.');
    return success('All three callables are present, and each interpreter gets a fresh namespace.');
  }

  function namespaceWiring():StdFireCheckOutcome
  {
    final before:Null<String> = currentTitle();
    if (before == null) return skip('This target exposes no window or tab title to verify the namespace end to end.');

    final rename:Dynamic = Reflect.field(StdFireLibrary.createNamespace(), 'NativeTitleRename');
    if (!Reflect.isFunction(rename)) return failure('NativeTitleRename is not callable in the namespace.');

    // Identity checks on function values are target-dependent; the observable
    // behaviour of the call is what proves the namespace reaches the facade.
    final accepted:Bool = Reflect.callMethod(null, rename, [TITLE_SAMPLE]);
    final applied:Null<String> = currentTitle();
    final resetAccepted:Bool = Reflect.callMethod(null, rename, [null]);
    final restored:Null<String> = currentTitle();

    if (!accepted || applied != TITLE_SAMPLE)
    {
      restoreTitle(before);
      return failure('A title set through the namespace did not reach the window.');
    }
    if (!resetAccepted || restored != before)
    {
      restoreTitle(before);
      return failure('A reset through the namespace did not restore ' + describe(before) + '.');
    }
    return success('A title set and reset through the namespace reached the real window.');
  }

  // ---------------------------------------------------------------------------
  // NativeTitleRename
  // ---------------------------------------------------------------------------

  function titleResetNoop():StdFireCheckOutcome
  {
    if (!StdFire.nativeTitleRename(null))
      return failure('Resetting the title with no active stdfire title was rejected.');
    return success('A reset with no previous softmod title was accepted as a no-op.');
  }

  function titleRoundTrip():StdFireCheckOutcome
  {
    final before:Null<String> = currentTitle();
    if (before == null) return skip('This target exposes no window or tab title to read back.');

    final accepted:Bool = StdFire.nativeTitleRename(TITLE_SAMPLE);
    final applied:Null<String> = currentTitle();
    final resetAccepted:Bool = StdFire.nativeTitleRename(null);
    final restored:Null<String> = currentTitle();

    if (!accepted)
    {
      restoreTitle(before);
      return failure('NativeTitleRename rejected ' + describe(TITLE_SAMPLE) + '.');
    }
    if (applied != TITLE_SAMPLE)
    {
      restoreTitle(before);
      return failure('The title was accepted, but the target shows ' + describe(applied) + ' instead.');
    }
    if (!resetAccepted)
    {
      restoreTitle(before);
      return failure('The title was applied, but resetting it was rejected.');
    }
    if (restored != before)
    {
      restoreTitle(before);
      return failure('Reset shows ' + describe(restored) + ' instead of the previous ' + describe(before) + '.');
    }
    return success('Set ' + describe(TITLE_SAMPLE) + ', read it back, and restored ' + describe(before) + '.');
  }

  function titleRejectNul():StdFireCheckOutcome
  {
    final before:Null<String> = currentTitle();
    final accepted:Bool = StdFire.nativeTitleRename('Bad\x00title');
    final after:Null<String> = currentTitle();

    if (accepted)
    {
      restoreTitle(before);
      return failure('A title with an embedded NUL was accepted.');
    }
    if (before != null && after != before)
    {
      restoreTitle(before);
      return failure('The invalid title was rejected, but the window changed to ' + describe(after) + '.');
    }
    return success('Rejected without touching ' + describe(before) + '.');
  }

  function titleEnginePrecedence():StdFireCheckOutcome
  {
    #if android
    // Android's Activity title is not readable back through Lime, so a direct
    // engine write cannot be observed here; stdfire caches its own writes only.
    return skip('Android does not expose the Activity title back to Lime, so a later write cannot be observed.');
    #else
    final before:Null<String> = currentTitle();
    if (before == null) return skip('This target exposes no window or tab title to read back.');
    if (!StdFire.nativeTitleRename(TITLE_SAMPLE))
    {
      restoreTitle(before);
      return failure('The softmod title was rejected, so engine precedence could not be tested.');
    }
    if (!writeTitle(ENGINE_TITLE_SAMPLE))
    {
      StdFire.nativeTitleRename(null);
      restoreTitle(before);
      return skip('This target cannot imitate a direct engine title write.');
    }
    final resetAccepted:Bool = StdFire.nativeTitleRename(null);
    final after:Null<String> = currentTitle();
    restoreTitle(before);

    if (!resetAccepted) return failure('Resetting after an engine title write was rejected.');
    if (after != ENGINE_TITLE_SAMPLE)
      return failure('Reset replaced the later engine title with ' + describe(after) + '.');
    return success('A later engine write (' + describe(ENGINE_TITLE_SAMPLE) + ') survived the reset.');
    #end
  }

  // ---------------------------------------------------------------------------
  // NativeMSGBox
  // ---------------------------------------------------------------------------

  function msgBoxRejectsNull():StdFireCheckOutcome
  {
    if (!messageBoxSupported()) return skip('This target has no native message box backend; the call returns false by design.');
    if (StdFire.nativeMSGBox(null)) return failure('A null message was accepted.');
    return success('A null message was rejected without showing a dialog.');
  }

  function msgBoxRejectsNul():StdFireCheckOutcome
  {
    if (!messageBoxSupported()) return skip('This target has no native message box backend; the call returns false by design.');
    if (StdFire.nativeMSGBox('Bad\x00message')) return failure('A message with an embedded NUL was accepted.');
    return success('Rejected the message without showing a dialog.');
  }

  function msgBoxRejectsNulTitle():StdFireCheckOutcome
  {
    if (!messageBoxSupported()) return skip('This target has no native message box backend; the call returns false by design.');
    if (StdFire.nativeMSGBox('Valid message', 'Bad\x00title')) return failure('A dialog caption with an embedded NUL was accepted.');
    return success('Rejected the caption before opening a dialog.');
  }

  function msgBoxShow():StdFireCheckOutcome
  {
    if (!messageBoxSupported()) return skip('This target has no native message box backend; the call returns false by design.');
    if (!StdFire.nativeMSGBox(DIALOG_MESSAGE, DIALOG_TITLE))
      return failure('The message box call returned false: no usable window, or the request was rejected.');
    return success('Accepted. "true" means accepted; the OS still owns whether it was drawn, so check the dialog on screen.');
  }

  // ---------------------------------------------------------------------------
  // NativeWarn
  // ---------------------------------------------------------------------------

  function warnRejectsNull():StdFireCheckOutcome
  {
    if (!warningSupported()) return skip('This target has no warning backend; the call returns false by design.');
    if (StdFire.nativeWarn(null)) return failure('A null warning was accepted.');
    return success('A null warning was rejected without showing anything.');
  }

  function warnRejectsBlank():StdFireCheckOutcome
  {
    if (!warningSupported()) return skip('This target has no warning backend; the call returns false by design.');
    if (StdFire.nativeWarn('   ')) return failure('A whitespace-only warning was accepted.');
    return success('A blank warning was rejected without showing anything.');
  }

  function warnRejectsNul():StdFireCheckOutcome
  {
    if (!warningSupported()) return skip('This target has no warning backend; the call returns false by design.');
    if (StdFire.nativeWarn('Bad\x00warning')) return failure('A warning with an embedded NUL was accepted.');
    return success('Rejected the warning without showing anything.');
  }

  function warnRejectsNulTitle():StdFireCheckOutcome
  {
    if (!warningSupported()) return skip('This target has no warning backend; the call returns false by design.');
    if (StdFire.nativeWarn('Valid warning', 'Bad\x00title')) return failure('A warning caption with an embedded NUL was accepted.');
    return success('Rejected the caption before showing anything.');
  }

  function warnShow():StdFireCheckOutcome
  {
    if (!warningSupported())
      return skip('This target has no warning backend (non-C++ desktop, Flash or an unsupported platform);'
        + ' the call returns false by design.');
    if (!StdFire.nativeWarn(WARNING_MESSAGE, 'Phoenix stdfire self-test'))
      return failure('The warning call returned false: no usable window, backend or accepted request.');
    return success('Accepted or queued. Warnings are non-modal, and the OS or desktop settings may still suppress them.');
  }
}
