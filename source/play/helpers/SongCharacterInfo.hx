package play.helpers;

import backend.Paths;
import backend.XmlDefinitions;
import haxe.Json;

/** Character properties that remain useful when artwork is intentionally skipped. */
typedef SongCharacterProperties =
{
  var vocalsFile:String;
  var noteskin:String;
  var healthDrain:Bool;
  var drainAmount:Float;
  var drainFloor:Float;
  var healthIcon:String;
  var healthColors:Array<Int>;
};

/**
 * Reads only character JSON for the experimental HUD-only mode. In particular,
 * do not create an atlas or run character scripts here: the small stand-in
 * still needs the right vocal stem and health-drain behavior without loading
 * the character's potentially enormous sprite sheet.
 */
class SongCharacterInfo
{
  public static function load(name:String, fallback:String):SongCharacterProperties
  {
    // Use the same resolution and built-in fallback as full Character loading.
    var text:String = null;
    try text = Paths.characterFileText(name, fallback) catch (_:Dynamic) {}
    return decode(text);
  }

  /** Invalid/missing metadata falls back to the engine's neutral values. */
  public static function decode(text:String):SongCharacterProperties
  {
    var json:Dynamic = null;
    try
    {
      if (text != null) json = Json.parse(text);
    }
    catch (_:Dynamic)
    {
      // Not JSON: it may be an XML character definition instead.
      try if (text != null) json = cast XmlDefinitions.parseCharacter(text)
      catch (_:Dynamic) {}
    }
    final colors:Dynamic = field(json, 'healthbar_colors');
    var healthColors:Array<Int> = [255, 0, 0];
    if (Std.isOfType(colors, Array))
    {
      final values:Array<Dynamic> = cast colors;
      if (values.length >= 3 && isNumber(values[0]) && isNumber(values[1]) && isNumber(values[2]))
        healthColors = [Std.int(values[0]), Std.int(values[1]), Std.int(values[2])];
    }
    return {
      vocalsFile: stringField(json, 'vocals_file', ''),
      noteskin: stringField(json, 'noteskin', ''),
      healthDrain: field(json, 'health_drain') == true,
      drainAmount: numberField(json, 'drain_amount'),
      drainFloor: numberField(json, 'drain_floor'),
      healthIcon: stringField(json, 'healthicon', 'face'),
      healthColors: healthColors
    };
  }

  static inline function field(object:Dynamic, name:String):Dynamic
    return object != null ? Reflect.field(object, name) : null;

  static function stringField(object:Dynamic, name:String, fallback:String):String
  {
    final value:Dynamic = field(object, name);
    return Std.isOfType(value, String) ? cast value : fallback;
  }

  static function isNumber(value:Dynamic):Bool
    return Std.isOfType(value, Int) || Std.isOfType(value, Float);

  static function numberField(object:Dynamic, name:String):Float
  {
    final value:Dynamic = field(object, name);
    if (!isNumber(value)) return 0;
    final number:Float = value;
    return Math.isFinite(number) ? number : 0;
  }
}
