/**
 * Options -> Audio -> Master Volume must stay a *mirror* of `FlxG.sound.volume`,
 * never a second copy of it, and it must follow the volume keys instead of
 * showing the value the menu was built with.
 *
 * The behaviour is covered by `VolumeCurveSpec` (the shared curve) and by the
 * compiled game; what this spec pins is the wiring, which is exactly what a
 * rename or a forgotten blacklist entry breaks silently:
 *
 *   1. `masterVolume` is excluded from the save file and from `.json` backups,
 *      while `FlxG.sound.volume` stays the persisted value (`flixelSound`);
 *   2. both master volume rows (Audio and Misc) are `live` rows bound to the
 *      same mirror and apply through `ClientPrefs.assignMasterVolume()`;
 *   3. the curve is the only conversion, and the menu refreshes live rows.
 *
 * File reads need `sys`, so this runs in the Haxe interpreter:
 *
 *     bash tests/haxe/run-master-volume.sh
 */
class MasterVolumeSpec
{
  static inline var PREFS:String = 'source/backend/ClientPrefs.hx';
  static inline var BACKUP:String = 'source/backend/SettingsBackup.hx';
  static inline var AUDIO:String = 'source/options/AudioSettingsSubState.hx';
  static inline var MISC:String = 'source/options/MiscSettingsSubState.hx';
  static inline var HELPERS:String = 'source/options/helpers/OptionsMenuHelpers.hx';
  static inline var MENU:String = 'source/options/BaseOptionsMenu.hx';
  static inline var OPTION:String = 'source/options/Option.hx';
  static inline var CURVE:String = 'source/backend/VolumeCurve.hx';
  static inline var TRAY:String = 'source/objects/CustomSoundTray.hx';

  static function main():Void
  {
    final prefs:String = read(PREFS);
    final backup:String = read(BACKUP);
    final helpers:String = read(HELPERS);
    final audio:String = read(AUDIO);
    final misc:String = read(MISC);
    final menu:String = read(MENU);

    storedOnce(prefs, backup);
    rowsAreLive(helpers, audio, misc);
    oneCodePath(prefs);
    mutePersistence(prefs, backup, read(TRAY), helpers, audio, misc, menu);
    menuWiring(menu, read(OPTION));
    curveIsShared(read(CURVE));

    trace('MasterVolumeSpec passed');
  }

  /** 1. Flixel's `volume` and `muted` are the stored values; mirrors are kept out of both. */
  static function storedOnce(prefs:String, backup:String):Void
  {
    contains(prefs, 'public static var masterVolume:Float = 1;', 'ClientPrefs.masterVolume (Float, default 100%) is missing');
    contains(prefs, 'public static var masterMuted:Bool = false;', 'ClientPrefs.masterMuted (Bool, default false) is missing');

    final saveList:String = lineContaining(prefs, '"saveBlackList" =>');
    final loadList:String = lineContaining(prefs, '"loadBlackList" =>');
    contains(saveList, '"masterVolume"', 'masterVolume is not in the saveBlackList, so it would be saved twice');
    contains(loadList, '"masterVolume"', 'masterVolume is not in the loadBlackList, so it would be loaded twice');
    contains(saveList, '"masterMuted"', 'masterMuted is not in the saveBlackList, so it would be saved twice');
    contains(loadList, '"masterMuted"', 'masterMuted is not in the loadBlackList, so it would be loaded twice');
    contains(prefs, '"flixelSound" => ["volume", "muted"]', 'FlxG.sound.volume and muted must stay the persisted values (flixelSound)');
    notContains(prefs, '"flixelSound" => ["volume", "sound"]', 'flixelSound must not reference the nonexistent "sound" field');
    notContains(saveList, '"volume"', 'the mirror must not replace the flixelSound round trip');
    notContains(saveList, '"muted"', 'the mute mirror must not replace the flixelSound round trip');

    contains(backup, "'masterVolume',", 'masterVolume is not in SettingsBackup.NOT_PREFERENCES and would be exported twice');
    contains(backup, "'masterMuted',", 'masterMuted is not in SettingsBackup.NOT_PREFERENCES and would be exported twice');
    contains(backup, 'volume: FlxG.sound.volume,', 'the backup must keep carrying the real volume');
    contains(backup, 'ClientPrefs.syncMasterVolume();',
      'an imported volume must refresh the mirror right away');
  }

  /**
   * 2. Every master volume row mirrors the real value.
   *
   * One definition, `OptionsMenuHelpers.addMasterVolumeRow()`, is used by both
   * lists so the two rows cannot drift apart.
   */
  static function rowsAreLive(helpers:String, audio:String, misc:String):Void
  {
    contains(helpers, "'masterVolume',", 'the helper has no masterVolume row');
    contains(helpers, "'percent',", 'the master volume row must be a percent');
    contains(helpers, 'option.live = true;', 'the master volume row must be live');
    contains(helpers, 'option.readValue = ClientPrefs.readMasterVolume;',
      'the row must read the real volume every frame');
    contains(helpers, 'option.onChange = () -> ClientPrefs.assignMasterVolume(ClientPrefs.masterVolume);',
      'the row must apply its value through assignMasterVolume()');
    // `decimals` is the *value's* precision (0..1): 0 would round every step
    // back to 0 or 1, so the row could only ever be silent or full.
    contains(helpers, 'option.decimals = 2;', '2% steps need decimals = 2');
    contains(helpers, 'option.changeValue = 0.02;', '2% a press expected');

    contains(audio, 'OptionsMenuHelpers.addMasterVolumeRow(this);', 'Options -> Audio lost its master volume row');
    contains(misc, 'OptionsMenuHelpers.addMasterVolumeRow(this);', 'Options -> Misc lost its master volume row');
  }

  /** 3. One function writes the volume, and it goes through the curve. */
  static function oneCodePath(prefs:String):Void
  {
    contains(prefs, 'FlxG.sound.volume = VolumeCurve.toVolume(percent);',
      'assignMasterVolume() must go through the shared curve');
    contains(prefs, 'masterVolume = VolumeCurve.toPercent(FlxG.sound.volume);',
      'syncMasterVolume() must mirror FlxG.sound.volume through the curve');
    contains(prefs, 'public static function readMasterVolume():Dynamic {',
      'ClientPrefs.readMasterVolume() is missing');

    // The mirror must never be assigned from anywhere but the curve: a second
    // stored value is exactly what this feature has to avoid.
    for (line in prefs.split('\n'))
    {
      final trimmed:String = StringTools.trim(line);
      if (!StringTools.startsWith(trimmed, 'masterVolume =')) continue;
      check(StringTools.startsWith(trimmed, 'masterVolume = VolumeCurve.toPercent('),
        'masterVolume is only ever mirrored through the curve: ' + trimmed);
    }
  }

  /** 4. Mute survives restarts from both Options and the sound tray. */
  static function mutePersistence(
    prefs:String,
    backup:String,
    tray:String,
    helpers:String,
    audio:String,
    misc:String,
    menu:String
  ):Void
  {
    contains(prefs, 'FlxG.save.data.mute = FlxG.sound.muted;', 'saveSettings() must keep legacy save.data.mute in sync');
    contains(prefs, 'Reflect.field(FlxG.save.data, "mute")', 'loadPrefs() must migrate legacy save.data.mute');
    contains(prefs, 'FlxG.sound.volumeHandler(FlxG.sound.muted ? 0 : FlxG.sound.volume);',
      'loadPrefs()/assignMasterMuted() must notify volumeHandler when muted changes');
    contains(prefs, 'public static function readMasterMuted():Dynamic {', 'ClientPrefs.readMasterMuted() is missing');
    contains(prefs, 'public static function assignMasterMuted(muted:Bool):Void {', 'ClientPrefs.assignMasterMuted() is missing');

    contains(tray, 'FlxG.save.data.muted = FlxG.sound.muted;', 'CustomSoundTray must persist save.data.muted');
    contains(tray, 'FlxG.save.data.mute = FlxG.sound.muted;', 'CustomSoundTray must keep save.data.mute in sync');
    contains(tray, 'FlxG.save.flush();', 'CustomSoundTray must flush audio changes so tray-only mutes survive quit');

    contains(helpers, "'masterMuted',", 'OptionsMenuHelpers.addMuteRow() must bind masterMuted');
    contains(helpers, 'option.readValue = ClientPrefs.readMasterMuted;', 'Mute row must read live mute state');
    contains(helpers, 'option.onChange = () -> ClientPrefs.assignMasterMuted(ClientPrefs.masterMuted);',
      'Mute row must route through assignMasterMuted()');
    contains(audio, 'OptionsMenuHelpers.addMuteRow(this);', 'Options -> Audio must include Mute Audio');
    contains(misc, 'OptionsMenuHelpers.addMuteRow(this);', 'Options -> Misc must include Mute Audio');

    contains(menu, 'checkbox.daValue = (option.getValue() == true);',
      'refreshLiveOptions() must refresh live checkbox rows');
    contains(backup, 'ClientPrefs.syncMasterMuted();', 'SettingsBackup import must sync masterMuted');
  }

  static function menuWiring(menu:String, option:String):Void
  {
    contains(menu, 'refreshLiveOptions();', 'BaseOptionsMenu.update() must refresh live rows');
    contains(menu, 'if (option == null || !option.live) continue;',
      'refreshLiveOptions() must skip plain options');
    // A live row may also be a checkbox now (Android TV Navigation turns itself
    // off from `backend.TouchlessUI`), and those refresh through
    // `reloadCheckboxes()`. The volume row is a text row, so it still has to be
    // re-read from the curve every frame instead of falling into that branch.
    contains(menu, 'else if (option.text != null) updateTextFrom(option);',
      'refreshLiveOptions() must re-read live text rows');
    // Reset has to apply a live row *before* re-reading its label, or the label
    // syncs the mirror back to the old value and the reset does nothing.
    final reset:String = functionBody(menu, 'function resetOptionToDefault(');
    final applyAt:Int = reset.indexOf('if (leOption.live) leOption.change();');
    final readAt:Int = reset.indexOf('updateTextFrom(leOption);');
    check(applyAt != -1, 'resetOptionToDefault() must apply a live row through onChange()');
    check(readAt != -1, 'resetOptionToDefault() must refresh the label');
    check(applyAt < readAt, 'a live reset must apply before the label is re-read');

    contains(option, 'if (live && readValue != null) return readValue();',
      'Option.getValue() must report a live row through readValue()');
    contains(option, 'public var live:Bool = false;', 'Option.live is missing');
  }

  static function curveIsShared(curve:String):Void
  {
    contains(curve, 'public static inline var MIN_VOLUME:Float = 0.001;', 'the curve lost the tray floor');
    contains(curve, 'public static function toVolume(percent:Float):Float', 'VolumeCurve.toVolume() is missing');
    contains(curve, 'public static function toPercent(volume:Float):Float', 'VolumeCurve.toPercent() is missing');
    contains(curve, 'public static function steppedVolume(volume:Float, amount:Float):Float',
      'VolumeCurve.steppedVolume() is missing');
    // The tray and the row must not each keep their own copy of the maths.
    notContains(curve, 'import flixel', 'the curve stays Flixel-free so the spec can run it');
  }

  // -- helpers ---------------------------------------------------------------

  static function read(path:String):String
  {
    if (!sys.FileSystem.exists(path)) throw 'missing file: $path';
    return sys.io.File.getContent(path);
  }

  static function contains(haystack:String, needle:String, label:String):Void
  {
    if (haystack == null || haystack.indexOf(needle) == -1) throw label;
  }

  static function notContains(haystack:String, needle:String, label:String):Void
  {
    if (haystack != null && haystack.indexOf(needle) != -1) throw label;
  }

  static function check(ok:Bool, label:String):Void
  {
    if (!ok) throw label;
  }

  /** The first line that contains `marker` (blacklists are one line each). */
  static function lineContaining(source:String, marker:String):String
  {
    for (line in source.split('\n'))
      if (line.indexOf(marker) != -1) return line;
    throw 'no line contains: $marker';
  }

  /** Text from `signature` to the next line that is a single closing brace. */
  static function functionBody(source:String, signature:String):String
  {
    final start:Int = source.indexOf(signature);
    if (start == -1) throw 'no function: $signature';
    final end:Int = source.indexOf('\n\t}', start);
    return end == -1 ? source.substr(start) : source.substring(start, end);
  }
}
