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
