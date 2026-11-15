package backend;

import flixel.FlxG;
import haxe.Json;

using StringTools;

/** Lifetime play count for one song. */
typedef SongPlayEntry =
{
  var key:String;
  var name:String;
  var plays:Int;
  @:optional var mod:String;
  @:optional var modName:String;
}

/** Lifetime play count for one mod folder. */
typedef ModPlayEntry =
{
  var key:String;
  var name:String;
  var plays:Int;
}

/** Lifetime note counts grouped by judgement. */
typedef JudgementCounts =
{
  var perfects:Int;
  var sicks:Int;
  var goods:Int;
  var bads:Int;
  var poors:Int;
  var misses:Int;
}

/** Read-only snapshot rendered by `states.StatsState`. */
typedef PlayerStatsSnapshot =
{
  var playtimeSeconds:Float;
  var songsFinished:Int;
  var fullCombos:Int;
  var deaths:Int;
  var judgements:JudgementCounts;
  var topSongs:Array<SongPlayEntry>;
  var topMods:Array<ModPlayEntry>;
  var uniqueSongs:Int;
  var uniqueMods:Int;
}

/**
 * Persistent lifetime player statistics.
 *
 * Tracks cumulative playtime (continuing indefinitely past the 50-hour
 * achievement threshold), songs finished, notes per judgement, deaths,
 * full combos, and most-played songs and mods.
 *
 * Stored as a versioned JSON string under `FlxG.save.data.playerStats` so the
 * save payload is portable across every target (C++, Android, iOS, HTML5,
 * Flash/AIR and Neko) without relying on target-specific `Map` serialization.
 */
class PlayerStats
{
  /** On-disk payload schema version. */
  public static inline final SCHEMA_VERSION:Int = 1;

  /** Field written into `FlxG.save.data`. */
  public static inline final SAVE_FIELD:String = 'playerStats';

  /** Achievement ID used for one-time playtime migration on older saves. */
  public static inline final PLAYTIME_ACHIEVEMENT_ID:String = 'lol';

  /** Target hours of the playtime achievement, used when already unlocked. */
  public static inline final PLAYTIME_ACHIEVEMENT_HOURS:Float = 50;

  /** Maximum character length preserved for a song or mod display name. */
  public static inline final MAX_NAME_LENGTH:Int = 64;

  static inline final MAX_INT:Int = 2147483647;

  /** Total seconds spent with the game running. */
  public static var playtimeSeconds(default, null):Float = 0;

  /** Total songs played to completion in normal gameplay. */
  public static var songsFinished(default, null):Int = 0;

  /** Total finished songs completed with zero misses and at least one hit. */
  public static var fullCombos(default, null):Int = 0;

  /** Total game overs triggered in normal gameplay. */
  public static var deaths(default, null):Int = 0;

  /** Lifetime Perfect (Marvelous) judgements. */
  public static var perfects(default, null):Int = 0;

  /** Lifetime Sick judgements. */
  public static var sicks(default, null):Int = 0;

  /** Lifetime Good judgements. */
  public static var goods(default, null):Int = 0;

  /** Lifetime Bad judgements. */
  public static var bads(default, null):Int = 0;

  /** Lifetime Poor (`shit`) judgements. */
  public static var poors(default, null):Int = 0;

  /** Lifetime missed notes / miss presses. */
  public static var misses(default, null):Int = 0;

  static var songPlays:Map<String, SongPlayEntry> = new Map<String, SongPlayEntry>();
  static var modPlays:Map<String, ModPlayEntry> = new Map<String, ModPlayEntry>();
  static var dirty:Bool = false;
  static var loaded:Bool = false;

  /**
   * Loads saved player statistics from `FlxG.save.data`.
   *
   * Safe to call multiple times: once loaded, subsequent calls are no-ops.
   * On the first load after upgrading from a build without `PlayerStats`,
   * playtime is seeded from the 50-hour achievement progress so existing
   * players keep their previously tracked hours.
   */
  public static function load():Void
  {
    if (loaded) return;
    if (FlxG.save == null || FlxG.save.data == null) return;

    final raw:Dynamic = Reflect.field(FlxG.save.data, SAVE_FIELD);
    if (raw == null)
    {
      final seedHours:Float = readLegacyPlaytimeHours();
      loadFromDynamic(null, seedHours);
      loaded = true;
      if (seedHours > 0) save(false);
    }
    else
    {
      loadFromDynamic(raw, 0);
      loaded = true;
    }
  }

  /**
   * Writes current stats into `FlxG.save.data` and optionally flushes to disk.
   *
   * @param flush whether to call `FlxG.save.flush()` immediately.
   */
  public static function save(flush:Bool = true):Void
  {
    if (FlxG.save == null || FlxG.save.data == null) return;
    Reflect.setField(FlxG.save.data, SAVE_FIELD, encodeJson());
    dirty = false;
    if (flush) FlxG.save.flush();
  }

  /** Flushes pending in-memory updates (e.g. notes hit before leaving PlayState). */
  public static function flushIfDirty():Void
  {
    if (dirty) save(true);
  }

  /**
   * Resets every lifetime stat back to zero.
   *
   * Does not touch `Achievements` or `Highscore`. When `persist` is true, an
   * empty versioned record is saved right away so the next boot does not
   * re-seed playtime from the 50-hour achievement.
   *
   * @param persist whether to write and flush the cleared stats to `FlxG.save`.
   */
  public static function reset(persist:Bool = true):Void
  {
    clearMemory();
    loaded = true;
    if (persist) save(true);
  }

  /**
   * Whether a `PlayState` session represents genuine player gameplay rather
   * than botplay, practice mode, video rendering, chart editor testing or
   * troll mode.
   */
  public static inline function canTrackGameplay(cpuControlled:Bool, practiceMode:Bool,
      ffmpegMode:Bool, chartingMode:Bool, trollingMode:Bool):Bool
  {
    return !cpuControlled && !practiceMode && !ffmpegMode && !chartingMode && !trollingMode;
  }

  /**
   * Whether a completed song counts as a Full Combo: zero misses, at least one
   * judged note hit, and no mid-song cheat flag.
   */
  public static inline function isFullComboRun(songMisses:Float, totalHits:Int, playerIsCheating:Bool):Bool
  {
    return !playerIsCheating && !Math.isNaN(songMisses) && songMisses <= 0 && totalHits > 0;
  }

  /**
   * Adds elapsed runtime seconds to lifetime playtime.
   *
   * @param seconds elapsed seconds to add; non-positive or non-finite values are ignored.
   * @param persist whether to flush immediately (usually false during frame updates).
   */
  public static function addPlaytime(seconds:Float, persist:Bool = false):Void
  {
    if (Math.isNaN(seconds) || !Math.isFinite(seconds) || seconds <= 0) return;
    playtimeSeconds += seconds;
    dirty = true;
    if (persist) save(true);
  }

  /**
   * Tallies one or more judged player notes.
   *
   * Fast-paths the canonical lowercase rating names from `Conductor.Rating`
   * without allocating strings during active gameplay.
   *
   * @param ratingName judgement identifier (`perfect`, `sick`, `good`, `bad`, `shit`/`poor`, `miss`).
   * @param count      number of notes to add (defaults to 1).
   */
  public static function recordJudgement(ratingName:String, count:Int = 1):Void
  {
    if (ratingName == null || count <= 0) return;

    switch (ratingName)
    {
      case 'perfect':
        perfects = safeAddInt(perfects, count);
        dirty = true;
        return;
      case 'sick':
        sicks = safeAddInt(sicks, count);
        dirty = true;
        return;
      case 'good':
        goods = safeAddInt(goods, count);
        dirty = true;
        return;
      case 'bad':
        bads = safeAddInt(bads, count);
        dirty = true;
        return;
      case 'shit', 'poor', 'crap':
        poors = safeAddInt(poors, count);
        dirty = true;
        return;
      case 'miss':
        misses = safeAddInt(misses, count);
        dirty = true;
        return;
      default:
    }

    switch (ratingName.trim().toLowerCase())
    {
      case 'perfect', 'marvelous', 'marv':
        perfects = safeAddInt(perfects, count);
        dirty = true;
      case 'sick':
        sicks = safeAddInt(sicks, count);
        dirty = true;
      case 'good':
        goods = safeAddInt(goods, count);
        dirty = true;
      case 'bad':
        bads = safeAddInt(bads, count);
        dirty = true;
      case 'shit', 'poor', 'crap':
        poors = safeAddInt(poors, count);
        dirty = true;
      case 'miss':
        misses = safeAddInt(misses, count);
        dirty = true;
      default:
    }
  }

  /**
   * Tallies one or more missed notes / miss presses.
   *
   * @param count number of misses to add (defaults to 1).
   */
  public static function recordMiss(count:Int = 1):Void
  {
    if (count <= 0) return;
    misses = safeAddInt(misses, count);
    dirty = true;
  }

  /**
   * Tallies a player death (Game Over).
   *
   * @param persist whether to flush immediately (true by default so rage-quits still count).
   */
  public static function recordDeath(persist:Bool = true):Void
  {
    deaths = safeAddInt(deaths, 1);
    dirty = true;
    if (persist) save(true);
  }

  /**
   * Tallies a finished song, updating total clears, full combos, per-song play
   * count and (when played from a mod folder) per-mod play count.
   *
   * @param songName       song title or slug (`PlayState.SONG.song`).
   * @param modFolder      active mod folder (`Mods.currentModDirectory`), empty for base game.
   * @param modDisplayName optional human-readable mod name (e.g. from `pack.json`).
   * @param isFullCombo    whether the song finished with zero misses and at least one hit.
   * @param persist        whether to flush immediately to `FlxG.save`.
   */
  public static function recordSongFinished(songName:String, ?modFolder:String = '',
      ?modDisplayName:String = null, isFullCombo:Bool = false, persist:Bool = true):Void
  {
    songsFinished = safeAddInt(songsFinished, 1);
    if (isFullCombo) fullCombos = safeAddInt(fullCombos, 1);

    final modKey:String = (modFolder == null) ? '' : modFolder.trim();
    final cleanModName:String = modKey.length > 0
      ? sanitizeLabel((modDisplayName != null && modDisplayName.trim().length > 0) ? modDisplayName : modKey)
      : '';

    final rawSong:String = (songName == null) ? '' : songName.trim();
    final songSlug:String = normalizeSongKey(rawSong);
    if (songSlug.length > 0)
    {
      final cleanSongName:String = sanitizeLabel(rawSong.length > 0 ? rawSong : songSlug);
      final songKey:String = modKey.length > 0 ? (modKey + '/' + songSlug) : songSlug;
      addSongPlay(songKey, cleanSongName, 1, modKey, cleanModName);
    }

    if (modKey.length > 0)
      addModPlay(modKey, cleanModName, 1);

    dirty = true;
    if (persist) save(true);
  }

  /** Total non-miss notes judged across every judgement bucket. */
  public static inline function totalNotesHit():Int
  {
    var sum:Int = safeAddInt(perfects, sicks);
    sum = safeAddInt(sum, goods);
    sum = safeAddInt(sum, bads);
    sum = safeAddInt(sum, poors);
    return sum;
  }

  /** Total judged notes including misses. */
  public static inline function totalJudgedNotes():Int
    return safeAddInt(totalNotesHit(), misses);

  /** Percentage of judged notes that were hit rather than missed (`0..100`). */
  public static function hitRatePercent():Float
  {
    final total:Int = totalJudgedNotes();
    if (total <= 0) return 0;
    return (totalNotesHit() / total) * 100.0;
  }

  /**
   * Weighted lifetime accuracy (`0..100`) using the engine's standard rating
   * weights (`Perfect`/`Sick` = 1.0, `Good` = 0.7, `Bad` = 0.4, `Poor`/`Miss` = 0).
   */
  public static function weightedAccuracyPercent():Float
  {
    final total:Int = totalJudgedNotes();
    if (total <= 0) return 0;
    final weighted:Float = perfects + sicks + (goods * 0.7) + (bads * 0.4);
    return Math.min(100.0, Math.max(0.0, (weighted / total) * 100.0));
  }

  /** Percentage of finished songs that ended in a Full Combo (`0..100`). */
  public static function fullComboRatePercent():Float
  {
    if (songsFinished <= 0) return 0;
    return Math.min(100.0, (fullCombos / songsFinished) * 100.0);
  }

  /** Whether any lifetime statistic is currently non-zero. */
  public static function hasAnyData():Bool
  {
    return playtimeSeconds >= 1.0 || songsFinished > 0 || fullCombos > 0 || deaths > 0
      || totalJudgedNotes() > 0 || uniqueSongsCount() > 0 || uniqueModsCount() > 0;
  }

  /** Number of distinct songs recorded in play history. */
  public static function uniqueSongsCount():Int
  {
    var count:Int = 0;
    for (_ in songPlays.keys()) count++;
    return count;
  }

  /** Number of distinct mods recorded in play history. */
  public static function uniqueModsCount():Int
  {
    var count:Int = 0;
    for (_ in modPlays.keys()) count++;
    return count;
  }

  /**
   * Most-played songs ordered by play count descending, with alphabetical
   * tie-breaking.
   *
   * @param limit maximum number of entries to return (`<= 0` returns all).
   */
  public static function topSongs(limit:Int = 5):Array<SongPlayEntry>
  {
    final list:Array<SongPlayEntry> = [];
    for (entry in songPlays)
    {
      list.push({
        key: entry.key,
        name: entry.name,
        plays: entry.plays,
        mod: entry.mod,
        modName: entry.modName
      });
    }
    list.sort(compareSongEntries);
    if (limit > 0 && list.length > limit) return list.slice(0, limit);
    return list;
  }

  /**
   * Most-played mods ordered by play count descending, with alphabetical
   * tie-breaking.
   *
   * @param limit maximum number of entries to return (`<= 0` returns all).
   */
  public static function topMods(limit:Int = 5):Array<ModPlayEntry>
  {
    final list:Array<ModPlayEntry> = [];
    for (entry in modPlays)
    {
      list.push({
        key: entry.key,
        name: entry.name,
        plays: entry.plays
      });
    }
    list.sort(compareModEntries);
    if (limit > 0 && list.length > limit) return list.slice(0, limit);
    return list;
  }

  /** Builds an immutable snapshot of all current stats for UI rendering. */
  public static function snapshot(topLimit:Int = 10):PlayerStatsSnapshot
  {
    return {
      playtimeSeconds: playtimeSeconds,
      songsFinished: songsFinished,
      fullCombos: fullCombos,
      deaths: deaths,
      judgements: {
        perfects: perfects,
        sicks: sicks,
        goods: goods,
        bads: bads,
        poors: poors,
        misses: misses
      },
      topSongs: topSongs(topLimit),
      topMods: topMods(topLimit),
      uniqueSongs: uniqueSongsCount(),
      uniqueMods: uniqueModsCount()
    };
  }

  /** Serializes current stats to a plain anonymous object suitable for JSON. */
  public static function toSaveObject():Dynamic
  {
    final songsOut:Array<Dynamic> = [];
    for (entry in topSongs(0))
    {
      final item:Dynamic = {
        key: entry.key,
        name: entry.name,
        plays: entry.plays
      };
      if (entry.mod != null && entry.mod.length > 0) item.mod = entry.mod;
      if (entry.modName != null && entry.modName.length > 0) item.modName = entry.modName;
      songsOut.push(item);
    }

    final modsOut:Array<Dynamic> = [];
    for (entry in topMods(0))
    {
      modsOut.push({
        key: entry.key,
        name: entry.name,
        plays: entry.plays
      });
    }

    return {
      version: SCHEMA_VERSION,
      playtimeSeconds: playtimeSeconds,
      songsFinished: songsFinished,
      fullCombos: fullCombos,
      deaths: deaths,
      judgements: {
        perfects: perfects,
        sicks: sicks,
        goods: goods,
        bads: bads,
        poors: poors,
        misses: misses
      },
      songs: songsOut,
      mods: modsOut
    };
  }

  /** Serializes current stats to a compact JSON string. */
  public static function encodeJson():String
    return Json.stringify(toSaveObject());

  /**
   * Populates stats from a saved JSON string or plain anonymous object.
   *
   * Malformed or partially corrupt data degrades safely to zero for any
   * unreadable field rather than throwing.
   *
   * @param raw               saved payload (`String` JSON, plain object, or `null`).
   * @param seedPlaytimeHours legacy playtime in hours used only when `raw == null`.
   */
  public static function loadFromDynamic(raw:Dynamic, seedPlaytimeHours:Float = 0):Void
  {
    clearMemory();

    if (raw == null)
    {
      final seededHours:Float = (Math.isNaN(seedPlaytimeHours) || !Math.isFinite(seedPlaytimeHours) || seedPlaytimeHours < 0)
        ? 0
        : seedPlaytimeHours;
      playtimeSeconds = seededHours * 3600.0;
      return;
    }

    var data:Dynamic = raw;
    if (Std.isOfType(raw, String))
    {
      final text:String = cast raw;
      if (text.trim().length == 0) return;
      try
      {
        data = Json.parse(text);
      }
      catch (e:Dynamic)
      {
        return;
      }
    }

    if (data == null || !Reflect.isObject(data)) return;

    playtimeSeconds = readNonNegativeFloat(Reflect.field(data, 'playtimeSeconds'));
    songsFinished = readNonNegativeInt(Reflect.field(data, 'songsFinished'));
    fullCombos = readNonNegativeInt(Reflect.field(data, 'fullCombos'));
    deaths = readNonNegativeInt(Reflect.field(data, 'deaths'));

    final judgements:Dynamic = Reflect.field(data, 'judgements');
    if (judgements != null && Reflect.isObject(judgements))
    {
      perfects = readNonNegativeInt(Reflect.field(judgements, 'perfects'));
      sicks = readNonNegativeInt(Reflect.field(judgements, 'sicks'));
      goods = readNonNegativeInt(Reflect.field(judgements, 'goods'));
      bads = readNonNegativeInt(Reflect.field(judgements, 'bads'));
      poors = readNonNegativeInt(Reflect.field(judgements, 'poors'));
      misses = readNonNegativeInt(Reflect.field(judgements, 'misses'));
    }

    final rawSongs:Dynamic = Reflect.field(data, 'songs');
    if (rawSongs != null && Std.isOfType(rawSongs, Array))
    {
      final items:Array<Dynamic> = cast rawSongs;
      for (item in items)
      {
        if (item == null || !Reflect.isObject(item)) continue;
        final plays:Int = readNonNegativeInt(Reflect.field(item, 'plays'));
        if (plays <= 0) continue;
        final rawMod:String = readString(Reflect.field(item, 'mod')).trim();
        final rawModName:String = readString(Reflect.field(item, 'modName')).trim();
        final rawName:String = readString(Reflect.field(item, 'name')).trim();
        final rawKey:String = readString(Reflect.field(item, 'key')).trim();
        final resolvedKey:String = rawKey.length > 0 ? rawKey : normalizeSongKey(rawName);
        if (resolvedKey.length == 0) continue;
        final resolvedName:String = sanitizeLabel(rawName.length > 0 ? rawName : resolvedKey);
        final resolvedModName:String = rawMod.length > 0
          ? sanitizeLabel(rawModName.length > 0 ? rawModName : rawMod)
          : '';
        addSongPlay(resolvedKey, resolvedName, plays, rawMod, resolvedModName);
      }
    }

    final rawMods:Dynamic = Reflect.field(data, 'mods');
    if (rawMods != null && Std.isOfType(rawMods, Array))
    {
      final items:Array<Dynamic> = cast rawMods;
      for (item in items)
      {
        if (item == null || !Reflect.isObject(item)) continue;
        final plays:Int = readNonNegativeInt(Reflect.field(item, 'plays'));
        if (plays <= 0) continue;
        final rawKey:String = readString(Reflect.field(item, 'key')).trim();
        if (rawKey.length == 0) continue;
        final rawName:String = readString(Reflect.field(item, 'name')).trim();
        final resolvedName:String = sanitizeLabel(rawName.length > 0 ? rawName : rawKey);
        addModPlay(rawKey, resolvedName, plays);
      }
    }
  }

  /**
   * Formats a duration in seconds as `Xh YYm ZZs`, `Ym ZZs`, or `Zs`.
   *
   * Continues formatting cleanly well beyond 50 hours (e.g. `125h 04m 09s`).
   */
  public static function formatPlaytime(seconds:Float):String
  {
    if (Math.isNaN(seconds) || !Math.isFinite(seconds) || seconds <= 0) return '0s';

    final totalSeconds:Float = Math.floor(seconds);
    final hours:Float = Math.floor(totalSeconds / 3600.0);
    final remAfterHours:Float = totalSeconds - (hours * 3600.0);
    final minutes:Int = Math.floor(remAfterHours / 60.0);
    final secs:Int = Math.floor(remAfterHours - (minutes * 60.0));

    if (hours >= 1.0)
      return formatWholeFloat(hours) + 'h ' + padTwo(minutes) + 'm ' + padTwo(secs) + 's';
    if (minutes > 0)
      return minutes + 'm ' + padTwo(secs) + 's';
    return secs + 's';
  }

  /** Formats a non-negative integer with comma thousands separators. */
  public static function formatCount(value:Int):String
  {
    if (value < 0) return '-' + formatDigits(Std.string(-value));
    return formatDigits(Std.string(value));
  }

  /** Formats a percentage (`0..100`) with a fixed number of decimal places. */
  public static function formatPercent(percent:Float, decimals:Int = 1):String
  {
    final safe:Float = (Math.isNaN(percent) || !Math.isFinite(percent)) ? 0.0 : Math.min(100.0, Math.max(0.0, percent));
    if (decimals <= 0) return Std.string(Math.round(safe)) + '%';

    var scale:Float = 1.0;
    for (_ in 0...decimals) scale *= 10.0;
    final rounded:Int = Math.round(safe * scale);
    final scaleInt:Int = Std.int(scale);
    final whole:Int = Std.int(rounded / scaleInt);
    final frac:Int = rounded % scaleInt;
    var fracStr:String = Std.string(frac);
    while (fracStr.length < decimals) fracStr = '0' + fracStr;
    return whole + '.' + fracStr + '%';
  }

  /**
   * Normalizes a song title into a stable lookup slug (lowercase, spaces and
   * punctuation collapsed to hyphens, mirroring `Paths.formatToSongPath`).
   */
  public static function normalizeSongKey(songName:String):String
  {
    if (songName == null) return '';
    final trimmed:String = songName.trim();
    if (trimmed.length == 0) return '';

    final buf:StringBuf = new StringBuf();
    var lastWasDash:Bool = false;
    for (i in 0...trimmed.length)
    {
      final code:Int = trimmed.fastCodeAt(i);
      if (code <= 32 || code == '~'.code || code == '&'.code || code == '\\'.code || code == ';'.code
        || code == ':'.code || code == '<'.code || code == '>'.code || code == '#'.code || code == '/'.code)
      {
        if (!lastWasDash && buf.length > 0)
        {
          buf.addChar('-'.code);
          lastWasDash = true;
        }
      }
      else if (code == '.'.code || code == ','.code || code == '\''.code || code == '"'.code
        || code == '%'.code || code == '?'.code || code == '!'.code)
      {
        // Dropped to match Paths.formatToSongPath.
      }
      else if (code == '-'.code)
      {
        if (!lastWasDash && buf.length > 0)
        {
          buf.addChar('-'.code);
          lastWasDash = true;
        }
      }
      else
      {
        buf.addChar(code);
        lastWasDash = false;
      }
    }

    var result:String = buf.toString().toLowerCase();
    while (result.endsWith('-')) result = result.substr(0, result.length - 1);
    return result;
  }

  /**
   * Flattens an arbitrary song or mod name into one clean, length-bounded
   * single line so untrusted mod metadata cannot break the stats layout.
   */
  public static function sanitizeLabel(text:String, maxLength:Int = MAX_NAME_LENGTH):String
  {
    if (text == null) return '';
    final words:Array<String> = [];
    var wordStart:Int = -1;
    for (i in 0...text.length + 1)
    {
      final code:Null<Int> = i < text.length ? text.charCodeAt(i) : 32;
      if (code == null || code <= 32 || code == 127 || code == 0x85 || code == 0x2028 || code == 0x2029)
      {
        if (wordStart >= 0) words.push(text.substring(wordStart, i));
        wordStart = -1;
      }
      else if (wordStart < 0)
      {
        wordStart = i;
      }
    }

    final joined:String = words.join(' ');
    if (maxLength <= 0 || joined.length <= maxLength) return joined;
    if (maxLength <= 3) return joined.substr(0, maxLength);
    return joined.substr(0, maxLength - 3).trim() + '...';
  }

  /**
   * Builds a plain-text ASCII summary of current lifetime stats (suitable for
   * clipboard export or logging).
   */
  public static function buildSummaryText(topLimit:Int = 5):String
  {
    final snap:PlayerStatsSnapshot = snapshot(topLimit);
    final totalNotes:Int = totalJudgedNotes();
    final lines:Array<String> = [
      'Phoenix Engine - Player Stats',
      '',
      '[OVERVIEW]',
      'Playtime:       ' + formatPlaytime(snap.playtimeSeconds),
      'Songs Finished: ' + formatCount(snap.songsFinished) + ' (' + formatCount(snap.uniqueSongs) + ' unique)',
      'Full Combos:    ' + formatCount(snap.fullCombos) + (snap.songsFinished > 0 ? ' (' + formatPercent(fullComboRatePercent(), 1) + ')' : ''),
      'Deaths:         ' + formatCount(snap.deaths),
      '',
      '[NOTES PER JUDGEMENT]',
      'Total Judged:   ' + formatCount(totalNotes) + (totalNotes > 0 ? ' (Accuracy ' + formatPercent(weightedAccuracyPercent(), 2) + ')' : ''),
      'Perfect:        ' + formatJudgementLine(snap.judgements.perfects, totalNotes),
      'Sick:           ' + formatJudgementLine(snap.judgements.sicks, totalNotes),
      'Good:           ' + formatJudgementLine(snap.judgements.goods, totalNotes),
      'Bad:            ' + formatJudgementLine(snap.judgements.bads, totalNotes),
      'Poor:           ' + formatJudgementLine(snap.judgements.poors, totalNotes),
      'Miss:           ' + formatJudgementLine(snap.judgements.misses, totalNotes),
      '',
      '[MOST-PLAYED SONGS]'
    ];

    if (snap.topSongs.length == 0)
    {
      lines.push('None yet');
    }
    else
    {
      for (i in 0...snap.topSongs.length)
      {
        final song:SongPlayEntry = snap.topSongs[i];
        final modTag:String = (song.modName != null && song.modName.length > 0) ? ' [' + song.modName + ']' : '';
        final unit:String = song.plays == 1 ? ' play' : ' plays';
        lines.push('#' + (i + 1) + ' ' + song.name + modTag + ' - ' + formatCount(song.plays) + unit);
      }
    }

    lines.push('');
    lines.push('[MOST-PLAYED MODS]');
    if (snap.topMods.length == 0)
    {
      lines.push('None yet');
    }
    else
    {
      for (i in 0...snap.topMods.length)
      {
        final mod:ModPlayEntry = snap.topMods[i];
        final unit:String = mod.plays == 1 ? ' play' : ' plays';
        lines.push('#' + (i + 1) + ' ' + mod.name + ' - ' + formatCount(mod.plays) + unit);
      }
    }

    return lines.join('\n');
  }

  // -- Internal helpers ------------------------------------------------------

  static function clearMemory():Void
  {
    playtimeSeconds = 0;
    songsFinished = 0;
    fullCombos = 0;
    deaths = 0;
    perfects = 0;
    sicks = 0;
    goods = 0;
    bads = 0;
    poors = 0;
    misses = 0;
    songPlays = new Map<String, SongPlayEntry>();
    modPlays = new Map<String, ModPlayEntry>();
    dirty = false;
  }

  static function readLegacyPlaytimeHours():Float
  {
    #if ACHIEVEMENTS_ALLOWED
    try
    {
      if (Achievements.isUnlocked(PLAYTIME_ACHIEVEMENT_ID))
        return PLAYTIME_ACHIEVEMENT_HOURS;
      if (Achievements.exists(PLAYTIME_ACHIEVEMENT_ID))
      {
        final score:Float = Achievements.getScore(PLAYTIME_ACHIEVEMENT_ID);
        if (!Math.isNaN(score) && Math.isFinite(score) && score > 0) return score;
      }
    }
    catch (e:Dynamic) {}
    #end
    return 0;
  }

  static function addSongPlay(key:String, name:String, count:Int, mod:String, modName:String):Void
  {
    final existing:Null<SongPlayEntry> = songPlays.get(key);
    if (existing != null)
    {
      existing.plays = safeAddInt(existing.plays, count);
      if (isBetterDisplayName(existing.name, name)) existing.name = name;
      if (mod.length > 0 && (existing.mod == null || existing.mod.length == 0)) existing.mod = mod;
      if (modName.length > 0 && (existing.modName == null || existing.modName.length == 0 || existing.modName == existing.mod))
        existing.modName = modName;
      return;
    }

    songPlays.set(key, {
      key: key,
      name: name,
      plays: count,
      mod: mod,
      modName: modName
    });
  }

  static function addModPlay(key:String, name:String, count:Int):Void
  {
    final existing:Null<ModPlayEntry> = modPlays.get(key);
    if (existing != null)
    {
      existing.plays = safeAddInt(existing.plays, count);
      if (name.length > 0 && (existing.name == existing.key || isBetterDisplayName(existing.name, name)))
        existing.name = name;
      return;
    }

    modPlays.set(key, {
      key: key,
      name: name.length > 0 ? name : key,
      plays: count
    });
  }

  static function isBetterDisplayName(current:String, candidate:String):Bool
  {
    if (candidate == null || candidate.length == 0) return false;
    if (current == null || current.length == 0) return true;
    final currentPlain:Bool = (current == current.toLowerCase() && current.indexOf(' ') < 0);
    final candidateFormatted:Bool = (candidate != candidate.toLowerCase() || candidate.indexOf(' ') >= 0);
    return currentPlain && candidateFormatted;
  }

  static function compareSongEntries(a:SongPlayEntry, b:SongPlayEntry):Int
  {
    if (a.plays != b.plays) return (b.plays > a.plays) ? 1 : -1;
    final cmpName:Int = compareStrings(a.name.toLowerCase(), b.name.toLowerCase());
    if (cmpName != 0) return cmpName;
    return compareStrings(a.key, b.key);
  }

  static function compareModEntries(a:ModPlayEntry, b:ModPlayEntry):Int
  {
    if (a.plays != b.plays) return (b.plays > a.plays) ? 1 : -1;
    final cmpName:Int = compareStrings(a.name.toLowerCase(), b.name.toLowerCase());
    if (cmpName != 0) return cmpName;
    return compareStrings(a.key, b.key);
  }

  static inline function compareStrings(a:String, b:String):Int
    return (a < b) ? -1 : ((a > b) ? 1 : 0);

  static inline function safeAddInt(current:Int, delta:Int):Int
  {
    if (delta <= 0) return current;
    return (current >= MAX_INT - delta) ? MAX_INT : current + delta;
  }

  static function readNonNegativeFloat(raw:Dynamic):Float
  {
    if (raw == null || Std.isOfType(raw, Bool)) return 0;
    if (Std.isOfType(raw, Float))
    {
      final value:Float = raw;
      return (Math.isNaN(value) || !Math.isFinite(value) || value < 0) ? 0 : value;
    }
    return 0;
  }

  static function readNonNegativeInt(raw:Dynamic):Int
  {
    final value:Float = readNonNegativeFloat(raw);
    if (value <= 0) return 0;
    if (value >= MAX_INT) return MAX_INT;
    return Math.floor(value);
  }

  static function readString(raw:Dynamic):String
  {
    if (raw == null || !Std.isOfType(raw, String)) return '';
    return cast raw;
  }

  static function formatJudgementLine(count:Int, total:Int):String
  {
    if (total <= 0) return formatCount(count);
    final pct:Float = (count / total) * 100.0;
    return formatCount(count) + ' (' + formatPercent(pct, 1) + ')';
  }

  static function padTwo(value:Int):String
    return value < 10 ? ('0' + value) : Std.string(value);

  static function formatWholeFloat(value:Float):String
  {
    if (value <= 0) return '0';
    if (value <= MAX_INT) return formatCount(Math.floor(value));
    // Fallback for extreme multi-million-hour values.
    return formatDigits(Std.string(Math.floor(value)));
  }

  static function formatDigits(digits:String):String
  {
    if (digits.length <= 3) return digits;
    final out:StringBuf = new StringBuf();
    final rem:Int = digits.length % 3;
    for (i in 0...digits.length)
    {
      if (i > 0 && ((i - rem) % 3 == 0)) out.addChar(','.code);
      out.addChar(digits.fastCodeAt(i));
    }
    return out.toString();
  }
}
