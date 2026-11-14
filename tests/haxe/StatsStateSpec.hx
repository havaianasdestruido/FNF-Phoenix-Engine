import backend.Achievements;
import backend.Paths;
import backend.PlayerSettings;
import backend.PlayerStats;
import backend.ViewportVisuals;
import flixel.FlxG;
import lime.system.Clipboard;
import mobile.MobileControls;
import objects.TouchTarget;
#if ACHIEVEMENTS_ALLOWED
import states.AchievementsMenuState;
#end
import states.MainMenuState;
import states.StatsState;
import states.StatsState.ResetStatsSubState;

using StringTools;

/**
 * Behavioral and wiring specs for `states.StatsState`, `states.ResetStatsSubState`,
 * and the Awards link in `states.AchievementsMenuState`.
 */
@:access(backend.PlayerStats)
@:access(states.StatsState)
@:access(states.ResetStatsSubState)
#if ACHIEVEMENTS_ALLOWED
@:access(states.AchievementsMenuState)
#end
class StatsStateSpec
{
  static var passed:Int = 0;
  static var failed:Int = 0;

  static function log(msg:String):Void
  {
    #if sys
    Sys.println(msg);
    #end
  }

  static function check(cond:Bool, label:String):Void
  {
    if (cond) passed++;
    else
    {
      failed++;
      log('FAIL: ' + label);
    }
  }

  static function eq<T>(actual:T, expected:T, label:String):Void
  {
    if (actual == expected) passed++;
    else
    {
      failed++;
      log('FAIL: ' + label + ' (expected ' + Std.string(expected) + ', got ' + Std.string(actual) + ')');
    }
  }

  static function freshEnv():Void
  {
    FlxG.reset();
    PlayerSettings.reset();
    Clipboard.reset();
    Paths.reset();
    ViewportVisuals.reset();
    Achievements.reset();
    MobileControls.enabled = false;
    TouchTarget.nextPressedTarget = null;
    PlayerStats.clearMemory();
    PlayerStats.loaded = false;
  }

  public static function main():Void
  {
    testCreateLayoutResizeLivePlaytimeAndDestroy();
    testScrollingAndClipboard();
    testResetPromptConfirmAndCancel();
    testNavigationAndAwardsLink();

    log('StatsStateSpec: ' + passed + ' passed, ' + failed + ' failed');
    #if sys
    if (failed > 0) Sys.exit(1);
    #end
  }

  static function testCreateLayoutResizeLivePlaytimeAndDestroy():Void
  {
    freshEnv();
    PlayerStats.load();
    PlayerStats.addPlaytime(3665.0, false); // 1h 01m 05s
    PlayerStats.recordJudgement('perfect');
    PlayerStats.recordJudgement('sick');
    PlayerStats.recordMiss();
    PlayerStats.recordDeath(false);
    for (i in 0...8)
      PlayerStats.recordSongFinished('Song ' + i, 'mod-' + i, 'Mod ' + i, i % 2 == 0, false);

    final state:StatsState = new StatsState(true);
    state.create();

    check(state.created, 'StatsState.create completes');
    check(Paths.storedCleared == 1 && Paths.unusedCleared == 1, 'StatsState clears stored/unused memory');
    check(state.contentCamera != null, 'contentCamera created');
    eq(FlxG.cameras.added.length, 1, 'contentCamera registered in FlxG.cameras');
    check(state.contentGroup.length > 20, 'dashboard cards and rows populated');
    eq(state.virtualPadAdded, 'UP_DOWN/A_B_C', 'virtual pad configured');
    check(state.virtualPadCameraAdded, 'virtual pad camera configured');
    check(state.playtimeValueText != null, 'playtime value text tracked for live updates');
    eq(state.playtimeValueText.text, '1h 01m 05s', 'initial formatted playtime shown');

    // Live playtime tick while StatsState stays open
    PlayerStats.addPlaytime(2.0, false);
    state.update(0.016);
    eq(state.playtimeValueText.text, '1h 01m 07s', 'playtime value updates live on update()');

    // Resize handling across widescreen and compact sizes
    FlxG.width = 1600;
    FlxG.height = 900;
    state.onResize(1600, 900);
    check(state.contentCamera.width == 1160, 'contentWidth caps cleanly at 1160 on ultrawide');

    FlxG.width = 800;
    FlxG.height = 600;
    state.onResize(800, 600);
    check(state.contentCamera.width == 720, 'contentWidth adapts on narrow window');
    check(state.maxScroll > 0, 'overflowing 8-entry list enables scrolling');

    // Destroy cleans up camera and flushes dirty stats
    final flushesBefore:Int = FlxG.save.flushCount;
    state.destroy();
    eq(FlxG.cameras.removed.length, 1, 'destroy removes contentCamera');
    check(state.contentCamera == null, 'contentCamera nulled on destroy');
    check(FlxG.save.flushCount == flushesBefore + 1, 'destroy flushes dirty stats');
  }

  static function testScrollingAndClipboard():Void
  {
    freshEnv();
    PlayerStats.load();
    for (i in 0...10)
      PlayerStats.recordSongFinished('Long Track ' + i, 'pack-' + i, 'Pack ' + i, true, false);

    FlxG.width = 1280;
    FlxG.height = 600;
    final state:StatsState = new StatsState(false);
    state.create();

    check(state.maxScroll > 0, 'scrollable content has positive maxScroll');
    PlayerSettings.player1.controls.UI_DOWN = true;
    state.update(0.5);
    check(state.scrollOffset > 0 && state.scrollOffset <= state.maxScroll, 'UI_DOWN scrolls within bounds');
    PlayerSettings.player1.controls.UI_DOWN = false;

    FlxG.mouse.wheel = 5;
    state.update(0.016);
    FlxG.mouse.wheel = 0;
    check(state.scrollOffset >= 0, 'mouse wheel scroll clamped >= 0');

    // Copy summary to clipboard
    FlxG.keys.justPressed.C = true;
    state.update(0.016);
    FlxG.keys.justPressed.C = false;
    eq(Clipboard.writes, 1, 'C copies summary to clipboard');
    check(Clipboard.text != null && Clipboard.text.indexOf('Songs Finished: 10') >= 0, 'clipboard text contains stats summary');
    check(state.hintText.text.indexOf('copied') >= 0, 'footer hint confirms copy');

    // Clipboard failure does not throw
    Clipboard.fail = true;
    FlxG.keys.justPressed.C = true;
    state.update(0.016);
    FlxG.keys.justPressed.C = false;
    check(state.hintText.text.indexOf('unavailable') >= 0, 'clipboard failure surfaces fallback hint');
    state.destroy();
  }

  static function testResetPromptConfirmAndCancel():Void
  {
    freshEnv();
    PlayerStats.load();

    // Empty stats should NOT open reset prompt
    final emptyState:StatsState = new StatsState(false);
    emptyState.create();
    PlayerSettings.player1.controls.RESET = true;
    emptyState.update(0.016);
    PlayerSettings.player1.controls.RESET = false;
    eq(emptyState.openedSubStates.length, 0, 'RESET ignored when stats are already empty');
    emptyState.destroy();

    // Populated stats open ResetStatsSubState
    PlayerStats.addPlaytime(120, false);
    PlayerStats.recordSongFinished('Tutorial', '', null, true, false);
    final state:StatsState = new StatsState(false);
    state.create();

    PlayerSettings.player1.controls.RESET = true;
    state.update(0.016);
    PlayerSettings.player1.controls.RESET = false;
    eq(state.openedSubStates.length, 1, 'RESET opens ResetStatsSubState');
    check(Std.isOfType(state.subState, ResetStatsSubState), 'opened substate is ResetStatsSubState');

    final prompt:ResetStatsSubState = cast state.subState;
    check(prompt.overlayCamera != null, 'ResetStatsSubState registers its own top overlayCamera');

    // Cancelling leaves stats intact
    PlayerSettings.player1.controls.BACK = true;
    prompt.update(0.016);
    PlayerSettings.player1.controls.BACK = false;
    check(prompt.closed, 'BACK closes reset prompt');
    eq(PlayerStats.songsFinished, 1, 'cancelling reset preserves stats');
    prompt.destroy();
    check(prompt.overlayCamera == null, 'ResetStatsSubState.destroy removes overlayCamera');

    // Re-open and confirm via HoldToConfirm callback
    PlayerSettings.player1.controls.RESET = true;
    state.update(0.016);
    PlayerSettings.player1.controls.RESET = false;
    final prompt2:ResetStatsSubState = cast state.subState;
    prompt2.confirmReset();
    check(prompt2.closed, 'confirmReset closes reset prompt');
    eq(PlayerStats.songsFinished, 0, 'confirming reset clears songsFinished');
    eq(PlayerStats.playtimeSeconds, 0.0, 'confirming reset clears playtimeSeconds');
    check(state.hintText.text.indexOf('reset') >= 0, 'footer hint confirms reset');
    prompt2.destroy();
    state.destroy();
  }

  static function testNavigationAndAwardsLink():Void
  {
    // Direct entry (returnToAwards == false): BACK goes to MainMenuState
    freshEnv();
    PlayerStats.load();
    final directState:StatsState = new StatsState(false);
    directState.create();
    PlayerSettings.player1.controls.BACK = true;
    directState.update(0.016);
    PlayerSettings.player1.controls.BACK = false;
    eq(FlxG.switchedStates.length, 1, 'direct StatsState BACK switches state');
    check(Std.isOfType(FlxG.switchedStates[0], MainMenuState), 'direct StatsState BACK returns to MainMenuState');
    directState.destroy();

    #if ACHIEVEMENTS_ALLOWED
    // From Awards (returnToAwards == true): BACK returns to AchievementsMenuState
    freshEnv();
    PlayerStats.load();
    final fromAwards:StatsState = new StatsState(true);
    fromAwards.create();
    PlayerSettings.player1.controls.BACK = true;
    fromAwards.update(0.016);
    PlayerSettings.player1.controls.BACK = false;
    eq(FlxG.switchedStates.length, 1, 'StatsState(true) BACK switches state');
    check(Std.isOfType(FlxG.switchedStates[0], AchievementsMenuState), 'StatsState(true) BACK returns to AchievementsMenuState');
    fromAwards.destroy();

    // TAB from StatsState switches to AchievementsMenuState
    freshEnv();
    PlayerStats.load();
    final tabBack:StatsState = new StatsState(false);
    tabBack.create();
    FlxG.keys.justPressed.TAB = true;
    tabBack.update(0.016);
    FlxG.keys.justPressed.TAB = false;
    eq(FlxG.switchedStates.length, 1, 'StatsState TAB switches state');
    check(Std.isOfType(FlxG.switchedStates[0], AchievementsMenuState), 'StatsState TAB opens AchievementsMenuState');
    tabBack.destroy();

    // AchievementsMenuState opens StatsState(true) on TAB and on stats tab click
    freshEnv();
    Achievements.registerPlaytimeBadge(5.0, false);
    final awards:AchievementsMenuState = new AchievementsMenuState();
    awards.create();
    check(awards.statsTabBg != null && awards.achTabBg != null, 'AchievementsMenuState builds top Awards/Stats tabs');
    awards.onResize(1600, 900);

    FlxG.keys.justPressed.TAB = true;
    awards.update(0.016);
    FlxG.keys.justPressed.TAB = false;
    eq(FlxG.switchedStates.length, 1, 'AchievementsMenuState TAB switches state');
    check(Std.isOfType(FlxG.switchedStates[0], StatsState), 'AchievementsMenuState TAB opens StatsState');
    final opened:StatsState = cast FlxG.switchedStates[0];
    check(opened.returnToAwards, 'StatsState opened from Awards remembers returnToAwards == true');

    // Touch / click on PLAYER STATS tab also switches to StatsState
    freshEnv();
    Achievements.registerPlaytimeBadge(5.0, false);
    final awardsTap:AchievementsMenuState = new AchievementsMenuState();
    awardsTap.create();
    TouchTarget.nextPressedTarget = awardsTap.statsTabBg;
    awardsTap.update(0.016);
    eq(FlxG.switchedStates.length, 1, 'tapping PLAYER STATS tab switches state');
    check(Std.isOfType(FlxG.switchedStates[0], StatsState), 'tapping PLAYER STATS tab opens StatsState');
    #end
  }
}
