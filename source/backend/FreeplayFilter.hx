package backend;

import StringTools;

/** One song as the Freeplay filter page sees it. */
class FreeplayFilterEntry
{
  /** Display name, as the week lists it ("Bopeebo"). */
  public var songName:String;

  /** Mod folder the week came from; `''` is the base game. */
  public var folder:String;

  /** Best accuracy saved on any difficulty, 0..1, or `-1` when never played. */
  public var bestAccuracy:Float;

  /** There is at least one saved score or accuracy for this song. */
  public var played:Bool;

  public function new(songName:String, folder:String = '', bestAccuracy:Float = -1, played:Bool = false)
  {
    this.songName = songName;
    this.folder = folder == null ? '' : folder;
    this.bestAccuracy = bestAccuracy;
    this.played = played;
  }
}

/** What the save knows about one song path: its best run over every difficulty. */
class FreeplaySongStat
{
  /** Highest saved accuracy (0..1) across difficulties, `-1` when never played. */
  public var bestAccuracy:Float = -1;

  /** A saved score or accuracy exists for at least one difficulty. */
  public var played:Bool = false;

  public function new() {}
}

/** The orders the Freeplay list can be sorted in. */
class FreeplaySort
{
  public static inline var NAME:Int = 0;
  public static inline var MOD:Int = 1;
  public static inline var ACCURACY:Int = 2;
  public static inline var UNPLAYED:Int = 3;

  /** How many orders exist; also the wrap point when cycling. */
  public static function count():Int
  {
    return 4;
  }

  /** Keeps a value read from a save (or a script) inside the known orders. */
  public static function clamp(mode:Int):Int
  {
    if (mode < NAME) return NAME;
    if (mode >= count()) return count() - 1;
    return mode;
  }

  /** The order `step` positions after `mode`, wrapping at both ends. */
  public static function cycle(mode:Int, step:Int):Int
  {
    final total:Int = count();
    var next:Int = (clamp(mode) + step) % total;
    if (next < 0) next += total;
    return next;
  }

  /** Name shown next to "Sort by" on the filter page. */
  public static function label(mode:Int):String
  {
    return switch (clamp(mode))
    {
      case MOD: 'Mod';
      case ACCURACY: 'Best Accuracy';
      case UNPLAYED: 'Unplayed';
      default: 'Name';
    }
  }
}

/**
 * Everything the Freeplay filter page remembers: the search text, the order, the
 * mod shown, the favourites-only switch and the starred songs.
 *
 * Every change bumps {@link revision}, so `states.FreeplayState` can tell
 * whether closing the page has to rebuild the list or only save the stars.
 * Setters keep the fields in a valid state; `replaceStars` is what the save
 * loader uses.
 */
class FreeplayFilterState
{
  /** Text from the Freeplay search box; `''` shows every song. */
  public var query(default, null):String = '';

  /** One of the `FreeplaySort` orders. */
  public var sort(default, null):Int = FreeplaySort.NAME;

  /** Mod folder to show, `null` for every mod (and the base game). */
  public var mod(default, null):String = null;

  /** Hide every song that is not starred. */
  public var favouritesOnly(default, null):Bool = false;

  /** Moves on every change; see the class doc. */
  public var revision(default, null):Int = 0;

  var starred:Map<String, Bool> = new Map();

  public function new() {}

  /** Stable key for a star: the mod folder plus the song name, both lowercased. */
  public static function key(songName:String, folder:String):String
  {
    final modName:String = folder == null ? '' : folder;
    final name:String = songName == null ? '' : songName;
    return modName.toLowerCase() + '/' + name.toLowerCase();
  }

  public function setQuery(value:String):Void
  {
    final next:String = value == null ? '' : value;
    if (next == query) return;
    query = next;
    revision++;
  }

  public function setSort(mode:Int):Void
  {
    final next:Int = FreeplaySort.clamp(mode);
    if (next == sort) return;
    sort = next;
    revision++;
  }

  public function cycleSort(step:Int):Void
  {
    setSort(FreeplaySort.cycle(sort, step));
  }

  /** `folder` may be `''` (base game only) or `null` (every mod). */
  public function setMod(folder:String):Void
  {
    if (folder == mod) return;
    mod = folder;
    revision++;
  }

  /**
   * Cycles through "All Mods" and the folders passed in.
   * `folders` is the list from the current song list, base game first.
   */
  public function cycleMod(folders:Array<String>, step:Int):Void
  {
    final options:Array<String> = [null];
    for (folder in folders)
    {
      if (folder != null) options.push(folder);
    }

    var current:Int = options.indexOf(mod);
    if (current < 0) current = 0;
    var next:Int = (current + step) % options.length;
    if (next < 0) next += options.length;
    setMod(options[next]);
  }

  public function setFavouritesOnly(value:Bool):Void
  {
    if (value == favouritesOnly) return;
    favouritesOnly = value;
    revision++;
  }

  public function toggleFavouritesOnly():Void
  {
    setFavouritesOnly(!favouritesOnly);
  }

  public function isStarred(songName:String, folder:String):Bool
  {
    return starred.get(key(songName, folder)) == true;
  }

  /** Sets one star; returns the value now stored. */
  public function setStar(songName:String, folder:String, value:Bool):Bool
  {
    final starKey:String = key(songName, folder);
    final current:Bool = starred.get(starKey) == true;
    if (current == value)
    {
      if (!value) starred.remove(starKey);
      return value;
    }

    if (value) starred.set(starKey, true) else starred.remove(starKey);
    revision++;
    return value;
  }

  /** Flips one star; returns the value now stored. */
  public function toggleStar(songName:String, folder:String):Bool
  {
    return setStar(songName, folder, !isStarred(songName, folder));
  }

  public function starCount():Int
  {
    var total:Int = 0;
    for (_ in starred.keys()) total++;
    return total;
  }

  /** Keys of every starred song, sorted so a save file stays comparable. */
  public function starKeys():Array<String>
  {
    final keys:Array<String> = [];
    for (starKey in starred.keys()) keys.push(starKey);
    keys.sort(function(a:String, b:String):Int return a < b ? -1 : (a > b ? 1 : 0));
    return keys;
  }

  /** Replaces the stars with a save's list; bad entries are dropped. */
  public function replaceStars(keys:Array<String>):Void
  {
    starred = new Map();
    if (keys != null)
    {
      for (starKey in keys)
      {
        if (starKey == null || starKey.length == 0) continue;
        starred.set(starKey, true);
      }
    }
    revision++;
  }

  /** Clears the search text, order, mod and favourites switch; stars stay. */
  public function resetAll():Void
  {
    final changed:Bool = query.length > 0 || sort != FreeplaySort.NAME || mod != null || favouritesOnly;
    query = '';
    sort = FreeplaySort.NAME;
    mod = null;
    favouritesOnly = false;
    if (changed) revision++;
  }
}

/**
 * Renderer-free sorting and filtering behind `states.FreeplayState` and
 * `states.substates.FreeplayFilterSubState`.
 *
 * Freeplay used to have only the text box. This class adds the rest of the
 * question "which songs do I want to see?": show one mod at a time, star the
 * songs worth coming back to, order by name, by mod, by best accuracy, or put
 * everything never played at the top, and pick a random song out of whatever is
 * left. None of that needs Flixel, so `haxe --interp` drives it in CI:
 *
 * - `matches` is the filter (search text, mod, favourites-only).
 * - `order` returns the indexes to draw, filtered and sorted, stable on ties.
 * - `randomPick` turns a `[0, 1)` roll into one of those indexes.
 * - `collectStats` folds `Highscore.songScores` / `Highscore.songRating` into
 *   one best accuracy per song, resolving `foo-bar` to its own song before it
 *   can be mistaken for a difficulty of `foo`.
 *
 * Nothing here reads or writes a file; persistence lives in
 * `backend.FreeplayFilterStore`.
 */
class FreeplayFilter
{
  /** "Base Game" for `''`, the folder name otherwise. */
  public static function modLabel(folder:String):String
  {
    return (folder == null || folder.length == 0) ? 'Base Game' : folder;
  }

  /** Lowercased, trimmed text used for every comparison. */
  static function normalize(value:String):String
  {
    return value == null ? '' : StringTools.trim(value.toLowerCase());
  }

  /** Case-insensitive `a` before `b`, ties included. */
  static function compareText(a:String, b:String):Int
  {
    final one:String = normalize(a);
    final two:String = normalize(b);
    if (one < two) return -1;
    if (one > two) return 1;
    return 0;
  }

  /** True when the search box, the mod filter and the favourites switch all allow it. */
  public static function matches(entry:FreeplayFilterEntry, state:FreeplayFilterState):Bool
  {
    if (state.mod != null && entry.folder != state.mod) return false;
    if (state.favouritesOnly && !state.isStarred(entry.songName, entry.folder)) return false;

    final query:String = normalize(state.query);
    if (query.length == 0) return true;

    // Every word has to appear in the song name or in its mod name, so
    // "week 3 bop" finds a song of that mod without a special syntax.
    final haystack:String = normalize(entry.songName) + ' ' + normalize(modLabel(entry.folder));
    for (term in query.split(' '))
    {
      if (term.length == 0) continue;
      if (haystack.indexOf(term) == -1) return false;
    }
    return true;
  }

  /** How many entries the current filter keeps. */
  public static function count(entries:Array<FreeplayFilterEntry>, state:FreeplayFilterState):Int
  {
    var total:Int = 0;
    for (entry in entries)
    {
      if (matches(entry, state)) total++;
    }
    return total;
  }

  /**
   * Indexes into `entries` in display order: filtered by `matches` and sorted
   * by `state.sort`. Ties keep the order the week files listed them in, so the
   * list never reshuffles between two identical draws.
   */
  public static function order(entries:Array<FreeplayFilterEntry>, state:FreeplayFilterState):Array<Int>
  {
    final indexes:Array<Int> = [];
    for (i in 0...entries.length)
    {
      if (matches(entries[i], state)) indexes.push(i);
    }

    final mode:Int = state.sort;
    indexes.sort(function(a:Int, b:Int):Int {
      final one:FreeplayFilterEntry = entries[a];
      final two:FreeplayFilterEntry = entries[b];
      var result:Int = 0;

      if (mode == FreeplaySort.MOD)
      {
        result = compareText(modLabel(one.folder), modLabel(two.folder));
        if (result == 0) result = compareText(one.songName, two.songName);
      }
      else if (mode == FreeplaySort.ACCURACY)
      {
        result = compareAccuracy(one, two);
        if (result == 0) result = compareText(one.songName, two.songName);
      }
      else if (mode == FreeplaySort.UNPLAYED)
      {
        result = compareUnplayed(one, two);
        if (result == 0) result = compareText(one.songName, two.songName);
      }
      else
      {
        result = compareText(one.songName, two.songName);
        if (result == 0) result = compareText(modLabel(one.folder), modLabel(two.folder));
      }

      if (result == 0) result = compareText(one.folder, two.folder);
      if (result == 0) result = a - b;
      return result;
    });

    return indexes;
  }

  /** Best accuracy first, songs without one last. */
  static function compareAccuracy(one:FreeplayFilterEntry, two:FreeplayFilterEntry):Int
  {
    final a:Float = one.bestAccuracy;
    final b:Float = two.bestAccuracy;
    if (a < 0 && b < 0) return 0;
    if (a < 0) return 1;
    if (b < 0) return -1;
    if (a > b) return -1;
    if (a < b) return 1;
    return 0;
  }

  /** Never played first, then the played ones by best accuracy. */
  static function compareUnplayed(one:FreeplayFilterEntry, two:FreeplayFilterEntry):Int
  {
    if (one.played != two.played) return one.played ? 1 : -1;
    return compareAccuracy(one, two);
  }

  /**
   * Turns a `[0, 1)` roll into one of the indexes in `order`.
   * Returns `-1` for an empty list; a `1` roll is treated as "just below 1"
   * and a NaN roll as `0`, so a sloppy caller cannot read past the array.
   */
  public static function randomPick(order:Array<Int>, roll:Float):Int
  {
    if (order.length == 0) return -1;
    var value:Float = roll;
    if (!(value >= 0)) value = 0;
    if (value >= 1) value = 0.999999;
    return order[Math.floor(value * order.length)];
  }

  /** Distinct mod folders in `entries`, base game (`''`) first. */
  public static function availableMods(entries:Array<FreeplayFilterEntry>):Array<String>
  {
    final seen:Map<String, Bool> = new Map();
    final mods:Array<String> = [];
    for (entry in entries)
    {
      if (seen.get(entry.folder) == true) continue;
      seen.set(entry.folder, true);
      mods.push(entry.folder);
    }

    mods.sort(function(a:String, b:String):Int {
      if (a.length == 0) return b.length == 0 ? 0 : -1;
      if (b.length == 0) return 1;
      return compareText(a, b);
    });
    return mods;
  }

  /**
   * One stat per song path, folded from the raw `Highscore` maps.
   *
   * `songScores` keys are `formatToSongPath(song) + difficulty suffix`, and the
   * default difficulty has no suffix at all. Resolving the longest path first
   * keeps `foo-bar` from feeding its iron scores into `foo`.
   */
  public static function collectStats(paths:Array<String>, scores:Map<String, Int>, ratings:Map<String, Float>):Map<String, FreeplaySongStat>
  {
    final stats:Map<String, FreeplaySongStat> = new Map();
    final sorted:Array<String> = [];
    for (path in paths)
    {
      if (path == null || path.length == 0) continue;
      if (stats.exists(path)) continue;
      stats.set(path, new FreeplaySongStat());
      sorted.push(path);
    }
    sorted.sort(function(a:String, b:String):Int return b.length - a.length);

    if (ratings != null)
    {
      for (key in ratings.keys())
      {
        final path:String = resolvePath(key, sorted);
        if (path == null) continue;
        final value:Float = ratings.get(key);
        final stat:FreeplaySongStat = stats.get(path);
        if (value > stat.bestAccuracy) stat.bestAccuracy = value;
        if (value > 0) stat.played = true;
      }
    }

    if (scores != null)
    {
      for (key in scores.keys())
      {
        final path:String = resolvePath(key, sorted);
        if (path == null) continue;
        final value:Int = scores.get(key);
        if (value > 0) stats.get(path).played = true;
      }
    }

    return stats;
  }

  /** Song path a `Highscore` key belongs to, or `null` when it is not one of ours. */
  static function resolvePath(key:String, sortedPaths:Array<String>):String
  {
    if (key == null || key.length == 0) return null;
    for (path in sortedPaths)
    {
      if (key == path) return path;
      if (key.length > path.length + 1 && StringTools.startsWith(key, path + '-')) return path;
    }
    return null;
  }
}
