import backend.Paths;
import play.helpers.SongCharacterInfo;

class SongCharacterInfoSpec
{
  static function check(value:Bool, message:String):Void { if (!value) throw message; }
  static function equal(actual:Dynamic, expected:Dynamic, message:String):Void
  {
    if (actual != expected) throw message + ': expected ' + Std.string(expected) + ', got ' + Std.string(actual);
  }

  static function main():Void
  {
    Paths.files.set('characters/bf.json', '{"vocals_file":"bf","noteskin":null,"healthicon":"bf"}');
    Paths.files.set('characters/mod-dad.json', '{"vocals_file":"rival","noteskin":"custom","health_drain":true,'
      + '"drain_amount":0.03,"drain_floor":0.2,"healthicon":"rival-icon","healthbar_colors":[4,5,6],'
      + '"image":"very-large-atlas","animations":[{"anim":"idle"}]}');

    final info = SongCharacterInfo.load('mod-dad', 'bf');
    equal(info.vocalsFile, 'rival', 'character-specific stem is retained');
    equal(info.noteskin, 'custom', 'custom noteskin is retained');
    check(info.healthDrain && info.drainAmount == 0.03 && info.drainFloor == 0.2, 'health drain metadata is retained');
    equal(info.healthIcon, 'rival-icon', 'health icon is retained');
    equal(info.healthColors.join(','), '4,5,6', 'health bar colors are retained');
    equal(Paths.reads.join(','), 'characters/mod-dad.json', 'no atlas or fallback loaded for an existing character');

    Paths.reads = [];
    final fallback = SongCharacterInfo.load('missing', 'bf');
    equal(fallback.vocalsFile, 'bf', 'missing character uses the default metadata');
    equal(fallback.noteskin, '', 'null noteskin becomes default');
    equal(Paths.reads.join(','), 'characters/missing.json,characters/bf.json', 'fallback lookup order');

    final bad = SongCharacterInfo.decode('{"vocals_file":5,"noteskin":false,"health_drain":"true",'
      + '"drain_amount":{},"healthbar_colors":[1,null,3],"healthicon":null}');
    equal(bad.vocalsFile, '', 'invalid vocal metadata is ignored');
    equal(bad.noteskin, '', 'invalid skin metadata is ignored');
    check(!bad.healthDrain && bad.drainAmount == 0, 'invalid gameplay metadata is neutral');
    equal(bad.healthIcon, 'face', 'invalid icon falls back');
    equal(bad.healthColors.join(','), '255,0,0', 'invalid colors fall back');
    equal(SongCharacterInfo.decode('not json').vocalsFile, '', 'invalid JSON is nonfatal');
    equal(SongCharacterInfo.decode(null).vocalsFile, '', 'missing JSON is nonfatal');
    trace('SongCharacterInfoSpec passed');
  }
}
