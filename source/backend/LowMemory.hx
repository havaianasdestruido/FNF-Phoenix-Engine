package backend;

import backend.ClientPrefs;
import backend.MemoryProfiles;
import backend.MemoryProfiles.MemoryPolicy;
import backend.MemoryProfiles.StoredBaseline;
import backend.Paths;
import flixel.FlxG;
import flixel.FlxSprite;

/**
 * Applies a memory profile and drives its cleanup policy.
 *
 * `backend.MemoryProfiles` only describes the profiles; this is the part that
 * touches `ClientPrefs`, `Paths` and Flixel. It exists because a profile has
 * to be a *temporary* bundle: the player's own values must come back the
 * moment the profile is turned off, and saving the settings file must never
 * bake a forced value in as if the player had chosen it.
 *
 * How the override layer works:
 *
 *  1. Turning a profile on snapshots the player's current values for the
 *     preferences the profile manages, into `ClientPrefs.memoryProfileBaseline`
 *     (`MemoryProfiles.encodeBaseline`), then forces the profile's values.
 *  2. `beginSave()` puts the snapshot back before `ClientPrefs.saveSettings()`
 *     iterates the fields, so the save file keeps what the player chose;
 *     `endSave()` re-applies the profile afterwards.
 *  3. Turning the profile off restores the snapshot and forgets it.
 *
 * The cleanup side is deliberately conservative: everything here goes through
 * the same `Paths.clearUnusedMemory` / `Paths.clearStoredMemory` calls the
 * menus already make, only at more points in the session, and always guarded —
 * a cleanup routine must never be the reason a song crashes.
 */
class LowMemory
{
  /** Minimum seconds between two signal-driven trims (focus loss, ...). */
  static inline final SIGNAL_TRIM_COOLDOWN:Float = 1.0;

  /** Set while `ClientPrefs.saveSettings()` is writing the player's values. */
  static var restoringForSave:Bool = false;

  /** Seconds accumulated since the last idle trim. */
  static var idleSeconds:Float = 0;

  /** `haxe.Timer.stamp()` of the last trim, for cooldowns and the vlog. */
  static var lastTrimAt:Float = -1000;

  /** Profile that is currently forced into `ClientPrefs`. */
  static var appliedProfile:String = MemoryProfiles.OFF;

  /** Last raw `ClientPrefs.memoryProfile` value the policy cache was built from. */
  static var cachedRawProfile:String = null;

  /** Cached policy, so `update()` does no string work per frame. */
  static var cachedPolicy:MemoryPolicy = null;

  // -- State -----------------------------------------------------------------

  /** Canonical id of the active profile (`MemoryProfiles.OFF` when inactive). */
  public static function current():String
    return MemoryProfiles.normalize(ClientPrefs.memoryProfile);

  /** True while any profile other than `Off` is applied. */
  public static function active():Bool
    return current() != MemoryProfiles.OFF;

  /**
   * Cleanup policy of the active profile.
   *
   * Read once per frame from `update()`, so the result is cached against the
   * raw preference value instead of re-normalizing a string mid-gameplay.
   */
  public static function policy():MemoryPolicy
  {
    final raw:String = ClientPrefs.memoryProfile;
    if (cachedPolicy == null || raw != cachedRawProfile)
    {
      cachedRawProfile = raw;
      cachedPolicy = MemoryProfiles.policy(raw);
    }
    return cachedPolicy;
  }

  /** Short status line for the diagnostics page. */
  public static function statusLine():String
    return MemoryProfiles.summary(ClientPrefs.memoryProfile);

  /**
   * Whether a profile currently forces `field`, which the Options menu can
   * use to explain why a value snaps back.
   */
  public static function isManaged(field:String):Bool
  {
    if (field == null || !active()) return false;
    return MemoryProfiles.overrides(current()).exists(field);
  }

  // -- Applying --------------------------------------------------------------

  /**
   * Boot path: re-applies whatever profile the save file selected.
   *
   * Called at the end of `ClientPrefs.loadPrefs()`, so the first screen
   * already sees the forced values. Idempotent and failure-proof: if anything
   * goes wrong the game simply runs as if no profile were selected.
   */
  public static function applyFromPrefs():Void
  {
    try
    {
      // Whatever the previous session forced is not a player choice: put the
      // real values back before looking at the profile again.
      restoreBaseline();

      final target:String = current();
      if (target == MemoryProfiles.OFF)
      {
        ClientPrefs.memoryProfileBaseline = '';
      }
      else
      {
        final saved:StoredBaseline = MemoryProfiles.decodeBaseline(ClientPrefs.memoryProfileBaseline);
        if (saved == null || saved.profile != target)
          ClientPrefs.memoryProfileBaseline = MemoryProfiles.encodeBaseline(target, capture(target));
        applyOverrides(target);
      }

      ClientPrefs.memoryProfile = target;
      appliedProfile = target;
      invalidatePolicy();
      mirrorLegacyFlag();
      idleSeconds = 0;
      refreshVisuals();
      VLog.memoryEvent('profile applied: ' + MemoryProfiles.summary(target));
    }
    catch (e:Dynamic)
    {
      // A broken baseline must not keep the game from booting.
      VLog.memoryEvent('profile apply failed: ' + Std.string(e));
    }
  }

  /**
   * Player changed the option: snapshot their real values, force the new
   * profile (or restore their values for `Off`) and persist the choice.
   *
   * @param name profile spelling from the menu or a script.
   * @param save write `funkin.sol` right away (the options menu does).
   */
  public static function setProfile(name:String, save:Bool = true):Void
  {
    final target:String = MemoryProfiles.normalize(name);
    try
    {
      restoreBaseline(); // start from what the player actually chose
      final changed:Bool = target != appliedProfile;
      ClientPrefs.memoryProfile = target;

      if (target == MemoryProfiles.OFF)
      {
        ClientPrefs.memoryProfileBaseline = '';
      }
      else
      {
        ClientPrefs.memoryProfileBaseline = MemoryProfiles.encodeBaseline(target, capture(target));
        applyOverrides(target);
      }

      appliedProfile = target;
      invalidatePolicy();
      mirrorLegacyFlag();
      idleSeconds = 0;
      refreshVisuals();
      VLog.memoryEvent('profile changed: ' + MemoryProfiles.summary(target));

      if (save) ClientPrefs.saveSettings();
      // Freeing the previous profile's caches right away is what makes
      // "Extreme" feel like it did something on a device that was already full.
      // Shallow only: a deep clear disposes engine-generated bitmaps (menu font
      // atlases, ...) and is only safe when a state is entering or leaving.
      // Scrolling the option fires onChange per step, so only a real change pays.
      if (changed && target != MemoryProfiles.OFF) trim(false);
    }
    catch (e:Dynamic)
    {
      VLog.memoryEvent('profile change failed: ' + Std.string(e));
    }
  }

  /**
   * Opens the save window: puts the player's own values back so
   * `ClientPrefs.saveSettings()` writes them instead of the forced ones.
   *
   * Safe to call when no profile is active or from a nested save.
   */
  public static function beginSave():Void
  {
    if (restoringForSave) return;
    restoringForSave = true;
    try
    {
      restoreBaseline();
      mirrorLegacyFlag();
    }
    catch (e:Dynamic)
    {
      VLog.memoryEvent('profile save prepare failed: ' + Std.string(e));
    }
  }

  /** Closes the save window and re-applies the active profile. */
  public static function endSave():Void
  {
    if (!restoringForSave) return;
    restoringForSave = false;
    try
    {
      final target:String = current();
      if (target != MemoryProfiles.OFF) applyOverrides(target);
      appliedProfile = target;
      invalidatePolicy();
      mirrorLegacyFlag();
    }
    catch (e:Dynamic)
    {
      VLog.memoryEvent('profile save finish failed: ' + Std.string(e));
    }
  }

  /**
   * Rebuilds the profile state after the preferences were replaced wholesale
   * (settings import), instead of layering it on top of the old values.
   *
   * The imported file has no snapshot of its own, so the new values become the
   * player's baseline and the named profile is forced on top of them.
   */
  public static function reloadAfterImport():Void
  {
    restoringForSave = false;
    try
    {
      final target:String = current();
      ClientPrefs.memoryProfile = target;
      ClientPrefs.memoryProfileBaseline = '';
      if (target != MemoryProfiles.OFF)
      {
        ClientPrefs.memoryProfileBaseline = MemoryProfiles.encodeBaseline(target, capture(target));
        applyOverrides(target);
      }
      appliedProfile = target;
      invalidatePolicy();
      mirrorLegacyFlag();
      idleSeconds = 0;
      refreshVisuals();
      VLog.memoryEvent('profile reloaded after import: ' + MemoryProfiles.summary(target));
    }
    catch (e:Dynamic)
    {
      VLog.memoryEvent('profile reload failed: ' + Std.string(e));
    }
  }

  // -- Runtime policy --------------------------------------------------------

  /**
   * Idle cleanup, called once per frame from `backend.MusicBeatState.update()`.
   *
   * Only runs outside gameplay: trimming during a song would just free notes
   * and sprites that are about to be used and cause a stutter instead of
   * saving anything.
   */
  public static function update(elapsed:Float):Void
  {
    final activePolicy:MemoryPolicy = policy();
    if (activePolicy.idleTrimSeconds <= 0)
    {
      idleSeconds = 0;
      return;
    }

    // `FlxG.state` is the state currently being updated; substates still count
    // as gameplay, so the pause menu will not trim either.
    if (FlxG.state != null && Std.isOfType(FlxG.state, play.PlayState)) return;

    idleSeconds += elapsed;
    if (idleSeconds < activePolicy.idleTrimSeconds) return;

    idleSeconds = 0;
    trim(false);
  }

  /** A song finished; `PlayState.endSong()` calls this. */
  public static function onSongEnd():Void
  {
    if (policy().trimOnSongEnd) trim(false);
  }

  /** PlayState is being torn down; its graphics and audio are now garbage. */
  public static function onPlayStateExit():Void
  {
    if (!policy().releaseOnPlayStateExit) return;
    trim(true);
  }

  /** The window/app went to the background; perfect time to hand RAM back. */
  public static function onFocusLost():Void
  {
    if (!policy().trimOnFocusLost) return;
    if (haxe.Timer.stamp() - lastTrimAt < SIGNAL_TRIM_COOLDOWN) return;
    trim(false);
  }

  /**
   * The OS reported memory pressure (Android `onTrimMemory`/`onLowMemory`).
   *
   * Android's own handler already releases the caches unconditionally, so
   * this only records the event against the active profile in the vlog —
   * which is what a support report needs to know.
   */
  public static function reportSystemPressure():Void
  {
    VLog.memoryEvent('system memory pressure | ' + statusLine());
  }

  /**
   * Releases cached assets now.
   *
   * @param deep also drop cached entries that are still tracked (song audio,
   *             note skins, ...), i.e. the `clearStoredMemory` menu path.
   */
  public static function trim(deep:Bool = false):Void
  {
    final before:Float = VLog.heapUsedBytes();
    try
    {
      if (deep)
      {
        Paths.clearStoredMemory();
        Paths.clearUnusedMemory();
      }
      else
      {
        Paths.clearUnusedMemory();
      }
      lastTrimAt = haxe.Timer.stamp();
      if (deep) VLog.memoryEvent('profile trim (deep) | ' + statusLine() + ' | heap '
        + VLog.formatBytes(before) + ' -> ' + VLog.formatBytes(VLog.heapUsedBytes()));
    }
    catch (e:Dynamic)
    {
      VLog.memoryEvent('profile trim failed: ' + Std.string(e));
    }
  }

  // -- Internals -------------------------------------------------------------

  /** Snapshot of the player's values for the preferences `profile` manages. */
  static function capture(profile:String):Map<String, Dynamic>
  {
    final values:Map<String, Dynamic> = new Map<String, Dynamic>();
    for (field in MemoryProfiles.get(profile).overrides.keys())
    {
      final value:Dynamic = Reflect.field(ClientPrefs, field);
      if (value == null) continue;
      values.set(field, value);
    }
    return values;
  }

  /** Puts the player's own values back (no-op when nothing is stored). */
  static function restoreBaseline():Void
  {
    final saved:StoredBaseline = MemoryProfiles.decodeBaseline(ClientPrefs.memoryProfileBaseline);
    if (saved == null) return;

    // A snapshot is internal save data, not a general-purpose reflection
    // channel. Restore only fields that belonged to the profile that created
    // it; this also makes a hand-edited/cross-version baseline harmless.
    final managed:Map<String, Dynamic> = MemoryProfiles.overrides(saved.profile);
    for (field => value in saved.values)
    {
      if (!managed.exists(field)) continue;
      final live:Dynamic = Reflect.field(ClientPrefs, field);
      if (live == null) continue; // preference was removed since the snapshot
      Reflect.setField(ClientPrefs, field, MemoryProfiles.coerce(live, value));
    }
  }

  /** Forces the profile's values into `ClientPrefs`, type-safe. */
  static function applyOverrides(profile:String):Void
  {
    for (field => forced in MemoryProfiles.overrides(profile))
    {
      final live:Dynamic = Reflect.field(ClientPrefs, field);
      if (live == null) continue;
      Reflect.setField(ClientPrefs, field, MemoryProfiles.coerce(live, forced));
    }
  }

  /**
   * Keeps the legacy `ClientPrefs.lowMemoryMode` boolean in sync.
   *
   * The field existed before profiles and is published to scripts; mods and
   * older HScript code check it, so it is now derived from the profile
   * instead of being a separate switch that does nothing.
   */
  static function mirrorLegacyFlag():Void
  {
    ClientPrefs.lowMemoryMode = active();
  }

  /** Forces the policy cache to be rebuilt on the next `policy()` call. */
  static function invalidatePolicy():Void
  {
    cachedRawProfile = null;
    cachedPolicy = null;
  }

  /** Re-paints the visuals whose default was just forced. */
  static function refreshVisuals():Void
  {
    try
    {
      FlxSprite.defaultAntialiasing = ClientPrefs.globalAntialiasing;
      objects.MovingCheckerboard.refreshAll();
    }
    catch (e:Dynamic)
    {
      // Synthetic states and tests without a stage have no checkerboards.
    }
  }
}
