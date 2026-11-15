import backend.Achievements;
import backend.PlayerStats;
import backend.PlayerStats.ModPlayEntry;
import backend.PlayerStats.PlayerStatsSnapshot;
import backend.PlayerStats.SongPlayEntry;
import backend.PlaytimeTracker;
import flixel.FlxG;
import lime.app.Application;

using StringTools;

/**
 * Unit specs for `backend.PlayerStats` and `backend.PlaytimeTracker`.
 *
 * Covers lifetime playtime beyond the 50-hour badge, legacy migration from
 * the `lol` badge, gameplay gating, per-judgement accounting, deaths, full
 * combos, song/mod leaderboards, persistence round-trips, corrupt saves,
 * explicit resets, and formatting helpers.
 */
@:access(backend.PlayerStats)
class PlayerStatsSpec
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

  static function near(actual:Float, expected:Float, eps:Float, label:String):Void
  {
    if (Math.abs(actual - expected) <= eps) passed++;
    else
    {
      failed++;
      log('FAIL: ' + label + ' (expected ' + expected + ' +/- ' + eps + ', got ' + actual + ')');
    }
  }

  static function freshEnv():Void
  {
    FlxG.reset();
    Application.reset();
    Achievements.reset();
    PlayerStats.clearMemory();
    PlayerStats.loaded = false;
  }

  public static function main():Void
  {
    testCleanDefaults();
    testGameplayGatingAndFullComboRules();
    testJudgementsAndAccuracy();
    testDeathsSongsModsAndRanking();
    testPlaytimeBeyondFiftyHoursAndPlaytimeTracker();
    testLegacyMigrationAndExplicitReset();
    testSerializationAndCorruptSaves();
    testFormattingSanitizationAndSummary();

    log('PlayerStatsSpec: ' + passed + ' passed, ' + failed + ' failed');
    #if sys
    if (failed > 0) Sys.exit(1);
    #end
  }

  static function testCleanDefaults():Void
  {
    freshEnv();
    PlayerStats.load();

    eq(PlayerStats.playtimeSeconds, 0.0, 'fresh playtime is 0');
    eq(PlayerStats.songsFinished, 0, 'fresh songsFinished is 0');
    eq(PlayerStats.fullCombos, 0, 'fresh fullCombos is 0');
    eq(PlayerStats.deaths, 0, 'fresh deaths is 0');
    eq(PlayerStats.totalNotesHit(), 0, 'fresh totalNotesHit is 0');
    eq(PlayerStats.totalJudgedNotes(), 0, 'fresh totalJudgedNotes is 0');
    eq(PlayerStats.weightedAccuracyPercent(), 0.0, 'fresh accuracy is 0');
    eq(PlayerStats.fullComboRatePercent(), 0.0, 'fresh FC rate is 0');
    check(!PlayerStats.hasAnyData(), 'fresh store reports hasAnyData == false');
    eq(PlayerStats.topSongs().length, 0, 'fresh topSongs is empty');
    eq(PlayerStats.topMods().length, 0, 'fresh topMods is empty');
  }

  static function testGameplayGatingAndFullComboRules():Void
  {
    check(PlayerStats.canTrackGameplay(false, false, false, false, false), 'normal run tracks stats');
    check(!PlayerStats.canTrackGameplay(true, false, false, false, false), 'botplay excluded');
    check(!PlayerStats.canTrackGameplay(false, true, false, false, false), 'practice mode excluded');
    check(!PlayerStats.canTrackGameplay(false, false, true, false, false), 'ffmpeg render excluded');
    check(!PlayerStats.canTrackGameplay(false, false, false, true, false), 'charting mode excluded');
    check(!PlayerStats.canTrackGameplay(false, false, false, false, true), 'trolling mode excluded');

    check(PlayerStats.isFullComboRun(0, 120, false), '0 misses with hits and not cheating is FC');
    check(!PlayerStats.isFullComboRun(1, 120, false), '1 miss is not FC');
    check(!PlayerStats.isFullComboRun(0, 0, false), '0 hits song is not FC');
    check(!PlayerStats.isFullComboRun(0, 120, true), 'cheating run is not FC');
    check(!PlayerStats.isFullComboRun(Math.NaN, 120, false), 'NaN misses is not FC');
  }

  static function testJudgementsAndAccuracy():Void
  {
    freshEnv();
    PlayerStats.load();

    PlayerStats.recordJudgement('perfect');
    PlayerStats.recordJudgement('PERFECT');
    PlayerStats.recordJudgement('marvelous');
    PlayerStats.recordJudgement('sick');
    PlayerStats.recordJudgement('Good');
    PlayerStats.recordJudgement('bad');
    PlayerStats.recordJudgement('shit');
    PlayerStats.recordJudgement('poor');
    PlayerStats.recordJudgement('crap');
    PlayerStats.recordJudgement('miss');
    PlayerStats.recordMiss();
    PlayerStats.recordJudgement('unknown_ignored_rating');

    eq(PlayerStats.perfects, 3, 'perfect/PERFECT/marvelous map to perfects');
    eq(PlayerStats.sicks, 1, 'sick maps to sicks (unknown ratings ignored)');
    eq(PlayerStats.goods, 1, 'Good maps to goods');
    eq(PlayerStats.bads, 1, 'bad maps to bads');
    eq(PlayerStats.poors, 3, 'shit/poor/crap map to poors');
    eq(PlayerStats.misses, 2, 'miss judgement + recordMiss both increment misses');
    eq(PlayerStats.totalNotesHit(), 9, 'totalNotesHit excludes misses');
    eq(PlayerStats.totalJudgedNotes(), 11, 'totalJudgedNotes includes misses');

    // Weighted accuracy (Conductor weights: 1.0, 1.0, 0.7, 0.4, 0, 0): (3+1+0.7+0.4)/11*100 = 5.1/11*100
    near(PlayerStats.weightedAccuracyPercent(), (5.1 / 11.0) * 100.0, 0.01, 'weighted accuracy matches Conductor weights');
    check(PlayerStats.hasAnyData(), 'recording judgements marks hasAnyData == true');

    // Ignore empty/null judgement names
    PlayerStats.recordJudgement(null);
    PlayerStats.recordJudgement('   ');
    eq(PlayerStats.totalJudgedNotes(), 11, 'null/blank judgements ignored');

    // Overflow saturation
    PlayerStats.perfects = 2147483647;
    PlayerStats.recordJudgement('perfect');
    eq(PlayerStats.perfects, 2147483647, 'judgement counter saturates at MAX_INT');
  }

  static function testDeathsSongsModsAndRanking():Void
  {
    freshEnv();
    PlayerStats.load();

    PlayerStats.recordDeath(true);
    PlayerStats.recordDeath(true);
    eq(PlayerStats.deaths, 2, 'deaths tracked');
    eq(FlxG.save.flushCount, 2, 'deaths flush to disk');

    // Base-game song played 3 times with spacing/case variations
    PlayerStats.recordSongFinished('Dad Battle', '', null, true, false);
    PlayerStats.recordSongFinished('dad-battle', '', null, false, false);
    PlayerStats.recordSongFinished('DAD BATTLE!', null, null, true, false);

    // Modded song with same title in a mod folder must NOT collide with base game!
    PlayerStats.recordSongFinished('Dad Battle', 'my-remix-mod', 'My Remix Mod', true, false);
    PlayerStats.recordSongFinished('Dad Battle', 'my-remix-mod', 'My Remix Mod', false, false);

    // Another mod played 4 times across 2 songs -> mod #1
    PlayerStats.recordSongFinished('Alpha Song', 'cool-mod', 'Cool Mod', true, false);
    PlayerStats.recordSongFinished('Alpha Song', 'cool-mod', 'Cool Mod', true, false);
    PlayerStats.recordSongFinished('Beta Song', 'cool-mod', 'Cool Mod', false, false);
    PlayerStats.recordSongFinished('Beta Song', 'cool-mod', 'Cool Mod', false, false);

    // Tie-break check (2 plays each): 'Alpha Song' vs 'Beta Song' vs 'Dad Battle' (my-remix-mod)
    eq(PlayerStats.songsFinished, 9, 'songsFinished counts all finished songs');
    eq(PlayerStats.fullCombos, 5, 'fullCombos counts only FC runs');
    near(PlayerStats.fullComboRatePercent(), (5.0 / 9.0) * 100.0, 0.01, 'FC rate computed accurately');

    final songs:Array<SongPlayEntry> = PlayerStats.topSongs(10);
    eq(songs.length, 4, '4 distinct song keys (base Dad Battle distinct from modded Dad Battle)');
    eq(songs[0].key, 'dad-battle', 'base Dad Battle is #1 with 3 plays');
    eq(songs[0].plays, 3, 'base Dad Battle has 3 plays');
    eq(songs[0].mod, '', 'base Dad Battle has empty mod');

    // Remaining 3 songs all have 2 plays -> sorted alphabetically by name
    eq(songs[1].name, 'Alpha Song', 'tie #1 alphabetically is Alpha Song');
    eq(songs[1].plays, 2, 'Alpha Song has 2 plays');
    eq(songs[2].name, 'Beta Song', 'tie #2 alphabetically is Beta Song');
    eq(songs[3].key, 'my-remix-mod/dad-battle', 'modded Dad Battle kept separate from base game');
    eq(songs[3].modName, 'My Remix Mod', 'mod display name stored on song entry');

    final mods:Array<ModPlayEntry> = PlayerStats.topMods(10);
    eq(mods.length, 2, 'base game plays are NOT counted as a mod');
    eq(mods[0].key, 'cool-mod', 'Cool Mod is #1 mod with 4 plays');
    eq(mods[0].name, 'Cool Mod', 'Cool Mod display name preserved');
    eq(mods[0].plays, 4, 'Cool Mod plays == 4');
    eq(mods[1].key, 'my-remix-mod', 'My Remix Mod is #2 with 2 plays');
    eq(mods[1].plays, 2, 'My Remix Mod plays == 2');

    // Limit enforcement (<= 0 returns all)
    eq(PlayerStats.topSongs(2).length, 2, 'topSongs respects limit');
    eq(PlayerStats.topMods(1).length, 1, 'topMods respects limit');
    eq(PlayerStats.topSongs(0).length, 4, 'topSongs(0) returns all entries');
  }

  static function testPlaytimeBeyondFiftyHoursAndPlaytimeTracker():Void
  {
    freshEnv();
    #if ACHIEVEMENTS_ALLOWED
    // Start at 49.99 hours (36 seconds away from the 50-hour badge)
    Achievements.registerPlaytimeBadge(49.99, false);
    #end
    PlayerStats.load();

    #if ACHIEVEMENTS_ALLOWED
    near(PlayerStats.playtimeSeconds, 49.99 * 3600.0, 0.5, 'seeded from 49.99h legacy badge');
    #else
    // Seed directly past 49.99h when achievements are compiled out
    PlayerStats.addPlaytime(49.99 * 3600.0, false);
    #end

    final tracker:PlaytimeTracker = new PlaytimeTracker();

    // Advance 40 seconds -> crosses 50h badge threshold!
    tracker.update(40.0);
    near(PlayerStats.playtimeSeconds, 49.99 * 3600.0 + 40.0, 0.5, 'playtime crosses 50 hours');
    #if ACHIEVEMENTS_ALLOWED
    check(Achievements.isUnlocked('lol'), '50-hour badge unlocks when crossing 50h');
    #end

    // Now the badge is ALREADY unlocked! Keep ticking 2 more hours + 65 seconds.
    final flushesBefore:Int = FlxG.save.flushCount;
    tracker.update(3600.0);
    tracker.update(3600.0);
    tracker.update(65.0);

    near(PlayerStats.playtimeSeconds, 49.99 * 3600.0 + 40.0 + 7265.0, 0.5,
      'lifetime playtime keeps accumulating AFTER 50h badge is unlocked');
    check(FlxG.save.flushCount > flushesBefore, 'PlaytimeTracker keeps flushing every 60s after 50h');

    // Test exit flush for sub-60s remainder
    final flushesBeforeExit:Int = FlxG.save.flushCount;
    tracker.update(15.0);
    Application.current.onExit.dispatch(0);
    eq(FlxG.save.flushCount, flushesBeforeExit + 1, 'onExit flushes pending <60s playtime');
    check(FlxG.save.data.playerStats != null, 'playerStats JSON persisted on exit');

    // Ignore invalid elapsed deltas
    final beforeInvalid:Float = PlayerStats.playtimeSeconds;
    tracker.update(0);
    tracker.update(-10);
    tracker.update(Math.NaN);
    tracker.update(Math.POSITIVE_INFINITY);
    near(PlayerStats.playtimeSeconds, beforeInvalid, 0.001, 'invalid elapsed values ignored');

    // Destroy cleans up onExit listener cleanly
    tracker.destroy();
    eq(Application.current.onExit.listeners.length, 0, 'destroy removes Application.onExit listener');
  }

  static function testLegacyMigrationAndExplicitReset():Void
  {
    freshEnv();
    #if ACHIEVEMENTS_ALLOWED
    Achievements.registerPlaytimeBadge(12.5, false);
    #end
    PlayerStats.load();

    #if ACHIEVEMENTS_ALLOWED
    near(PlayerStats.playtimeSeconds, 45000.0, 0.5, 'legacy lol badge (12.5h) seeds initial playtimeSeconds');
    #end

    // Explicit reset persists an empty v1 JSON record so rebooting stays at 0!
    PlayerStats.recordSongFinished('Bopeebo', '', null, true, false);
    PlayerStats.reset(true);
    eq(PlayerStats.playtimeSeconds, 0.0, 'reset zeroes playtimeSeconds');
    eq(PlayerStats.songsFinished, 0, 'reset zeroes songsFinished');
    check(FlxG.save.data.playerStats != null, 'reset writes explicit empty v1 save payload');

    // Simulate restarting the game: load() must NOT re-seed from the legacy badge!
    PlayerStats.clearMemory();
    PlayerStats.loaded = false;
    PlayerStats.load();
    eq(PlayerStats.playtimeSeconds, 0.0, 'reboot after explicit reset does NOT re-seed from legacy badge');
    eq(PlayerStats.songsFinished, 0, 'reboot after explicit reset stays empty');
  }

  static function testSerializationAndCorruptSaves():Void
  {
    freshEnv();
    PlayerStats.load();

    PlayerStats.addPlaytime(52 * 3600 + 14 * 60 + 8, false);
    PlayerStats.recordJudgement('perfect');
    PlayerStats.recordJudgement('sick');
    PlayerStats.recordJudgement('good');
    PlayerStats.recordJudgement('bad');
    PlayerStats.recordJudgement('shit');
    PlayerStats.recordMiss();
    PlayerStats.recordDeath(false);
    PlayerStats.recordSongFinished('Fresh', 'retro-pack', 'Retro Pack', true, false);
    PlayerStats.recordSongFinished('Bopeebo', '', null, false, false);

    final encoded:String = PlayerStats.encodeJson();
    PlayerStats.clearMemory();
    PlayerStats.loaded = false;
    PlayerStats.loadFromDynamic(encoded, 99.0); // seed ignored because encoded != null

    near(PlayerStats.playtimeSeconds, 52 * 3600 + 14 * 60 + 8, 0.01, 'round-trip playtimeSeconds');
    eq(PlayerStats.songsFinished, 2, 'round-trip songsFinished');
    eq(PlayerStats.fullCombos, 1, 'round-trip fullCombos');
    eq(PlayerStats.deaths, 1, 'round-trip deaths');
    eq(PlayerStats.perfects, 1, 'round-trip perfects');
    eq(PlayerStats.sicks, 1, 'round-trip sicks');
    eq(PlayerStats.goods, 1, 'round-trip goods');
    eq(PlayerStats.bads, 1, 'round-trip bads');
    eq(PlayerStats.poors, 1, 'round-trip poors');
    eq(PlayerStats.misses, 1, 'round-trip misses');
    eq(PlayerStats.topSongs().length, 2, 'round-trip songs');
    eq(PlayerStats.topMods().length, 1, 'round-trip mods');
    eq(PlayerStats.topMods()[0].name, 'Retro Pack', 'round-trip mod display name');

    // Corrupt JSON does not throw
    PlayerStats.loadFromDynamic('{not valid json!!!');
    eq(PlayerStats.songsFinished, 0, 'corrupt JSON degrades safely to empty stats');

    // Wrong field types & negative values degrade safely
    PlayerStats.loadFromDynamic({
      playtimeSeconds: -500,
      songsFinished: true,
      fullCombos: 'oops',
      deaths: 7.9,
      judgements: {
        perfects: -4,
        sicks: 12,
        goods: null,
        bads: 'bad',
        poors: 3,
        misses: false
      },
      songs: ([
        null,
        {key: '', name: '', plays: 5},
        {key: 'valid-song', name: 'Valid\nSong', plays: 4, mod: 'mod-a', modName: 'Mod A'},
        {key: 'zero-plays', name: 'Zero', plays: 0}
      ]:Array<Dynamic>),
      mods: ([
        'not-an-object',
        {key: 'mod-a', name: 'Mod A', plays: 4},
        {key: '', name: 'Blank', plays: 2}
      ]:Array<Dynamic>)
    });
    eq(PlayerStats.playtimeSeconds, 0.0, 'negative playtime ignored');
    eq(PlayerStats.songsFinished, 0, 'boolean songsFinished ignored');
    eq(PlayerStats.fullCombos, 0, 'string fullCombos ignored');
    eq(PlayerStats.deaths, 7, 'float deaths floored safely');
    eq(PlayerStats.perfects, 0, 'negative perfects ignored');
    eq(PlayerStats.sicks, 12, 'valid sicks preserved');
    eq(PlayerStats.poors, 3, 'valid poors preserved');
    eq(PlayerStats.misses, 0, 'boolean misses ignored');
    eq(PlayerStats.topSongs().length, 1, 'invalid/empty song rows skipped');
    eq(PlayerStats.topSongs()[0].name, 'Valid Song', 'newlines stripped from song names');
    eq(PlayerStats.topMods().length, 1, 'invalid/empty mod rows skipped');
  }

  static function testFormattingSanitizationAndSummary():Void
  {
    eq(PlayerStats.formatPlaytime(0), '0s', 'formatPlaytime(0)');
    eq(PlayerStats.formatPlaytime(-5), '0s', 'formatPlaytime(-5)');
    eq(PlayerStats.formatPlaytime(Math.NaN), '0s', 'formatPlaytime(NaN)');
    eq(PlayerStats.formatPlaytime(45), '45s', 'formatPlaytime(45)');
    eq(PlayerStats.formatPlaytime(125), '2m 05s', 'formatPlaytime(125)');
    eq(PlayerStats.formatPlaytime(3661), '1h 01m 01s', 'formatPlaytime(3661)');
    eq(PlayerStats.formatPlaytime(125 * 3600 + 4 * 60 + 9), '125h 04m 09s', 'formatPlaytime(125h+)');

    eq(PlayerStats.formatCount(0), '0', 'formatCount(0)');
    eq(PlayerStats.formatCount(999), '999', 'formatCount(999)');
    eq(PlayerStats.formatCount(1000), '1,000', 'formatCount(1,000)');
    eq(PlayerStats.formatCount(1234567), '1,234,567', 'formatCount(1,234,567)');

    eq(PlayerStats.formatPercent(0, 1), '0.0%', 'formatPercent(0, 1)');
    eq(PlayerStats.formatPercent(96.425, 2), '96.43%', 'formatPercent(96.425, 2)');
    eq(PlayerStats.formatPercent(150, 1), '100.0%', 'formatPercent clamps > 100');

    eq(PlayerStats.normalizeSongKey('Dad Battle!'), 'dad-battle', 'normalizeSongKey');
    eq(PlayerStats.sanitizeLabel('Hello\t\nWorld', 10), 'Hello W...', 'sanitizeLabel collapses whitespace and truncates');

    freshEnv();
    PlayerStats.load();
    PlayerStats.addPlaytime(3600, false);
    PlayerStats.recordJudgement('sick');
    PlayerStats.recordSongFinished('Bopeebo', 'test-mod', 'Test Mod', true, false);
    final summary:String = PlayerStats.buildSummaryText(5);
    check(summary.indexOf('Playtime:') >= 0 && summary.indexOf('1h 00m 00s') >= 0, 'summary includes playtime');
    check(summary.indexOf('Songs Finished: 1') >= 0, 'summary includes songs finished');
    check(summary.indexOf('Full Combos:') >= 0 && summary.indexOf('100.0%') >= 0, 'summary includes full combos');
    check(summary.indexOf('Perfect:') >= 0 && summary.indexOf('Miss:') >= 0, 'summary includes judgements');
    check(summary.indexOf('Bopeebo') >= 0, 'summary includes top songs');
    check(summary.indexOf('Test Mod') >= 0, 'summary includes top mods');
  }
}
