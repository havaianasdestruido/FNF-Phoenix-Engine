import backend.SettingsBackupCodec;
import backend.SettingsBackupCodec.SettingsBackupPayload;

/**
 * Contract tests for `backend.SettingsBackupCodec`.
 *
 * The codec is Flixel-free on purpose, so this spec runs in the Haxe
 * interpreter without any game haxelibs. It covers the file format, the
 * guard rails that reject non-backup JSON and the type coercion that protects
 * `ClientPrefs` from hand-edited or outdated values.
 *
 *     bash tests/haxe/run-settings-backup.sh
 */
class SettingsBackupCodecSpec
{
  static function check(ok:Bool, label:String):Void
  {
    if (!ok) throw label;
  }

  static function number(value:Dynamic):Float
  {
    final result:Float = value;
    return result;
  }

  static function field(object:Dynamic, name:String):Dynamic
  {
    return object == null ? null : Reflect.field(object, name);
  }

  static function minimal():SettingsBackupPayload
  {
    return {
      engine: 'Phoenix Engine test',
      exportedAt: '2026-11-04 21:00:00',
      settings: {downScroll: true},
      gameplaySettings: {},
      keyBinds: {},
      volume: 1.0,
      muted: false
    };
  }

  static function main():Void
  {
    roundTrip();
    rejectsForeignFiles();
    coercesValues();
    warnsAboutNewerFormats();
  }

  /** Everything exported must come back with the same value and type. */
  static function roundTrip():Void
  {
    final payload:SettingsBackupPayload = {
      engine: 'Phoenix Engine 0.0.1',
      exportedAt: '2026-11-04 21:00:00',
      settings: {
        downScroll: true,
        framerate: 120,
        noteSpawnTime: 1.5,
        noteSkin: 'Default',
        arrowRGB: [[16711680, 16777215, 983040], [65280, 16777215, 255]]
      },
      gameplaySettings: {scrollspeed: 1.25, practice: false},
      keyBinds: {note_left: [65, 263]},
      volume: 0.75,
      muted: false
    };

    final text:String = SettingsBackupCodec.encode(payload);
    check(text.indexOf('"format": "phoenix-settings-backup"') != -1, 'format marker written');
    check(text.indexOf('"formatVersion": 1') != -1, 'format version written');
    check(text.indexOf('\n  ') != -1, 'output is indented');

    final decoded = SettingsBackupCodec.decode(text);
    check(decoded.error == null, 'round-trip error: ' + decoded.error);
    check(field(decoded.settings, 'downScroll') == true, 'bool round-trip');
    check(field(decoded.settings, 'framerate') == 120, 'int round-trip');
    check(Math.abs(number(field(decoded.settings, 'noteSpawnTime')) - 1.5) < 0.0001, 'float round-trip');
    check(field(decoded.settings, 'noteSkin') == 'Default', 'string round-trip');

    final colors:Array<Dynamic> = field(decoded.settings, 'arrowRGB');
    check(colors != null && colors.length == 2 && Std.isOfType(colors[0], Array), 'nested arrays round-trip');
    final firstRow:Array<Dynamic> = colors[0];
    check(number(firstRow[0]) == 16711680 && number(firstRow[2]) == 983040, 'color values round-trip');

    check(Math.abs(number(field(decoded.gameplaySettings, 'scrollspeed')) - 1.25) < 0.0001, 'gameplay modifiers round-trip');
    check(field(decoded.keyBinds, 'note_left') != null, 'keybinds round-trip');
    final volume:Float = decoded.volume == null ? 0.0 : decoded.volume;
    check(Math.abs(volume - 0.75) < 0.0001, 'volume round-trip');
    check(decoded.muted == false, 'muted round-trip');
    check(decoded.engine == 'Phoenix Engine 0.0.1', 'engine name round-trip');
  }

  /** Anything that is not a Phoenix settings backup has to be refused. */
  static function rejectsForeignFiles():Void
  {
    check(SettingsBackupCodec.decode('').error != null, 'empty file');
    check(SettingsBackupCodec.decode('   \n\t').error != null, 'blank file');
    check(SettingsBackupCodec.decode('{not json').error != null, 'broken json');
    check(SettingsBackupCodec.decode('[1, 2, 3]').error != null, 'array is not a backup');
    check(SettingsBackupCodec.decode('"just a string"').error != null, 'string is not a backup');
    check(SettingsBackupCodec.decode('{"song": {"song": "Bopeebo"}}').error != null, 'chart.json rejected');
    check(SettingsBackupCodec.decode('{"format": "phoenix-settings-backup"}').error != null, 'backup without sections');
    check(SettingsBackupCodec.decode('{"format": "something-else", "settings": {}}').error != null, 'wrong marker');

    // Windows editors love a UTF-8 BOM; the file is still ours.
    final withBom:String = String.fromCharCode(0xFEFF) + SettingsBackupCodec.encode(minimal());
    check(SettingsBackupCodec.decode(withBom).error == null, 'UTF-8 BOM tolerated');
  }

  /** Imported values must fit the field they land in. */
  static function coercesValues():Void
  {
    check(SettingsBackupCodec.coerce(false, true) == true, 'bool kept');
    check(SettingsBackupCodec.coerce(true, 'false') == false, 'bool from string');
    check(SettingsBackupCodec.coerce(true, 1) == true, 'bool from number');
    check(SettingsBackupCodec.coerce(true, 5) == true, 'bool from any non-zero');
    check(SettingsBackupCodec.coerce(true, {}) == null, 'bool rejects objects');

    check(SettingsBackupCodec.coerce(0, 3.9) == 3, 'int truncates');
    check(SettingsBackupCodec.coerce(0, '42') == 42, 'int from string');
    check(SettingsBackupCodec.coerce(0, 'abc') == null, 'int rejects garbage');
    check(SettingsBackupCodec.coerce(0, true) == null, 'int rejects bools');

    check(Math.abs(number(SettingsBackupCodec.coerce(1.5, 2)) - 2) < 0.0001, 'float from int');
    check(Math.abs(number(SettingsBackupCodec.coerce(1.5, 0.25)) - 0.25) < 0.0001, 'float kept');
    check(SettingsBackupCodec.coerce(1.5, 'nope') == null, 'float rejects garbage');

    check(SettingsBackupCodec.coerce('Default', 'Custom') == 'Custom', 'string kept');
    check(SettingsBackupCodec.coerce('Default', 5) == null, 'string rejects numbers');
    check(SettingsBackupCodec.coerce('Default', null) == null, 'string rejects null');

    // Note colors are nested int arrays: the reference keeps the shape.
    final template:Array<Dynamic> = [[0, 0, 0], [0, 0, 0]];
    final converted:Array<Dynamic> = SettingsBackupCodec.coerce(template, [[1, 2, 3], [4, 5, 6]]);
    check(converted != null && converted.length == 2, 'array kept');
    final firstRow:Array<Dynamic> = converted[0];
    check(number(firstRow[2]) == 3, 'array elements converted');
    check(SettingsBackupCodec.coerce(template, [[1, 2, 3]]) == null, 'short array rejected');
    check(SettingsBackupCodec.coerce(template, 'nope') == null, 'non-array rejected');

    // keyBinds import reuses the int coercion with a numeric template.
    check(SettingsBackupCodec.coerce(0, 65) == 65, 'key code kept');
    check(SettingsBackupCodec.coerce(0, 'A') == null, 'key name rejected');
  }

  /** A file from a newer build still imports, but says so. */
  static function warnsAboutNewerFormats():Void
  {
    final newer:String = '{"format": "phoenix-settings-backup", "formatVersion": 99, "settings": {"downScroll": true}}';
    final decoded = SettingsBackupCodec.decode(newer);
    check(decoded.error == null, 'newer backup still readable');
    check(decoded.formatVersion == 99, 'format version kept');
    check(decoded.warnings.length == 1, 'newer backup warns');
    check(field(decoded.settings, 'downScroll') == true, 'newer backup settings kept');
  }
}
