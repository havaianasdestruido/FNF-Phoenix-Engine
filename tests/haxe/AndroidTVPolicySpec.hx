import backend.AndroidTVPolicy;

/**
 * Contract tests for `backend.AndroidTVPolicy` (Android TV / remote navigation).
 * Runs directly in the Haxe interpreter with zero OpenFL/Flixel dependencies.
 */
class AndroidTVPolicySpec
{
  static function check(ok:Bool, label:String):Void
  {
    if (!ok) throw label;
  }

  static function equal<T>(actual:T, expected:T, label:String):Void
  {
    if (actual != expected) throw '$label: expected $expected, got $actual';
  }

  /** Floats measured in frames never land exactly on the boundary value. */
  static function approx(actual:Float, expected:Float, label:String, tolerance:Float = 0.000001):Void
  {
    if (Math.abs(actual - expected) > tolerance) throw '$label: expected $expected, got $actual';
  }

  static function main():Void
  {
    // First-boot auto-detection across TV / touchless combinations.
    equal(AndroidTVPolicy.shouldAutoEnable(true, true), true, 'TV with touch reports TV');
    equal(AndroidTVPolicy.shouldAutoEnable(true, false), true, 'TV without touch reports TV');
    equal(AndroidTVPolicy.shouldAutoEnable(false, false), true, 'touchless box enables TV mode');
    equal(AndroidTVPolicy.shouldAutoEnable(false, true), false, 'touch phone stays touch mode');

    // Touch controls and mouse cursor stay suppressed when TV navigation is active.
    equal(AndroidTVPolicy.shouldUseTouchlessUI(false), false, 'touchless disabled');
    equal(AndroidTVPolicy.shouldUseTouchlessUI(true), true, 'touchless enabled');
    equal(AndroidTVPolicy.shouldShowTouchControls(true, 1.0), false, 'touch controls hidden in TV mode even at full opacity');
    equal(AndroidTVPolicy.shouldShowTouchControls(false, 0.0), false, 'touch controls hidden at 0 opacity');
    equal(AndroidTVPolicy.shouldShowTouchControls(false, 0.09), false, 'touch controls hidden below 0.1 opacity');
    equal(AndroidTVPolicy.shouldShowTouchControls(false, 0.1), true, 'touch controls shown when TV off and opacity >= 0.1');
    equal(AndroidTVPolicy.shouldShowTouchControls(false, 0.6), true, 'touch controls shown at default opacity');
    equal(AndroidTVPolicy.shouldShowMouseCursor(true), false, 'mouse cursor hidden in TV mode');
    equal(AndroidTVPolicy.shouldShowMouseCursor(false), true, 'mouse cursor visible outside TV mode');

    // Root TitleState Back only backgrounds when at root with no substate or transition.
    equal(AndroidTVPolicy.shouldBackgroundOnTitleBack(true, false, false, true), true, 'root TitleState Back backgrounds Android task');
    equal(AndroidTVPolicy.shouldBackgroundOnTitleBack(true, true, false, true), false, 'Prompt open suppresses task backgrounding');
    equal(AndroidTVPolicy.shouldBackgroundOnTitleBack(true, false, true, true), false, 'transitioning suppresses task backgrounding');
    equal(AndroidTVPolicy.shouldBackgroundOnTitleBack(true, false, false, false), false, 'no Back press does nothing');
    equal(AndroidTVPolicy.shouldBackgroundOnTitleBack(false, false, false, true), false, 'non-Android never calls Android task background');

    // "First five seconds" controller probe: TV navigation stays on only when a
    // remote/D-pad/gamepad answers inside the window. Frames are fed in exact
    // 1/16s steps so the five-second boundary lands on a representable number.
    equal(AndroidTVPolicy.CONTROLLER_PROBE_SECONDS, 5.0, 'probe window is five seconds');

    var probe = AndroidTVPolicy.newControllerProbe();
    equal(probe.elapsed, 0.0, 'fresh probe starts at zero');
    equal(probe.sawInput, false, 'fresh probe saw no input');
    equal(probe.settled, false, 'fresh probe is listening');

    var step = AndroidTVPolicy.stepControllerProbe(probe, 0.0625, false);
    equal(step.listening, true, 'probe listens while the window is open');
    equal(step.disable, false, 'probe does not disable on its first frame');

    // 79 frames of input silence = 4.9375s: still inside the window.
    for (_ in 1...79) AndroidTVPolicy.stepControllerProbe(probe, 0.0625, false);
    approx(probe.elapsed, 4.9375, 'probe accumulates frame time');
    approx(AndroidTVPolicy.controllerProbeRemaining(probe), 0.0625, 'remaining time shrinks with the window');
    equal(probe.settled, false, 'probe is still listening just before five seconds');

    // The 80th silent frame reaches exactly five seconds and turns the option off.
    step = AndroidTVPolicy.stepControllerProbe(probe, 0.0625, false);
    equal(step.listening, false, 'probe stopped listening at 5.0s');
    equal(step.disable, true, 'probe disables TV navigation at 5.0s');
    equal(probe.settled, true, 'expired probe is settled');
    approx(AndroidTVPolicy.controllerProbeRemaining(probe), 0.0, 'expired probe has no time left');
    step = AndroidTVPolicy.stepControllerProbe(probe, 1.0, false);
    equal(step.disable, false, 'an expired probe never disables twice');

    // A remote press inside the window confirms the mode for good.
    probe = AndroidTVPolicy.newControllerProbe();
    step = AndroidTVPolicy.stepControllerProbe(probe, 0.0625, true);
    equal(step.listening, false, 'confirmed probe stops listening');
    equal(step.disable, false, 'confirmed probe keeps TV navigation on');
    equal(probe.sawInput, true, 'confirmed probe remembers the input');
    equal(probe.settled, true, 'confirmed probe is settled');
    step = AndroidTVPolicy.stepControllerProbe(probe, 10.0, false);
    equal(step.disable, false, 'a confirmed probe never disables later on');

    // A press on the closing frame still counts.
    probe = AndroidTVPolicy.newControllerProbe();
    for (_ in 0...79) AndroidTVPolicy.stepControllerProbe(probe, 0.0625, false);
    step = AndroidTVPolicy.stepControllerProbe(probe, 0.0625, true);
    equal(step.disable, false, 'input on the closing frame keeps TV navigation on');

    // A stalled frame (loading, background wake-up) only advances the window by
    // one clamped frame, so a freeze cannot disable TV navigation on its own.
    probe = AndroidTVPolicy.newControllerProbe();
    step = AndroidTVPolicy.stepControllerProbe(probe, 30.0, false);
    equal(step.listening, true, 'a stalled frame keeps the window open');
    approx(probe.elapsed, AndroidTVPolicy.CONTROLLER_PROBE_MAX_FRAME_SECONDS, 'stalled frames are clamped');

    // Negative deltas never rewind the window.
    probe = AndroidTVPolicy.newControllerProbe();
    step = AndroidTVPolicy.stepControllerProbe(probe, -1.0, false);
    equal(step.listening, true, 'negative deltas keep listening');
    equal(probe.elapsed, 0.0, 'negative deltas are ignored');

    // Turning the option off and on again gets a whole new window.
    probe = AndroidTVPolicy.newControllerProbe();
    for (_ in 0...80) AndroidTVPolicy.stepControllerProbe(probe, 0.0625, false);
    equal(probe.settled, true, 'silent window settles the probe');
    AndroidTVPolicy.resetControllerProbe(probe);
    equal(probe.settled, false, 'reset re-arms the probe');
    equal(probe.sawInput, false, 'reset forgets earlier input');
    approx(AndroidTVPolicy.controllerProbeRemaining(probe), 5.0, 'reset restores the full window');

    // A missing probe is a no-op instead of a crash.
    AndroidTVPolicy.resetControllerProbe(null);
    step = AndroidTVPolicy.stepControllerProbe(null, 1.0, true);
    equal(step.disable, false, 'a missing probe never disables');
    equal(AndroidTVPolicy.controllerProbeRemaining(null), 0.0, 'a missing probe has no window left');

    // Binary Prompt choice wrapping.
    equal(AndroidTVPolicy.selectPromptChoice(0, 1), 1, 'prompt move right from OK -> Cancel');
    equal(AndroidTVPolicy.selectPromptChoice(1, 1), 0, 'prompt move right from Cancel -> OK');
    equal(AndroidTVPolicy.selectPromptChoice(0, -1), 1, 'prompt move left from OK -> Cancel');
    equal(AndroidTVPolicy.selectPromptChoice(1, -1), 0, 'prompt move left from Cancel -> OK');
    equal(AndroidTVPolicy.selectPromptChoice(0, 0), 0, 'prompt zero delta keeps OK');
    equal(AndroidTVPolicy.selectPromptChoice(1, 0), 1, 'prompt zero delta keeps Cancel');

    Sys.println('AndroidTVPolicySpec: ok');
  }
}
