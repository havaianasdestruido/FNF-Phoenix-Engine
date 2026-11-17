import backend.FreeplayFilter;

/**
 * Contract tests for `backend.FreeplayFilter`, the renderer-free half of the
 * Freeplay filter page. No stubs and no game haxelibs:
 *
 *     bash tests/haxe/run-freeplay-filter.sh
 *
 * The cases follow what the page promises: the search box filters, a mod can be
 * shown alone, starred songs can be the only ones listed, the four orders put
 * what they name first (unplayed stays last on the accuracy order), ties keep
 * the week-file order so the list never jumps around, the random pick never
 * reads past the filtered list, and the `Highscore` maps fold into one best
 * accuracy per song without handing `foo-bar`'s scores to `foo`.
 */
class FreeplayFilterSpec
{
  static function check(ok:Bool, label:String):Void
  {
    if (!ok) throw label;
  }

  static function equal<V>(actual:V, expected:V, label:String):Void
  {
    if (actual != expected) throw '$label: expected "$expected", got "$actual"';
  }

  static function near(actual:Float, expected:Float, label:String):Void
  {
    if (Math.isNaN(actual) || Math.abs(actual - expected) > 0.000001) throw '$label: expected $expected, got $actual';
  }

  static function entry(name:String, folder:String = '', accuracy:Float = -1, played:Bool = false):FreeplayFilterEntry
  {
    return new FreeplayFilterEntry(name, folder, accuracy, played);
  }

  /** "Bopeebo"/"Pico" style names, in the order the week files list them. */
  static function testEntries():Array<FreeplayFilterEntry>
  {
    return [
      entry('Bopeebo', '', 0.95, true),
      entry('Fresh', '', -1, false),
      entry('Dad Battle', '', 0.80, true),
      entry('Ugh', 'week3-mod', -1, false),
      entry('Guns', 'week3-mod', 0.99, true),
      entry('Bopeebo', 'remix-mod', -1, false)
    ];
  }

  static function names(entries:Array<FreeplayFilterEntry>, order:Array<Int>):String
  {
    final parts:Array<String> = [];
    for (index in order) parts.push(entries[index].songName + '@' + entries[index].folder);
    return parts.join(', ');
  }

  static function main():Void
  {
    testDefaults();
    testSearchMatchesSongAndMod();
    testSearchNeedsEveryWord();
    testModFilter();
    testFavouritesOnly();
    testSortByName();
    testSortByMod();
    testSortByAccuracy();
    testSortByUnplayed();
    testTiesKeepTheWeekOrder();
    testRandomPick();
    testStatsFoldDifficulties();
    testStatsResolveTheLongestPath();
    testStatsSurviveEmptyMaps();
    testStars();
    testCycleSort();
    testCycleMod();
    testResetKeepsStars();
    testAvailableMods();
    testRevisionMovesOnlyOnChange();
    testBadInputIsHarmless();
    Sys.println('FreeplayFilterSpec passed');
  }

  static function testDefaults():Void
  {
    final filter = new FreeplayFilterState();
    equal(filter.query, '', 'default query');
    equal(filter.sort, FreeplaySort.NAME, 'default sort');
    equal(filter.mod, null, 'default mod');
    equal(filter.favouritesOnly, false, 'default favourites-only');
    equal(filter.revision, 0, 'default revision');
    equal(FreeplaySort.label(filter.sort), 'Name', 'default sort label');
  }

  static function testSearchMatchesSongAndMod():Void
  {
    final filter = new FreeplayFilterState();
    final entries = testEntries();

    filter.setQuery('bop');
    equal(names(entries, FreeplayFilter.order(entries, filter)), 'Bopeebo@, Bopeebo@remix-mod', 'search by name');
    equal(FreeplayFilter.count(entries, filter), 2, 'search count');

    filter.setQuery('WEEK3');
    equal(FreeplayFilter.count(entries, filter), 2, 'search is case-insensitive and reads the mod name');

    filter.setQuery('   ');
    equal(FreeplayFilter.count(entries, filter), entries.length, 'whitespace is not a query');
  }

  static function testSearchNeedsEveryWord():Void
  {
    final filter = new FreeplayFilterState();
    final entries = testEntries();

    filter.setQuery('bopeebo remix');
    equal(names(entries, FreeplayFilter.order(entries, filter)), 'Bopeebo@remix-mod', 'both words must match');

    filter.setQuery('bopeebo missing');
    equal(FreeplayFilter.count(entries, filter), 0, 'a missing word empties the list');
  }

  static function testModFilter():Void
  {
    final filter = new FreeplayFilterState();
    final entries = testEntries();

    filter.setMod('week3-mod');
    equal(names(entries, FreeplayFilter.order(entries, filter)), 'Guns@week3-mod, Ugh@week3-mod', 'one mod only');

    filter.setMod('');
    equal(FreeplayFilter.count(entries, filter), 3, 'base game only');

    filter.setMod(null);
    equal(FreeplayFilter.count(entries, filter), entries.length, 'every mod');
  }

  static function testFavouritesOnly():Void
  {
    final filter = new FreeplayFilterState();
    final entries = testEntries();

    filter.toggleStar('Bopeebo', '');
    filter.toggleStar('Guns', 'week3-mod');

    filter.setFavouritesOnly(true);
    equal(names(entries, FreeplayFilter.order(entries, filter)), 'Bopeebo@, Guns@week3-mod', 'starred songs only');

    // The same song name in another mod is a different star.
    check(!filter.isStarred('Bopeebo', 'remix-mod'), 'stars are per mod');

    filter.toggleFavouritesOnly();
    equal(FreeplayFilter.count(entries, filter), entries.length, 'switch back off');
  }

  static function testSortByName():Void
  {
    final filter = new FreeplayFilterState();
    final entries = testEntries();

    filter.setSort(FreeplaySort.NAME);
    equal(names(entries, FreeplayFilter.order(entries, filter)),
      'Bopeebo@, Bopeebo@remix-mod, Dad Battle@, Fresh@, Guns@week3-mod, Ugh@week3-mod', 'name order, case-insensitive');
  }

  static function testSortByMod():Void
  {
    final filter = new FreeplayFilterState();
    final entries = testEntries();

    filter.setSort(FreeplaySort.MOD);
    equal(names(entries, FreeplayFilter.order(entries, filter)),
      'Bopeebo@, Dad Battle@, Fresh@, Bopeebo@remix-mod, Guns@week3-mod, Ugh@week3-mod', 'mod order, base game first');
  }

  static function testSortByAccuracy():Void
  {
    final filter = new FreeplayFilterState();
    final entries = testEntries();

    filter.setSort(FreeplaySort.ACCURACY);
    equal(names(entries, FreeplayFilter.order(entries, filter)),
      'Guns@week3-mod, Bopeebo@, Dad Battle@, Bopeebo@remix-mod, Fresh@, Ugh@week3-mod',
      'best accuracy first, never played last');
  }

  static function testSortByUnplayed():Void
  {
    final filter = new FreeplayFilterState();
    final entries = testEntries();

    filter.setSort(FreeplaySort.UNPLAYED);
    equal(names(entries, FreeplayFilter.order(entries, filter)),
      'Bopeebo@remix-mod, Fresh@, Ugh@week3-mod, Guns@week3-mod, Bopeebo@, Dad Battle@',
      'never played first, then the played ones by best accuracy');
  }

  static function testTiesKeepTheWeekOrder():Void
  {
    final filter = new FreeplayFilterState();
    // Same name, same mod, same accuracy: nothing may reorder them by itself.
    final entries:Array<FreeplayFilterEntry> = [
      entry('Same', '', -1, false),
      entry('Same', '', -1, false),
      entry('Same', '', -1, false)
    ];

    for (mode in [FreeplaySort.NAME, FreeplaySort.MOD, FreeplaySort.ACCURACY, FreeplaySort.UNPLAYED])
    {
      filter.setSort(mode);
      final order:Array<Int> = FreeplayFilter.order(entries, filter);
      equal(order.join(','), '0,1,2', 'stable order in mode ' + mode);
    }
  }

  static function testRandomPick():Void
  {
    final order:Array<Int> = [4, 7, 9];
    equal(FreeplayFilter.randomPick(order, 0.0), 4, 'roll 0 picks the first');
    equal(FreeplayFilter.randomPick(order, 0.5), 7, 'roll 0.5 picks the middle');
    equal(FreeplayFilter.randomPick(order, 0.99), 9, 'roll 0.99 picks the last');
    equal(FreeplayFilter.randomPick(order, 1.0), 9, 'roll 1 does not read past the end');
    equal(FreeplayFilter.randomPick(order, Math.NaN), 4, 'a NaN roll falls back to the first');
    equal(FreeplayFilter.randomPick(order, -3), 4, 'a negative roll falls back to the first');
    equal(FreeplayFilter.randomPick([], 0.5), -1, 'empty list picks nothing');
  }

  static function testStatsFoldDifficulties():Void
  {
    final scores:Map<String, Int> = new Map();
    final ratings:Map<String, Float> = new Map();

    // `formatSong(song, diff)` is the song path, plus "-<difficulty>" unless the
    // difficulty is the default one; hard is the best run.
    scores.set('bopeebo', 900);
    ratings.set('bopeebo', 0.7);
    scores.set('bopeebo-hard', 1200);
    ratings.set('bopeebo-hard', 0.98);

    final stats:Map<String, FreeplaySongStat> = FreeplayFilter.collectStats(['bopeebo', 'fresh'], scores, ratings);
    near(stats.get('bopeebo').bestAccuracy, 0.98, 'best accuracy over difficulties');
    check(stats.get('bopeebo').played, 'a saved score counts as played');
    near(stats.get('fresh').bestAccuracy, -1, 'never played keeps -1');
    check(!stats.get('fresh').played, 'never played is not played');

    // An accuracy saved is enough to count as played even with a 0 score.
    final scores2:Map<String, Int> = new Map();
    final ratings2:Map<String, Float> = new Map();
    ratings2.set('fresh', 0.4);
    final stats2:Map<String, FreeplaySongStat> = FreeplayFilter.collectStats(['fresh'], scores2, ratings2);
    near(stats2.get('fresh').bestAccuracy, 0.4, 'accuracy without score');
    check(stats2.get('fresh').played, 'accuracy without score counts as played');
  }

  static function testStatsResolveTheLongestPath():Void
  {
    final scores:Map<String, Int> = new Map();
    final ratings:Map<String, Float> = new Map();

    // A song literally called "foo-bar" must not feed "foo".
    ratings.set('foo-bar', 0.9);
    ratings.set('foo-bar-hard', 0.5);
    ratings.set('foo', 0.2);

    final stats:Map<String, FreeplaySongStat> = FreeplayFilter.collectStats(['foo', 'foo-bar'], scores, ratings);
    near(stats.get('foo').bestAccuracy, 0.2, 'short song keeps its own accuracy');
    near(stats.get('foo-bar').bestAccuracy, 0.9, 'long song keeps its own accuracy');

    // A key for a song that is not in the list is ignored instead of crashing.
    // (The key is deliberately unrelated: with only "foo" in the list, a
    // "foo-bar" key is indistinguishable from a difficulty called "bar".)
    final onlyFoo:Map<String, Float> = new Map();
    onlyFoo.set('foo', 0.2);
    onlyFoo.set('some-other-song-hard', 1.0);
    final stats2:Map<String, FreeplaySongStat> = FreeplayFilter.collectStats(['foo'], scores, onlyFoo);
    near(stats2.get('foo').bestAccuracy, 0.2, 'unknown keys are ignored');
  }

  static function testStatsSurviveEmptyMaps():Void
  {
    final emptyScores:Map<String, Int> = new Map();
    final emptyRatings:Map<String, Float> = new Map();
    final stats:Map<String, FreeplaySongStat> = FreeplayFilter.collectStats(['one'], emptyScores, emptyRatings);
    near(stats.get('one').bestAccuracy, -1, 'empty save means unplayed');
    check(!stats.get('one').played, 'empty save is not played');

    // Nulls are allowed: a fresh profile has no maps at all yet.
    final stats2:Map<String, FreeplaySongStat> = FreeplayFilter.collectStats(['one'], null, null);
    near(stats2.get('one').bestAccuracy, -1, 'null maps are safe');
    equal(FreeplayFilter.collectStats([], emptyScores, emptyRatings).keys().hasNext(), false, 'no paths, no stats');
  }

  static function testStars():Void
  {
    final filter = new FreeplayFilterState();

    check(!filter.isStarred('Bopeebo', ''), 'nothing is starred by default');
    check(filter.toggleStar('Bopeebo', ''), 'toggle stars');
    check(filter.isStarred('Bopeebo', ''), 'star sticks');
    equal(filter.starCount(), 1, 'one star');
    check(!filter.toggleStar('Bopeebo', ''), 'toggle unstars');
    equal(filter.starCount(), 0, 'unstarred again');

    filter.setStar('Bopeebo', '', true);
    filter.setStar('Bopeebo', 'mod-a', true);
    equal(filter.starKeys().join('|'), '/bopeebo|mod-a/bopeebo', 'keys are mod-relative and sorted');

    filter.replaceStars(['mod-b/fresh', '', 'mod-b/fresh']);
    equal(filter.starCount(), 1, 'replaceStars drops blanks and duplicates');
    check(filter.isStarred('Fresh', 'mod-b'), 'loaded star is readable');
  }

  static function testCycleSort():Void
  {
    equal(FreeplaySort.cycle(FreeplaySort.NAME, 1), FreeplaySort.MOD, 'name -> mod');
    equal(FreeplaySort.cycle(FreeplaySort.UNPLAYED, 1), FreeplaySort.NAME, 'unplayed wraps to name');
    equal(FreeplaySort.cycle(FreeplaySort.NAME, -1), FreeplaySort.UNPLAYED, 'name back to unplayed');
    equal(FreeplaySort.clamp(-5), FreeplaySort.NAME, 'clamp below');
    equal(FreeplaySort.clamp(99), FreeplaySort.UNPLAYED, 'clamp above');
    equal(FreeplaySort.label(FreeplaySort.ACCURACY), 'Best Accuracy', 'accuracy label');
    equal(FreeplaySort.label(FreeplaySort.UNPLAYED), 'Unplayed', 'unplayed label');
    equal(FreeplaySort.label(FreeplaySort.MOD), 'Mod', 'mod label');
  }

  static function testCycleMod():Void
  {
    final filter = new FreeplayFilterState();
    final folders:Array<String> = ['', 'mod-a', 'mod-b'];

    equal(filter.mod, null, 'starts on all mods');
    filter.cycleMod(folders, 1);
    equal(filter.mod, '', 'base game is the first option');
    filter.cycleMod(folders, 1);
    equal(filter.mod, 'mod-a', 'next mod');
    filter.cycleMod(folders, 1);
    equal(filter.mod, 'mod-b', 'last mod');
    filter.cycleMod(folders, 1);
    equal(filter.mod, null, 'wraps back to all mods');
    filter.cycleMod(folders, -1);
    equal(filter.mod, 'mod-b', 'backwards wraps the other way');

    // A filter pointing at a mod that disappeared falls back to "all".
    filter.setMod('gone');
    filter.cycleMod(folders, 1);
    equal(filter.mod, '', 'unknown mod restarts the cycle');
  }

  static function testResetKeepsStars():Void
  {
    final filter = new FreeplayFilterState();
    filter.setQuery('bop');
    filter.setSort(FreeplaySort.ACCURACY);
    filter.setMod('mod-a');
    filter.setFavouritesOnly(true);
    filter.toggleStar('Bopeebo', '');

    filter.resetAll();
    equal(filter.query, '', 'reset clears the query');
    equal(filter.sort, FreeplaySort.NAME, 'reset restores the order');
    equal(filter.mod, null, 'reset shows every mod');
    equal(filter.favouritesOnly, false, 'reset clears favourites-only');
    check(filter.isStarred('Bopeebo', ''), 'reset keeps stars');
  }

  static function testAvailableMods():Void
  {
    final entries = testEntries();
    final mods:Array<String> = FreeplayFilter.availableMods(entries);
    equal(mods.join('|'), '|remix-mod|week3-mod', 'base game first, then alphabetical');
    equal(FreeplayFilter.modLabel(''), 'Base Game', 'base game label');
    equal(FreeplayFilter.modLabel('week3-mod'), 'week3-mod', 'mod label');
    equal(FreeplayFilter.modLabel(null), 'Base Game', 'null folder label');
  }

  static function testRevisionMovesOnlyOnChange():Void
  {
    final filter = new FreeplayFilterState();
    final start:Int = filter.revision;

    filter.setSort(FreeplaySort.NAME);
    equal(filter.revision, start, 'setting the current sort changes nothing');
    filter.setQuery('');
    equal(filter.revision, start, 'setting the current query changes nothing');

    filter.setSort(FreeplaySort.MOD);
    equal(filter.revision, start + 1, 'a real change bumps the revision');
    filter.setQuery('bop');
    equal(filter.revision, start + 2, 'the query bumps it too');
    filter.cycleMod([''], 1);
    equal(filter.revision, start + 3, 'the mod bumps it');
    filter.toggleFavouritesOnly();
    equal(filter.revision, start + 4, 'favourites-only bumps it');
    filter.toggleStar('Bopeebo', '');
    equal(filter.revision, start + 5, 'a star bumps it');
    filter.toggleStar('Bopeebo', '');
    equal(filter.revision, start + 6, 'unstarring bumps it again');

    filter.resetAll();
    equal(filter.revision, start + 7, 'reset bumps it once');
    filter.resetAll();
    equal(filter.revision, start + 7, 'resetting twice changes nothing');
  }

  static function testBadInputIsHarmless():Void
  {
    final filter = new FreeplayFilterState();
    filter.setQuery(null);
    equal(filter.query, '', 'null query is empty');
    filter.setMod(null);
    equal(filter.mod, null, 'null mod is every mod');
    filter.replaceStars(null);
    equal(filter.starCount(), 0, 'null stars are no stars');

    // A hand-edited save can hold an impossible mode.
    filter.setSort(99999);
    equal(filter.sort, FreeplaySort.UNPLAYED, 'sort clamped into range');

    final entries:Array<FreeplayFilterEntry> = [];
    equal(FreeplayFilter.order(entries, filter).length, 0, 'empty list sorts to nothing');
    equal(FreeplayFilter.count(entries, filter), 0, 'empty list counts nothing');

    final nullFolder = new FreeplayFilterEntry('Song', null, -1, false);
    equal(nullFolder.folder, '', 'null folder becomes base game');
  }
}
