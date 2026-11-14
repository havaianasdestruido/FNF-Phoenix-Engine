package backend;

import Main;
import backend.SettingsBackupCodec.SettingsBackupPayload;
import backend.SettingsBackupCodec.SettingsBackupResult;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.input.keyboard.FlxKey;
import mobile.files.MobileFilePicker;
import mobile.files.MobileFilePicker.PickedFile;

/**
 * Exports and imports every user preference as a `.json` backup file.
 *
 * Every settings list (`Options -> Gameplay`, `Misc`, ...) ends with an
 * "Export/Import Settings (.json)" pair of options that call into here, so a
 * player can copy their setup to another device or keep a snapshot before
 * trying something weird.
 *
 * The file is written through `mobile.files.MobileFilePicker`, which uses the
 * system "save as" dialog on desktop and the Storage Access Framework picker
 * on Android, so both sides work everywhere the game runs. The format itself
 * is handled by the Flixel-free `backend.SettingsBackupCodec`.
 *
 * Import is defensive: only names that already exist in `ClientPrefs` are
 * touched, and every value is coerced with the current one as a type template,
 * so a hand-edited or outdated file can never inject unknown fields.
 */
class SettingsBackup
{
  /** Suggested name of a freshly exported backup file. */
  public static inline var FILE_NAME:String = 'phoenix-settings-backup.json';

  /** MIME type used by the Android document picker. */
  public static inline var MIME:String = 'application/json';

  /** `ClientPrefs` statics that are not player preferences. */
  static final NOT_PREFERENCES:Array<String> = [
    'gameplaySettings',
    'keyBinds',
    'defaultKeys',
    'defaultArrowRGB',
    'defaultPixelRGB',
    'defaultQuantRGB',
    'importantMap',
    // A mirror of `FlxG.sound.volume` for Options -> Audio; the real value is
    // already carried in the `audio` section, and exporting both would let the
    // two disagree after a hand edit.
    'masterVolume',
    // Internal state managed by backend.LowMemory. A backup carries the
    // selected profile, but never its private snapshot or derived mirror.
    'memoryProfileBaseline',
    'lowMemoryMode'
  ];

  /**
   * True while a picker is open, so holding the option cannot stack native
   * file dialogs. Read with `SettingsBackup.busy`.
   */
  public static var busy(default, null):Bool = false;

  /**
   * Opens a "save as" dialog pre-filled with every current preference.
   *
   * @param onResult receives the message to show the player; `null` means the
   *                 player canceled and there is nothing to report.
   */
  public static function exportToFile(?onResult:String->Void):Void
  {
    if (busy) return;
    busy = true;

    var answered:Bool = false;
    final started:Bool = MobileFilePicker.saveText(SettingsBackupCodec.encode(collect()), FILE_NAME, MIME,
      'Export your Phoenix settings backup', function(path:String):Void
      {
        answered = true;
        busy = false;
        if (onResult == null) return;
        if (path == null || StringTools.trim(path).length == 0)
        {
          onResult(null); // canceled
          return;
        }
        onResult('Settings exported to:\n' + path);
      });

    if (!started)
    {
      busy = false;
      if (!answered && onResult != null)
        onResult('This platform has no "save as" dialog,\nso the backup cannot be written.');
    }
  }

  /**
   * Opens a picker for a previously exported backup and applies it.
   *
   * @param onResult receives the message to show the player; `null` means the
   *                 player canceled and there is nothing to report.
   */
  public static function importFromFile(?onResult:String->Void):Void
  {
    if (busy) return;
    busy = true;

    var answered:Bool = false;
    final started:Bool = MobileFilePicker.openFile(function(file:PickedFile):Void
    {
      answered = true;
      busy = false;
      if (onResult == null) return;
      if (file == null || file.data == null)
      {
        onResult(null); // canceled
        return;
      }
      onResult(importFromJson(file.data.toString()));
    }, ['json'], 'Choose a Phoenix settings backup (.json)');

    if (!started)
    {
      busy = false;
      if (!answered && onResult != null)
        onResult('This platform has no file picker,\nso the backup cannot be loaded.');
    }
  }

  /**
   * Applies an already-read backup file and saves the result.
   *
   * @param text contents of the `.json` file.
   * @return a short message for the player (success or the reason it failed).
   */
  public static function importFromJson(text:String):String
  {
    final decoded:SettingsBackupResult = SettingsBackupCodec.decode(text);
    if (decoded.error != null) return 'Could not import settings.\n\n' + decoded.error;

    var applied:Int = 0;
    // Put the player's own values back before importing, so a forced memory
    // profile value is never treated as if the player had chosen it.
    LowMemory.beginSave();
    applied += applySettings(decoded.settings);
    applied += applyGameplaySettings(decoded.gameplaySettings);
    applied += applyKeyBinds(decoded.keyBinds);

    if (decoded.volume != null)
    {
      FlxG.sound.volume = decoded.volume;
      applied++;
    }
    if (decoded.muted != null)
    {
      FlxG.sound.muted = decoded.muted;
      applied++;
    }
    // Options -> Audio shows the imported volume right away instead of waiting
    // for the next frame it is open.
    ClientPrefs.syncMasterVolume();

    if (applied == 0)
    {
      LowMemory.endSave(); // re-applies the profile that was already active
      return 'That backup contains no setting this\nversion of the engine can use.';
    }

    // The backup carries its own memory profile (or Off): rebuild the
    // snapshot/override state from the imported values instead of merging it
    // with the snapshot of the previous profile.
    LowMemory.reloadAfterImport();
    ClientPrefs.saveSettings();
    applyImmediately();

    final notes:Array<String> = ['Settings imported!', applied + ' preference(s) restored.'];
    if (decoded.warnings.length > 0) notes.push(decoded.warnings[0]);
    notes.push('Restart to apply everything.');
    return notes.join('\n');
  }

  /** Collects every preference into the payload the codec writes out. */
  public static function collect():SettingsBackupPayload
  {
    // A memory profile forces some fields; export the player's own values so a
    // backup taken with "Extreme" on still restores what they actually chose.
    LowMemory.beginSave();

    final settings:Dynamic = {};
    for (field in preferenceFields())
      Reflect.setField(settings, field, Reflect.field(ClientPrefs, field));

    final gameplay:Dynamic = {};
    for (name in ClientPrefs.gameplaySettings.keys())
      Reflect.setField(gameplay, name, ClientPrefs.gameplaySettings.get(name));

    final binds:Dynamic = {};
    for (control => keys in ClientPrefs.keyBinds)
    {
      final values:Array<Dynamic> = [];
      for (key in keys) values.push(key); // FlxKey is an Int at runtime
      Reflect.setField(binds, control, values);
    }

    LowMemory.endSave();

    return {
      engine: 'Phoenix Engine ' + PhoenixVersion.current,
      exportedAt: Date.now().toString(),
      settings: settings,
      gameplaySettings: gameplay,
      keyBinds: binds,
      volume: FlxG.sound.volume,
      muted: FlxG.sound.muted
    };
  }

  /** Names of the `ClientPrefs` statics that count as user preferences. */
  public static function preferenceFields():Array<String>
  {
    final fields:Array<String> = [];
    for (field in Type.getClassFields(ClientPrefs))
      if (isPreference(field)) fields.push(field);
    return fields;
  }

  /**
   * True when `name` is a real, importable preference of `ClientPrefs` **that
   * applies to this build**.
   *
   * Platform-only fields (Android cut-out, mobile controls, renderer options on
   * web, ...) are left out of exports and ignored on import, so a backup made on
   * one device never carries settings the current target cannot use.
   */
  public static function isPreference(name:String):Bool
  {
    if (name == null || name.length == 0) return false;
    if (NOT_PREFERENCES.indexOf(name) != -1) return false;
    if (!PlatformSupport.supportsPreference(name)) return false;
    final value:Dynamic = Reflect.field(ClientPrefs, name);
    return value != null && !Reflect.isFunction(value);
  }

  /** Applies the `settings` section; returns how many values were written. */
  static function applySettings(settings:Dynamic):Int
  {
    if (settings == null) return 0;

    var applied:Int = 0;
    for (field in Reflect.fields(settings))
    {
      if (!isPreference(field)) continue;
      final reference:Dynamic = Reflect.field(ClientPrefs, field);
      final value:Dynamic = SettingsBackupCodec.coerce(reference, Reflect.field(settings, field));
      if (value == null) continue; // wrong type for this field: keep the current value
      Reflect.setField(ClientPrefs, field, value);
      applied++;
    }
    return applied;
  }

  /** Merges the `gameplaySettings` section, keeping unknown modifiers. */
  static function applyGameplaySettings(gameplay:Dynamic):Int
  {
    if (gameplay == null) return 0;

    var applied:Int = 0;
    for (name in Reflect.fields(gameplay))
    {
      if (!ClientPrefs.gameplaySettings.exists(name)) continue;
      final reference:Dynamic = ClientPrefs.gameplaySettings.get(name);
      final value:Dynamic = SettingsBackupCodec.coerce(reference, Reflect.field(gameplay, name));
      if (value == null) continue;
      ClientPrefs.gameplaySettings.set(name, value);
      applied++;
    }
    return applied;
  }

  /** Applies the `keyBinds` section; controls unknown to this build stay put. */
  static function applyKeyBinds(binds:Dynamic):Int
  {
    if (binds == null) return 0;

    var applied:Int = 0;
    var changed:Bool = false;
    for (control in Reflect.fields(binds))
    {
      final existing:Array<FlxKey> = ClientPrefs.keyBinds.get(control);
      final imported:Dynamic = Reflect.field(binds, control);
      if (existing == null || !Std.isOfType(imported, Array)) continue;

      final codes:Array<Dynamic> = imported;
      final rebuilt:Array<FlxKey> = [];
      var valid:Bool = true;
      final count:Int = existing.length > 0 ? existing.length : codes.length;
      for (i in 0...count)
      {
        if (i >= codes.length) // older backups may hold fewer keys per control
        {
          rebuilt.push(NONE);
          continue;
        }
        final code:Dynamic = SettingsBackupCodec.coerce(0, codes[i]);
        if (code == null)
        {
          valid = false;
          break;
        }
        final key:FlxKey = cast code;
        rebuilt.push(key);
      }

      if (!valid) continue;
      ClientPrefs.keyBinds.set(control, rebuilt);
      changed = true;
      applied++;
    }

    if (changed) ClientPrefs.reloadControls();
    return applied;
  }

  /**
   * Re-applies the preferences that are read once at startup, so an import
   * takes effect right away. Anything else (note skins, resolution, ...)
   * naturally shows up after the game is restarted.
   */
  static function applyImmediately():Void
  {
    if (ClientPrefs.framerate > 0)
    {
      FlxG.drawFramerate = ClientPrefs.framerate;
      FlxG.updateFramerate = ClientPrefs.framerate;
      debug.FrameProfiler.setTargetFps(ClientPrefs.framerate);
    }

    FlxSprite.defaultAntialiasing = ClientPrefs.globalAntialiasing;
    if (Main.fpsVar != null) Main.fpsVar.visible = ClientPrefs.showFPS;

    ClientPrefs.applyWidescreenPreference();
    #if android
    ClientPrefs.applyCutoutPreference();
    TouchlessUI.syncMouseCursor(!TouchlessUI.isActive());
    #end
    ClientPrefs.reloadControls();
    VLog.setEnabled(ClientPrefs.vlogEnabled);
    LuaDiagnosticsSetup.sync();
  }
}
