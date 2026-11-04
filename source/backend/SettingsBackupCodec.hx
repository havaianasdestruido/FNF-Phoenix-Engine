package backend;

import haxe.Json;

/**
 * Reads and writes the `.json` user-settings backup format used by
 * `Options -> <any settings list> -> "Export/Import Settings (.json)"`.
 *
 * The format logic deliberately lives in this Flixel-free module: the
 * player-facing glue (`backend.SettingsBackup`) owns the file dialogs and
 * `ClientPrefs`, while everything here is pure data work. That keeps the
 * format and its type coercion runnable in the Haxe interpreter through
 * `tests/haxe/SettingsBackupCodecSpec.hx`, with no game haxelibs.
 *
 * Format version 1:
 * ```json
 * {
 *   "format": "phoenix-settings-backup",
 *   "formatVersion": 1,
 *   "engine": "Phoenix Engine 0.0.1",
 *   "exportedAt": "2026-11-04 21:00:00",
 *   "settings": { "downScroll": true, "arrowRGB": [[4290408345, 4294967295]] },
 *   "gameplaySettings": { "scrollspeed": 1.0 },
 *   "keyBinds": { "note_left": [65, 263] },
 *   "audio": { "volume": 1.0, "muted": false }
 * }
 * ```
 */
class SettingsBackupCodec
{
  /** Value of the `format` marker every backup file carries. */
  public static inline var FORMAT_ID:String = 'phoenix-settings-backup';

  /** Format this build writes. Older files stay readable. */
  public static inline var FORMAT_VERSION:Int = 1;

  /** A settings file is a few kilobytes; anything bigger is the wrong file. */
  public static inline var MAX_FILE_SIZE:Int = 4194304;

  /**
   * Builds the pretty-printed JSON text of a backup.
   *
   * @param payload values collected from `ClientPrefs` by `SettingsBackup`.
   * @return the file contents, ready to be written as `.json`.
   */
  public static function encode(payload:SettingsBackupPayload):String
  {
    final file:Dynamic = {
      format: FORMAT_ID,
      formatVersion: FORMAT_VERSION,
      engine: payload.engine,
      exportedAt: payload.exportedAt,
      settings: section(payload.settings),
      gameplaySettings: section(payload.gameplaySettings),
      keyBinds: section(payload.keyBinds),
      audio: {volume: payload.volume, muted: payload.muted}
    };
    return Json.stringify(file, null, '  ');
  }

  /** Falls back to an empty JSON object so every section is always present. */
  static function section(values:Dynamic):Dynamic
  {
    if (values != null) return values;
    final empty:Dynamic = {};
    return empty;
  }

  /**
   * Parses a (possibly hand-edited) backup file.
   *
   * Never throws: an unusable file is reported through `error`, and values
   * that do not fit their `ClientPrefs` field are dropped later by `coerce`.
   *
   * @param text contents of the picked `.json` file.
   */
  public static function decode(text:String):SettingsBackupResult
  {
    final result:SettingsBackupResult = {
      error: null,
      warnings: [],
      engine: null,
      exportedAt: null,
      formatVersion: 0,
      settings: null,
      gameplaySettings: null,
      keyBinds: null,
      volume: null,
      muted: null
    };

    if (text == null || StringTools.trim(text).length == 0)
    {
      result.error = 'The selected file is empty.';
      return result;
    }
    // Editors on Windows happily save a UTF-8 BOM; JSON does not allow one.
    if (text.charCodeAt(0) == 0xFEFF) text = text.substr(1);
    if (text.length > MAX_FILE_SIZE)
    {
      result.error = 'That file is way too big to be a settings backup.';
      return result;
    }

    var parsed:Dynamic = null;
    try
    {
      parsed = Json.parse(text);
    }
    catch (_:Dynamic)
    {
      result.error = 'That file is not valid JSON.';
      return result;
    }

    if (!isObject(parsed))
    {
      result.error = 'That JSON is not a Phoenix settings backup.';
      return result;
    }

    // The marker keeps a chart.json, character.json, ... from being imported
    // by mistake and silently overwriting unrelated preferences.
    final format:Dynamic = Reflect.field(parsed, 'format');
    if (!Std.isOfType(format, String) || format != FORMAT_ID)
    {
      result.error = 'That file is not a Phoenix settings backup\n(no "' + FORMAT_ID + '" format marker).';
      return result;
    }

    final version:Dynamic = Reflect.field(parsed, 'formatVersion');
    result.formatVersion = (Std.isOfType(version, Int) || Std.isOfType(version, Float)) ? Std.int(version) : FORMAT_VERSION;
    if (result.formatVersion > FORMAT_VERSION)
      result.warnings.push('That backup is from a newer engine;\nunknown settings were ignored.');

    result.engine = asString(Reflect.field(parsed, 'engine'));
    result.exportedAt = asString(Reflect.field(parsed, 'exportedAt'));

    final settings:Dynamic = Reflect.field(parsed, 'settings');
    if (isObject(settings)) result.settings = settings;

    final gameplay:Dynamic = Reflect.field(parsed, 'gameplaySettings');
    if (isObject(gameplay)) result.gameplaySettings = gameplay;

    final binds:Dynamic = Reflect.field(parsed, 'keyBinds');
    if (isObject(binds)) result.keyBinds = binds;

    final audio:Dynamic = Reflect.field(parsed, 'audio');
    if (isObject(audio))
    {
      final volume:Dynamic = Reflect.field(audio, 'volume');
      final muted:Dynamic = Reflect.field(audio, 'muted');
      if (volume != null) result.volume = coerceFloat(volume);
      if (muted != null) result.muted = coerceBool(muted);
    }

    if (result.settings == null && result.gameplaySettings == null && result.keyBinds == null)
      result.error = 'That backup does not contain any settings.';

    return result;
  }

  /**
   * Converts a decoded JSON `value` so it can safely be stored in a
   * preference whose current value is `reference` (used as a type template).
   *
   * @return the converted value, or `null` when `value` cannot represent the
   *         reference's type (callers then keep their current value).
   */
  public static function coerce(reference:Dynamic, value:Dynamic):Dynamic
  {
    if (reference == null || value == null) return null;

    if (Std.isOfType(reference, Bool)) return coerceBool(value);
    if (Std.isOfType(reference, Int)) return coerceInt(value);
    if (Std.isOfType(reference, Float)) return coerceFloat(value);
    if (Std.isOfType(reference, String)) return Std.isOfType(value, String) ? value : null;
    if (Std.isOfType(reference, Array)) return coerceArray(reference, value);
    return null;
  }

  /** Bool field: accepts `true`/`false`, `0`/`1` and their string forms. */
  public static function coerceBool(value:Dynamic):Null<Bool>
  {
    if (value == null) return null;
    if (Std.isOfType(value, Bool)) return value;
    if (Std.isOfType(value, Int) || Std.isOfType(value, Float))
    {
      final number:Float = value;
      return number != 0;
    }
    if (Std.isOfType(value, String))
    {
      final text:String = StringTools.trim(value).toLowerCase();
      if (text == 'true' || text == '1') return true;
      if (text == 'false' || text == '0') return false;
    }
    return null;
  }

  /** Int field: accepts whole numbers and numeric strings, truncating floats. */
  public static function coerceInt(value:Dynamic):Null<Int>
  {
    if (value == null) return null;
    if (Std.isOfType(value, Int)) return value;
    if (Std.isOfType(value, Float))
    {
      final number:Float = value;
      if (Math.isNaN(number) || !Math.isFinite(number)) return null;
      return Std.int(number);
    }
    if (Std.isOfType(value, String)) return Std.parseInt(StringTools.trim(value));
    return null;
  }

  /** Float field: accepts any finite number or numeric string. */
  public static function coerceFloat(value:Dynamic):Null<Float>
  {
    if (value == null) return null;
    if (Std.isOfType(value, String))
    {
      final parsed:Float = Std.parseFloat(StringTools.trim(value));
      return (Math.isNaN(parsed) || !Math.isFinite(parsed)) ? null : parsed;
    }
    // Whole numbers first: widening an Int keeps a real Float on static targets.
    if (Std.isOfType(value, Int))
    {
      final integer:Int = value;
      return integer;
    }
    if (Std.isOfType(value, Float))
    {
      final number:Float = value;
      return (Math.isNaN(number) || !Math.isFinite(number)) ? null : number;
    }
    return null;
  }

  /** Array field (note colors, combo offsets, ...): converts element by element. */
  public static function coerceArray(reference:Array<Dynamic>, value:Dynamic):Dynamic
  {
    if (reference == null || !Std.isOfType(value, Array)) return null;
    final values:Array<Dynamic> = value;
    if (reference.length == 0) return values;

    final converted:Array<Dynamic> = [];
    for (i in 0...reference.length)
    {
      if (i >= values.length) return null;
      final item:Dynamic = coerce(reference[i], values[i]);
      if (item == null) return null;
      converted.push(item);
    }
    return converted;
  }

  /** True for JSON objects (`{...}`), false for arrays, scalars and null. */
  public static function isObject(value:Dynamic):Bool
  {
    // `Reflect.isObject` also reports strings (and other class instances), so
    // the JSON scalars are excluded explicitly before trusting it.
    if (value == null) return false;
    if (Std.isOfType(value, String) || Std.isOfType(value, Array)) return false;
    if (Std.isOfType(value, Bool) || Std.isOfType(value, Int) || Std.isOfType(value, Float)) return false;
    return Reflect.isObject(value);
  }

  static function asString(value:Dynamic):Null<String>
  {
    return Std.isOfType(value, String) ? value : null;
  }
}

/** Everything `SettingsBackupCodec.encode` needs to write a backup file. */
typedef SettingsBackupPayload =
{
  /** Engine name + version, only informational. */
  var engine:String;
  /** Human readable export date, only informational. */
  var exportedAt:String;
  /** `ClientPrefs` preference name -> value. */
  var settings:Dynamic;
  /** Gameplay modifiers from `ClientPrefs.gameplaySettings`. */
  var gameplaySettings:Dynamic;
  /** Control name -> raw key codes. */
  var keyBinds:Dynamic;
  var volume:Float;
  var muted:Bool;
}

/** Parsed backup file; `error` is null when the file can be applied. */
typedef SettingsBackupResult =
{
  var error:Null<String>;
  var warnings:Array<String>;
  var engine:Null<String>;
  var exportedAt:Null<String>;
  var formatVersion:Int;
  var settings:Dynamic;
  var gameplaySettings:Dynamic;
  var keyBinds:Dynamic;
  var volume:Null<Float>;
  var muted:Null<Bool>;
}
