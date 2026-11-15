import backend.Paths;
import play.helpers.SongCharacterInfo;
import openfl.utils.Assets as OpenFlAssets;
#if MODS_ALLOWED
import backend.Mods;
import sys.FileSystem;
import sys.io.File;
#end

/** Verifies the production character lookup used by both rendering paths. */
class CharacterPathSpec
{
  static function equal(actual:Dynamic, expected:Dynamic, message:String):Void
  {
    if (actual != expected) throw message + ': expected ' + Std.string(expected) + ', got ' + Std.string(actual);
  }

  static function main():Void
  {
    Paths.setCurrentLevel('week-test');
    #if MODS_ALLOWED
    FileSystem.createDirectory('assets/characters');
    FileSystem.createDirectory('assets/shared/characters');
    FileSystem.createDirectory('mods/Test/characters');
    FileSystem.createDirectory('mods/Global/characters');
    File.saveContent('assets/characters/bf.json', '{"vocals_file":"built-in-bf"}');
    File.saveContent('assets/characters/hero.json', '{"vocals_file":"built-in-hero"}');
    File.saveContent('assets/shared/characters/level-only.json', '{"vocals_file":"shared"}');
    File.saveContent('mods/Global/characters/hero.json', '{"vocals_file":"global-hero"}');
    File.saveContent('mods/Test/characters/hero.json', '{"vocals_file":"mod-hero"}');
    File.saveContent('mods/Test/characters/bf.json', '{"vocals_file":"mod-bf"}');
    File.saveContent('mods/Test/characters/broken.json', 'not json');
    Mods.currentModDirectory = 'Test';
    Mods.globalMods = ['Global'];

    equal(SongCharacterInfo.load('hero', 'bf').vocalsFile, 'mod-hero', 'active mod beats global and built-in');
    equal(SongCharacterInfo.load('bf', 'bf').vocalsFile, 'mod-bf', 'an explicitly requested BF uses the mod');
    equal(SongCharacterInfo.load('missing', 'bf').vocalsFile, 'built-in-bf', 'missing character falls back to built-in BF');
    equal(SongCharacterInfo.load('level-only', 'bf').vocalsFile, 'built-in-bf', 'shared-level JSON does not mask fallback');
    equal(SongCharacterInfo.load('broken', 'bf').vocalsFile, '', 'invalid selected JSON does not silently choose a different character');
    FileSystem.deleteFile('mods/Test/characters/hero.json');
    equal(SongCharacterInfo.load('hero', 'bf').vocalsFile, 'global-hero', 'global mod is the next choice');
    Mods.globalMods = [];
    equal(SongCharacterInfo.load('hero', 'bf').vocalsFile, 'built-in-hero', 'built-in character follows mods');
    FileSystem.deleteFile('assets/characters/bf.json');
    equal(Paths.characterFileText('missing', 'bf'), null, 'missing default returns null, not a mod fallback');
    #else
    OpenFlAssets.registerStubText('assets/characters/bf.json', '{"vocals_file":"built-in-bf"}');
    OpenFlAssets.registerStubText('assets/characters/hero.json', '{"vocals_file":"built-in-hero"}');
    OpenFlAssets.registerStubText('shared:assets/shared/characters/level-only.json', '{"vocals_file":"shared"}');
    OpenFlAssets.registerStubText('assets/characters/broken.json', 'not json');
    equal(SongCharacterInfo.load('hero', 'bf').vocalsFile, 'built-in-hero', 'registered built-in is read');
    equal(SongCharacterInfo.load('missing', 'bf').vocalsFile, 'built-in-bf', 'missing character uses built-in fallback');
    equal(SongCharacterInfo.load('level-only', 'bf').vocalsFile, 'built-in-bf', 'shared-level JSON does not mask fallback');
    equal(SongCharacterInfo.load('broken', 'bf').vocalsFile, '', 'invalid selected JSON uses neutral metadata');
    equal(Paths.characterFileText('missing', 'also-missing'), null, 'missing fallback returns null');
    #end
    trace('CharacterPathSpec passed');
  }
}
