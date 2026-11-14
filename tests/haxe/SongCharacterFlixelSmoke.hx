import backend.Paths;
import objects.Character;
import objects.Character.Boyfriend;

/** Real Character and Flixel/OpenFL, with only engine dependencies stubbed. */
class SongCharacterFlixelSmoke
{
  static function check(value:Bool, message:String):Void
  {
    if (!value) throw 'SongCharacterFlixelSmoke: ' + message;
  }

  static function main():Void
  {
    Paths.files.set('characters/dad.json', '{"vocals_file":"dad-voice","health_drain":true,'
      + '"drain_amount":0.05,"drain_floor":0.1}');
    Paths.files.set('characters/bf.json', '{"vocals_file":"bf-voice","noteskin":"custom"}');
    Paths.files.set('characters/pico-speaker.json', '{"vocals_file":"speaker"}');

    final dad = new Character(0, 0, 'dad', false, false, true);
    final bf = new Boyfriend(0, 0, 'bf', true);
    final speaker = new Character(0, 0, 'pico-speaker', false, false, true);
    check(dad.vocalsFile == 'dad-voice' && dad.healthDrain && dad.drainAmount == 0.05 && dad.drainFloor == 0.1,
      'opponent retains vocal and health metadata');
    check(bf.vocalsFile == 'bf-voice' && bf.noteskin == 'custom', 'player retains vocal and noteskin metadata');
    check(speaker.vocalsFile == 'speaker', 'special character metadata loads without mapped animations');
    check(dad.width == 1 && bf.width == 1 && speaker.width == 1, 'each stand-in uses a one-pixel graphic');
    check(dad.animation.getByName('singLEFT') != null && bf.animation.getByName('idle') != null,
      'stand-ins expose safe placeholder animations');
    check(Paths.atlasCalls == 0, 'metadata-only construction never loads a character atlas');
    dad.destroy();
    bf.destroy();
    speaker.destroy();
    trace('SongCharacterFlixelSmoke passed');
  }
}
