package backend;

using StringTools;

/*
 * Phoenix Engine memory profiles — the data behind
 * Options -> Optimization -> "Memory Profile".
 *
 * A profile is a *bundle*: a handful of appearance/performance preferences
 * that only make sense together (drop the splash sprites, drop the moving
 * menu backdrop, stop caching stage detail, ...) plus a runtime cleanup
 * policy (when to hand freed images and sounds back to the OS). Codename
 * Engine ships the same idea as a single "Low Memory Mode" switch under
 * Options > Appearance; Phoenix keeps the switch but also lets a player pick
 * how far it goes.
 *
 * Two rules keep this file honest:
 *
 *  1. It is pure data: no Flixel/OpenFL/Lime imports, no file or prefs I/O.
 *     `backend.LowMemory` does the applying, this file only *describes*.
 *     That is why `tests/haxe/MemoryProfilesSpec.hx` can exercise it in the
 *     Haxe interpreter with no stubs at all.
 *  2. Every key in an `overrides` map must be a real `ClientPrefs` field.
 *     `tests/haxe/run-memory-profiles.sh` checks that against
 *     `source/backend/ClientPrefs.hx`, so a renamed preference cannot leave a
 *     profile silently doing nothing.
 *
 * The player's own values are never destroyed: `LowMemory` snapshots them
 * before applying a profile (see `encodeBaseline`) and restores them the
 * moment the profile is turned off or the settings file is saved.
 */

/** What a profile does at runtime, on top of the preference overrides. */
typedef MemoryPolicy =
{
  /** Release unused cached assets when a song finishes (`Paths.clearUnusedMemory`). */
  var trimOnSongEnd:Bool;

  /** Release *all* cached assets once PlayState is torn down (`Paths.clearStoredMemory`). */
  var releaseOnPlayStateExit:Bool;

  /** Release unused cached assets when the window/app loses focus. */
  var trimOnFocusLost:Bool;

  /** Seconds between trims in a non-gameplay state, 0 = never. */
  var idleTrimSeconds:Float;

  /** Avoid speculative song assets on the loading screen; load on demand instead. */
  var skipSongPreload:Bool;

  /** Try streaming native Vorbis song stems instead of decoding them into RAM. */
  var streamSongAudio:Bool;

  /** Compact the heap on every trim, even if the asset cache freed nothing. */
  var compactOnTrim:Bool;

  /** Force an explicit full mark-and-sweep GC and drop dynamic font pages on every trim. */
  var majorGcOnTrim:Bool;

  /** Allow unused menu and pause themes in `Paths.dumpExclusions` to be evicted when silent. */
  var evictPinnedAudio:Bool;

  /** Strip heavy menu/title atlases, Freeplay icons/disc, Options character preview and fades. */
  var minimalMenus:Bool;

  /** Skip silent gameplay SFX/font warm-ups, countdown sprites, credit popups and intro tweens. */
  var minimalGameplayPrecache:Bool;
};

/** One profile: what the option shows, what it forces and what it cleans up. */
typedef MemoryProfile =
{
  /** Stable id, also the value stored in `ClientPrefs.memoryProfile`. */
  var id:String;

  /** Human name for menus and the diagnostics page. */
  var title:String;

  /** Description shown under the option in Options -> Optimization. */
  var description:String;

  /** `ClientPrefs` field -> forced value. Treat as read-only. */
  var overrides:Map<String, Dynamic>;

  var policy:MemoryPolicy;
};

/**
 * A player's own values for the preferences a profile manages, serialized
 * into `ClientPrefs.memoryProfileBaseline` so they survive a restart.
 */
typedef StoredBaseline =
{
  /** Profile these values belong to; a mismatch means "recapture". */
  var profile:String;

  var values:Map<String, Dynamic>;
};

class MemoryProfiles
{
  /** No profile: every preference behaves exactly as the player set it. */
  public static inline var OFF:String = 'Off';

  /** CNE-style low memory mode: the cheap wins, nothing gameplay-facing. */
  public static inline var LOW:String = 'Low';

  /** For devices that are already struggling: also drops detail and shaders. */
  public static inline var EXTREME:String = 'Extreme';

  /** Opt-in, compatibility-sacrificing mode for the smallest practical RAM footprint. */
  public static inline var EXPERIMENTAL:String = 'Experimental Extreme';

  /** Joke-named ATmega328P (2 KB SRAM @ 16 MHz) ultra-stripped mode beyond Experimental Extreme. */
  public static inline var ARDUINO_NANO_R3:String = 'Arduino Nano R3';

  /** Values offered by the Options menu, in display order. */
  public static final NAMES:Array<String> = [OFF, LOW, EXTREME, EXPERIMENTAL, ARDUINO_NANO_R3];

  /**
   * Spellings accepted from old saves, settings backups and scripts, so
   * `"low memory"`, `"LOW"` and `"low"` all resolve to the same profile.
   */
  static final ALIASES:Map<String, String> = [
    'none' => OFF,
    'disabled' => OFF,
    'no' => OFF,
    'low memory' => LOW,
    'lowmemory' => LOW,
    'light' => LOW,
    'on' => LOW,
    'aggressive' => EXTREME,
    'high' => EXTREME,
    'max' => EXTREME,
    'experimental' => EXPERIMENTAL,
    'experimentalextreme' => EXPERIMENTAL,
    'extreme experimental' => EXPERIMENTAL,
    'extremeexperimental' => EXPERIMENTAL,
    'insane' => EXPERIMENTAL,
    'minimum' => EXPERIMENTAL,
    'arduino' => ARDUINO_NANO_R3,
    'arduino nano' => ARDUINO_NANO_R3,
    'arduinonano' => ARDUINO_NANO_R3,
    'arduinonanor3' => ARDUINO_NANO_R3,
    'nano' => ARDUINO_NANO_R3,
    'nano r3' => ARDUINO_NANO_R3,
    'nanor3' => ARDUINO_NANO_R3,
    'atmega328p' => ARDUINO_NANO_R3,
    'atmega' => ARDUINO_NANO_R3,
    '2kb' => ARDUINO_NANO_R3
  ];

  /**
   * Managed `ClientPrefs` fields whose static type is `Float`.
   *
   * Boxed whole numbers (`0.0`, `1.0`) satisfy `Std.isOfType(x, Int)` in Haxe,
   * so `coerceField` consults this set instead of truncating fractional player
   * values (`0.4`, `0.85`) when restoring after a `0` override.
   */
  static final FLOAT_FIELDS:Map<String, Bool> = [
    'flashIntensity' => true,
    'cameraFxIntensity' => true,
    'stageDim' => true,
    'laneUnderlayAlpha' => true,
    'hitsoundVolume' => true
  ];

  /** Profiles are immutable, so one instance per id is cached on first use. */
  static var cache:Map<String, MemoryProfile> = null;

  // -- Lookup ----------------------------------------------------------------

  /**
   * Canonical id for any accepted spelling.
   *
   * Never throws: `null`, blank text and unknown words all resolve to `Off`,
   * because a corrupt save must not lock a player out of their settings.
   */
  public static function normalize(value:String):String
  {
    if (value == null) return OFF;
    final text:String = value.trim().toLowerCase();
    if (text.length == 0) return OFF;

    for (name in NAMES)
      if (name.toLowerCase() == text) return name;

    final alias:Null<String> = ALIASES.get(text);
    return alias != null ? alias : OFF;
  }

  /** The full profile for any accepted spelling (never `null`). */
  public static function get(value:String):MemoryProfile
  {
    final id:String = normalize(value);
    if (cache == null) cache = new Map<String, MemoryProfile>();

    var profile:MemoryProfile = cache.get(id);
    if (profile == null)
    {
      profile = build(id);
      cache.set(id, profile);
    }
    return profile;
  }

  /** Copy of the overrides for a profile; the returned map is safe to mutate. */
  public static function overrides(value:String):Map<String, Dynamic>
  {
    final copy:Map<String, Dynamic> = new Map<String, Dynamic>();
    for (field => forced in get(value).overrides)
      copy.set(field, forced);
    return copy;
  }

  /** Runtime cleanup policy for a profile. */
  public static function policy(value:String):MemoryPolicy
    return get(value).policy;

  /** Description used by the Options menu. */
  public static function describe(value:String):String
    return get(value).description;

  /** True when the spelling resolves to `Off`. */
  public static function isOff(value:String):Bool
    return normalize(value) == OFF;

  /** Every `ClientPrefs` field any profile can force, sorted, for docs/tests. */
  public static function managedKeys():Array<String>
  {
    final keys:Array<String> = [];
    for (name in NAMES)
    {
      for (field in get(name).overrides.keys())
        if (keys.indexOf(field) == -1) keys.push(field);
    }
    keys.sort((a, b) -> a < b ? -1 : (a > b ? 1 : 0));
    return keys;
  }

  /**
   * One-line summary for the diagnostics page and the vlog, e.g.
   * `Extreme (8 overrides, releases after songs, idle trim 20s)`.
   */
  public static function summary(value:String):String
  {
    final profile:MemoryProfile = get(value);
    if (profile.id == OFF) return OFF;

    final count:Int = countOverrides(profile.overrides);
    final parts:Array<String> = [count + ' override' + plural(count)];

    if (profile.policy.releaseOnPlayStateExit) parts.push('releases after songs');
    else if (profile.policy.trimOnSongEnd) parts.push('trims after songs');
    if (profile.policy.trimOnFocusLost) parts.push('trims on focus loss');
    if (profile.policy.idleTrimSeconds > 0) parts.push('idle trim ' + profile.policy.idleTrimSeconds + 's');
    if (profile.policy.skipSongPreload) parts.push('no song preloads');
    if (profile.policy.streamSongAudio) parts.push('streams supported song audio');
    if (profile.policy.compactOnTrim) parts.push('compacts on trim');
    if (profile.policy.majorGcOnTrim) parts.push('major GC on trim');
    if (profile.policy.evictPinnedAudio) parts.push('evicts pinned audio');
    if (profile.policy.minimalMenus) parts.push('minimal menus');
    if (profile.policy.minimalGameplayPrecache) parts.push('minimal song precache');

    return profile.title + ' (' + parts.join(', ') + ')';
  }

  // -- Baseline codec --------------------------------------------------------

  /**
   * Serializes a player's own values for the fields `profile` manages.
   *
   * The profile id travels with the values so a later run can tell whether
   * the snapshot still belongs to the selected profile. Only primitives are
   * stored (every managed preference is a Bool/Int/Float/String).
   */
  public static function encodeBaseline(profile:String, values:Map<String, Dynamic>):String
  {
    final data:Dynamic = {};
    if (values != null)
    {
      for (field => value in values)
      {
        if (field == null || value == null) continue;
        Reflect.setField(data, field, value);
      }
    }
    return haxe.Json.stringify({profile: normalize(profile), values: data});
  }

  /**
   * Parses a baseline written by `encodeBaseline`.
   *
   * Returns `null` for anything unusable (blank, truncated, not JSON, no
   * values) and silently drops entries that are not primitives, so a
   * hand-edited save can never inject a weird object into `ClientPrefs`.
   */
  public static function decodeBaseline(raw:String):StoredBaseline
  {
    if (raw == null) return null;
    final text:String = raw.trim();
    if (text.length < 2) return null;

    var parsed:Dynamic = null;
    try
    {
      parsed = haxe.Json.parse(text);
    }
    catch (_:Dynamic)
    {
      return null;
    }
    if (!isObject(parsed)) return null;

    final stored:Dynamic = Reflect.field(parsed, 'values');
    if (!isObject(stored)) return null;

    final values:Map<String, Dynamic> = new Map<String, Dynamic>();
    for (name in Reflect.fields(stored))
    {
      final value:Dynamic = Reflect.field(stored, name);
      if (value == null) continue;
      if (!isPrimitive(value)) continue;
      values.set(name, value);
    }
    if (countOverrides(values) == 0) return null;

    final profile:Dynamic = Reflect.field(parsed, 'profile');
    return {profile: normalize(profile == null ? OFF : Std.string(profile)), values: values};
  }

  /**
   * Converts `value` to the type of `current` (the live preference).
   *
   * JSON has no Int/Float distinction and backups can be hand-edited, so
   * `maxSplashLimit` must stay an `Int` and a `Bool` must never arrive as the
   * string `"false"` (which is truthy in Haxe). Anything unconvertible keeps
   * the current value instead of poisoning the preference.
   */
  public static function coerce(current:Dynamic, value:Dynamic):Dynamic
  {
    if (value == null) return current;
    if (current == null) return value;

    if (Std.isOfType(current, Bool))
    {
      if (value is Bool) return value;
      if (value is Int || value is Float) return (value != 0);
      if (value is String)
      {
        final str:String = value;
        final text:String = str.trim().toLowerCase();
        return text == 'true' || text == '1';
      }
      return current;
    }
    if (Std.isOfType(current, Int))
    {
      if (value is Int) return value;
      if (value is Float)
      {
        final number:Float = value;
        return (Math.isNaN(number) || !Math.isFinite(number)) ? current : Std.int(number);
      }
      if (value is Bool) return value ? 1 : 0;
      if (value is String)
      {
        final str:String = value;
        final parsed:Null<Int> = Std.parseInt(str.trim());
        return parsed != null ? parsed : current;
      }
      return current;
    }
    if (Std.isOfType(current, Float)) return coerceFloat(current, value);
    if (Std.isOfType(current, String)) return Std.string(value);

    return value;
  }

  /**
   * Field-aware wrapper around `coerce` that preserves fractional `Float`
   * preferences even when `current` currently holds a whole number (`0` / `1`).
   *
   * @param field `ClientPrefs` field name.
   * @param current Live value read from `ClientPrefs`.
   * @param value Candidate value from an override or saved baseline.
   * @return Type-safe coerced value ready to assign back onto `ClientPrefs`.
   */
  public static function coerceField(field:String, current:Dynamic, value:Dynamic):Dynamic
  {
    if (value == null) return current;
    if (current == null) return value;
    if (field != null && FLOAT_FIELDS.exists(field)) return coerceFloat(current, value);
    return coerce(current, value);
  }

  /**
   * Converts `value` to a finite `Float`, falling back to `current` when invalid.
   *
   * @param current Fallback numeric value.
   * @param value Candidate value to convert.
   * @return Finite `Float` value.
   */
  static function coerceFloat(current:Dynamic, value:Dynamic):Dynamic
  {
    if (value is Int || value is Float)
    {
      final number:Float = value + 0.0;
      return (Math.isNaN(number) || !Math.isFinite(number)) ? current : number;
    }
    if (value is String)
    {
      final str:String = value;
      final parsed:Float = Std.parseFloat(str.trim());
      return (Math.isNaN(parsed) || !Math.isFinite(parsed)) ? current : parsed;
    }
    return current;
  }

  /** JSON objects are the only shape a baseline's `values` may have. */
  static function isObject(value:Dynamic):Bool
  {
    if (value == null || Std.isOfType(value, Array)) return false;
    if (value is Bool || value is Int || value is Float || value is String) return false;
    return Reflect.isObject(value);
  }

  static function isPrimitive(value:Dynamic):Bool
  {
    return value is Bool || value is Int || value is Float || value is String;
  }

  // -- Profile definitions ---------------------------------------------------

  /**
   * Constructs the immutable definition for a canonical profile id.
   *
   * @param id Canonical profile id (`OFF`, `LOW`, `EXTREME`, `EXPERIMENTAL`, `ARDUINO_NANO_R3`).
   * @return Profile definition with preference overrides and runtime cleanup policy.
   */
  static function build(id:String):MemoryProfile
  {
    if (id == LOW)
    {
      return {
        id: LOW,
        title: 'Low',
        description: 'Low memory mode, in the spirit of Codename Engine\'s option:\n'
          + 'fewer note splash sprites, no moving menu checkerboard, unused\n'
          + 'assets freed after every song and during idle menus.\n'
          + 'The preferences it manages are forced while it is on.',
        overrides: lowOverrides(),
        policy: {
          trimOnSongEnd: true,
          releaseOnPlayStateExit: false,
          trimOnFocusLost: true,
          idleTrimSeconds: 45,
          skipSongPreload: false,
          streamSongAudio: false,
          compactOnTrim: false,
          majorGcOnTrim: false,
          evictPinnedAudio: false,
          minimalMenus: false,
          minimalGameplayPrecache: false
        }
      };
    }

    if (id == EXTREME)
    {
      return {
        id: EXTREME,
        title: 'Extreme',
        description: 'For devices already short on RAM:\n'
          + 'Low Quality stages, no note splashes, shaders or anti-aliasing,\n'
          + 'no camera bop zooms, no moving checkerboard, and every cached\n'
          + 'asset is released after a song or when the app loses focus.\n'
          + 'The preferences it manages are forced while it is on.',
        overrides: extremeOverrides(),
        policy: {
          trimOnSongEnd: true,
          releaseOnPlayStateExit: true,
          trimOnFocusLost: true,
          idleTrimSeconds: 20,
          skipSongPreload: false,
          streamSongAudio: false,
          compactOnTrim: false,
          majorGcOnTrim: false,
          evictPinnedAudio: false,
          minimalMenus: false,
          minimalGameplayPrecache: false
        }
      };
    }

    if (id == EXPERIMENTAL)
    {
      return {
        id: EXPERIMENTAL,
        title: EXPERIMENTAL,
        description: 'EXPERIMENTAL / UNSAFE: removes stages, characters and HUD effects.\n'
          + 'Mods may break; graphics can glitch or disappear. Streaming and\n'
          + 'skipping preloads can cause slow loads, stutters or audio hiccups.\n'
          + 'GPU caching needs a compatible context and may increase VRAM use.\n'
          + 'Choosing a lower profile or Off restores your managed preferences.',
        overrides: experimentalOverrides(),
        policy: {
          trimOnSongEnd: true,
          releaseOnPlayStateExit: true,
          trimOnFocusLost: true,
          idleTrimSeconds: 5,
          skipSongPreload: true,
          streamSongAudio: true,
          compactOnTrim: true,
          majorGcOnTrim: false,
          evictPinnedAudio: false,
          minimalMenus: false,
          minimalGameplayPrecache: false
        }
      };
    }

    if (id == ARDUINO_NANO_R3)
    {
      return {
        id: ARDUINO_NANO_R3,
        title: ARDUINO_NANO_R3,
        description: 'ABSURD / 2 KB SRAM EDITION: tuned for an imaginary 16 MHz ATmega328P.\n'
          + 'Everything Experimental Extreme cuts, plus hidden HUD, no extra vocal stems,\n'
          + 'no pause music, 15 FPS menus (1 FPS unfocused), stripped menu/countdown art,\n'
          + 'disabled note script hooks, and 1s major-GC + heap compaction trims.\n'
          + 'Pure arrows in a void. Pick Off or a lower tier to get your game back.',
        overrides: arduinoNanoOverrides(),
        policy: {
          trimOnSongEnd: true,
          releaseOnPlayStateExit: true,
          trimOnFocusLost: true,
          idleTrimSeconds: 1,
          skipSongPreload: true,
          streamSongAudio: true,
          compactOnTrim: true,
          majorGcOnTrim: true,
          evictPinnedAudio: true,
          minimalMenus: true,
          minimalGameplayPrecache: true
        }
      };
    }

    return {
      id: OFF,
      title: 'Off',
      description: 'No memory profile is applied: every option below stays\n'
        + 'at your chosen value and nothing is trimmed automatically.\n'
        + 'Cycle through Low, Extreme, Experimental Extreme, or the\n'
        + 'absurd Arduino Nano R3 tier to trade presentation for RAM.',
      overrides: new Map<String, Dynamic>(),
      policy: {
        trimOnSongEnd: false,
        releaseOnPlayStateExit: false,
        trimOnFocusLost: false,
        idleTrimSeconds: 0,
        skipSongPreload: false,
        streamSongAudio: false,
        compactOnTrim: false,
        majorGcOnTrim: false,
        evictPinnedAudio: false,
        minimalMenus: false,
        minimalGameplayPrecache: false
      }
    };
  }

  /**
   * The cheap wins. None of these change how a chart is played: splashes and
   * the menu backdrop are pure decoration, and the hard cap only limits how
   * many splash sprites can be alive at once.
   */
  static function lowOverrides():Map<String, Dynamic>
  {
    final forced:Map<String, Dynamic> = new Map<String, Dynamic>();
    forced.set('maxSplashLimit', 4);
    forced.set('movingMenuCheckerboard', false);
    return forced;
  }

  /**
   * Adds the appearance/performance knobs that actually free textures:
   * `lowQuality` skips the per-stage detail sprites, splashes/shaders/AA stop
   * allocating extra bitmaps, and the camera bop avoids re-scaling HUD work.
   */
  static function extremeOverrides():Map<String, Dynamic>
  {
    final forced:Map<String, Dynamic> = new Map<String, Dynamic>();
    forced.set('lowQuality', true);
    forced.set('noteSplashes', false);
    forced.set('oppNoteSplashes', false);
    forced.set('maxSplashLimit', 0);
    forced.set('shaders', false);
    forced.set('globalAntialiasing', false);
    forced.set('camZooms', false);
    forced.set('movingMenuCheckerboard', false);
    return forced;
  }

  /**
   * Deliberately sacrifices presentation and compatibility for RAM. Reuse
   * Extreme's map so new Extreme overrides cannot accidentally be dropped.
   * No input, scroll, note-speed or timing preferences are changed.
   */
  static function experimentalOverrides():Map<String, Dynamic>
  {
    final forced:Map<String, Dynamic> = extremeOverrides();
    forced.set('charsAndBG', false);
    forced.set('enableGC', true);
    forced.set('cacheOnGPU', true);
    forced.set('preloadNextSong', false);
    forced.set('enableColorShader', false);
    forced.set('distantNotes', false);
    forced.set('alphabetAntialiasing', false);
    forced.set('simplePopups', true);
    forced.set('ratingPopups', false);
    forced.set('comboPopups', false);
    forced.set('showMS', false);
    forced.set('earlyLateRatings', false);
    forced.set('scoreZoom', false);
    forced.set('showNPS', false);
    forced.set('showComboInfo', false);
    forced.set('showRendered', false);
    forced.set('opponentLightStrum', false);
    forced.set('botLightStrum', false);
    forced.set('playerLightStrum', false);
    forced.set('showFPS', false);
    forced.set('showRamUsage', false);
    forced.set('showMaxRamUsage', false);
    forced.set('showRamGraph', false);
    forced.set('debugInfo', false);
    forced.set('frameProfiler', false);
    forced.set('tipTexts', false);
    forced.set('platformWatermark', false);
    forced.set('discordRPC', false);
    return forced;
  }

  /**
   * Comically extreme ATmega328P tier: starts from `experimentalOverrides()` so
   * every Experimental Extreme win is guaranteed, then strips all remaining HUD
   * furniture, extra vocal/pause audio stems, decorative animations, per-note
   * script callbacks, dynamic CPU font glyph pages (`alphabetStyle = 'Image'`),
   * and caps menu/unfocused refresh rates to 15 FPS / 1 FPS while leaving core
   * chart playability (scroll, note speed, gameplay FPS, hit windows) intact.
   *
   * @return Preference map forced while `Arduino Nano R3` is active.
   */
  static function arduinoNanoOverrides():Map<String, Dynamic>
  {
    final forced:Map<String, Dynamic> = experimentalOverrides();
    // HUD & gameplay chrome stripped down to bare strum receptors and notes
    forced.set('hideHud', true);
    forced.set('timeBarType', 'Disabled');
    forced.set('watermarkStyle', 'Hide');
    forced.set('botTxtStyle', 'Hide');
    forced.set('botWatermark', false);
    forced.set('botTxtFade', false);
    forced.set('smoothHealth', false);
    forced.set('iconBounceType', 'None');
    forced.set('missRating', false);
    forced.set('doidoMisses', false);
    forced.set('comboStacking', false);
    forced.set('laneGlyphs', false);
    forced.set('visualBeatIndicator', false);
    // Screen effects, overlays, trails & per-note tinting off
    forced.set('flashing', false);
    forced.set('flashIntensity', 0);
    forced.set('reducedMotion', true);
    forced.set('cameraFxIntensity', 0);
    forced.set('stageDim', 0);
    forced.set('laneUnderlayAlpha', 0);
    forced.set('highContrast', false);
    forced.set('tauntOnGo', false);
    forced.set('ghostTapAnim', false);
    forced.set('spaceVPose', false);
    forced.set('crossFadeMode', 'Off');
    forced.set('noteColorStyle', 'Normal');
    // Extra audio buffers, SFX & haptics cut
    forced.set('extraVocals', false);
    forced.set('pauseMusic', 'None');
    forced.set('menuMusicFade', false);
    forced.set('missSoundEnabled', false);
    forced.set('hitsoundVolume', 0);
    forced.set('metronome', 'Off');
    forced.set('hapticFeedback', 'Off');
    // Script & frame overhead minimized
    forced.set('adaptivePerformance', true);
    forced.set('lessBotLag', true);
    forced.set('noSpawnFunc', true);
    forced.set('noHitFuncs', true);
    forced.set('noSkipFuncs', true);
    forced.set('menuFramerate', 15);
    forced.set('focusLostFramerate', 1);
    // Overlays, dynamic font glyph pages & background tasks disabled
    forced.set('showCommitWatermark', false);
    forced.set('show1PercentLows', false);
    forced.set('legacyFPSUI', false);
    forced.set('rainbowFPS', false);
    forced.set('loadingPieDial', false);
    forced.set('alphabetStyle', 'Image');
    forced.set('instantDialogueAdvance', true);
    forced.set('dimDialogueBackground', false);
    forced.set('hideDialogueBox', true);
    forced.set('debugPointingCursor', false);
    forced.set('screensaver', false);
    forced.set('androidNotifications', false);
    forced.set('checkForUpdates', false);
    return forced;
  }

  // -- Small helpers ---------------------------------------------------------

  static function countOverrides(values:Map<String, Dynamic>):Int
  {
    var count:Int = 0;
    for (field in values.keys())
    {
      if (field != null) count++;
    }
    return count;
  }

  /** `1 override` vs `2 overrides` without pulling in a plural helper. */
  static function plural(count:Int):String
    return count == 1 ? '' : 's';
}
