import backend.ClientPrefs;
import backend.MemoryLedger;
import backend.ModHealth;
import backend.Mods;
import backend.Paths;
import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import lime.utils.Assets as LimeAssets;
import openfl.media.Sound;
import openfl.utils.AssetType;
import openfl.utils.Assets as OpenFlAssets;
import sys.FileSystem;
import sys.io.File;

using StringTools;

/**
 * Executable behavioral & performance regression tests for `backend.Paths`
 * asset caching, mod-directory scoping, Sparrow/Packer/JSON atlas fast-paths,
 * 4-byte Ogg header validation, and OpenFL/Lime sound/bitmap cache eviction.
 *
 * Run with:
 *
 *     bash tests/haxe/run-asset-cache.sh
 */
class AssetCacheSpec
{
  static function check(ok:Bool, label:String):Void
  {
    if (!ok) throw 'AssetCacheSpec failed: ' + label;
  }

  static function legacyFormatToSongPath(path:String):String
  {
    var invalidChars = ~/[~&\\;:<>#]/;
    var hideChars = ~/[.,'"%?!]/;
    var step = invalidChars.split(path.replace(' ', '-')).join('-');
    return hideChars.split(step).join('').toLowerCase();
  }

  static function main():Void
  {
    Paths.setCurrentLevel('shared');

    // A registered difficulty-specific chart may have no loose desktop file
    // (e.g. it is embedded in a mobile asset library).
    OpenFlAssets.registerStubText('assets/data/packaged/events-hard.json', '{}');
    check(Paths.songEvents('Packaged', 'Hard') == 'packaged/events-hard', 'packaged difficulty events selected');
    check(Paths.songEvents('Packaged', 'Hard', true) == 'events-hard', 'packaged event chart basename selected');
    check(Paths.songEvents('Packaged', 'Easy') == 'packaged/events', 'missing difficulty events fall back');

    // 1. O(1) deduplication on repeated image hits + zero duplicate OpenFL cache retention.
    OpenFlAssets.registerStubImage('assets/images/alphabet.png', 256, 128);
    OpenFlAssets.registerStubText('assets/images/alphabet.xml', '<TextureAtlas/>');

    Paths.clearStoredMemory();
    final g1:FlxGraphic = Paths.image('alphabet');
    check(g1 != null, 'initial Paths.image("alphabet") returns graphic');
    check(OpenFlAssets.bitmapDecodeCount == 1, 'decoded once on cold load');
    check(!OpenFlAssets.cache.hasBitmapData('assets/images/alphabet.png'), 'no duplicate OpenFL bitmap cache retention');

    for (_ in 0...500)
    {
      final hit:FlxGraphic = Paths.image('alphabet');
      check(hit == g1, 'repeated Paths.image returns identical FlxGraphic');
    }
    check(OpenFlAssets.bitmapDecodeCount == 1, 'still decoded once after 500 hits');
    check(Paths.localTrackedAssets.length == 1, 'localTrackedAssets deduplicates repeated hits (got ' + Paths.localTrackedAssets.length + ')');

    // 2. External direct pushes to localTrackedAssets & dumpExclusions stay honored.
    OpenFlAssets.registerStubImage('assets/images/keepExternal.png', 32, 32);
    OpenFlAssets.registerStubImage('assets/images/evictMe.png', 32, 32);
    final gKeep = Paths.image('keepExternal');
    final gEvict = Paths.image('evictMe');
    check(gKeep != null && gEvict != null, 'loaded keepExternal and evictMe');

    Paths.clearStoredMemory();
    // Simulate a mod/HScript pushing directly onto the public array without calling Paths.image:
    Paths.localTrackedAssets.push(gKeep.key);
    Paths.clearUnusedMemory();
    check(Paths.currentTrackedAssets.exists(gKeep.key), 'externally pushed localTrackedAssets entry survives clearUnusedMemory');
    check(!Paths.currentTrackedAssets.exists(gEvict.key), 'unreferenced entry is evicted by clearUnusedMemory');
    check(gEvict.isDestroyed, 'evicted FlxGraphic is destroyed');

    // 3. Atlas loaders short-circuit via FlxAtlasFrames.findFrame without re-reading XML from disk.
    FileSystem.createDirectory('mods/ModAtlas/images');
    File.saveContent('mods/ModAtlas/images/hero.png', 'PNGDATA');
    File.saveContent('mods/ModAtlas/images/hero.xml', '<TextureAtlas imagePath="hero.png"/>');
    Mods.currentModDirectory = 'ModAtlas';
    Paths.invalidateAssetLookupCache();

    final a1:FlxAtlasFrames = Paths.getSparrowAtlas('hero');
    check(a1 != null, 'loaded modded Sparrow atlas');
    // Corrupt/delete the XML on disk after first parse: cached findFrame fast-path must NOT touch disk!
    FileSystem.deleteFile('mods/ModAtlas/images/hero.xml');
    final a2:FlxAtlasFrames = Paths.getSparrowAtlas('hero');
    check(a2 == a1, 'getSparrowAtlas hits cached FlxAtlasFrames without re-reading XML from disk');

    // 4. Cross-mod image isolation + ModsMenuState direct `mods/<pack>/pack.png` cacheBitmap support.
    OpenFlAssets.registerStubImage('assets/images/icons/icon-bf.png', 300, 150);
    FileSystem.createDirectory('mods/ModIconA/images/icons');
    File.saveContent('mods/ModIconA/images/icons/icon-bf.png', 'MOD_ICON_A');
    File.saveContent('mods/ModIconA/pack.png', 'PACK_PNG');

    Mods.currentModDirectory = '';
    final vanillaIcon:FlxGraphic = Paths.image('icons/icon-bf');
    Mods.currentModDirectory = 'ModIconA';
    final modIcon:FlxGraphic = Paths.image('icons/icon-bf');
    check(vanillaIcon != null && modIcon != null && vanillaIcon != modIcon, 'vanilla and mod icons do not collide');
    Mods.currentModDirectory = '';
    check(Paths.image('icons/icon-bf') == vanillaIcon, 'switching back to vanilla hits cached vanilla icon');

    final packBmp1:FlxGraphic = Paths.cacheBitmap(Paths.mods('ModIconA/pack.png'));
    final packBmp2:FlxGraphic = Paths.cacheBitmap(Paths.mods('ModIconA/pack.png'));
    check(packBmp1 != null && packBmp1 == packBmp2, 'ModsMenuState direct mods/<folder>/pack.png loads and caches');
    check(Paths.cacheBitmap(Paths.mods('ModIconA/missing-pack.png')) == null, 'missing direct mods/ bitmap returns null cleanly');

    // 5. Sound resolution memoization, 4-byte OggS validation, OpenFL sound cache eviction, and menu-music retention.
    OpenFlAssets.registerStubSound('songs:assets/songs/bopeebo/Inst.ogg', 400000);
    OpenFlAssets.registerStubSound('assets/music/freakyMenu-Default.ogg', 200000);
    ClientPrefs.daMenuMusic = 'Default';

    final menuSnd:Sound = Paths.music('freakyMenu-Default');
    final instSnd:Sound = Paths.inst('bopeebo');
    check(menuSnd != null && instSnd != null, 'loaded menu music and song Inst');
    final existsBeforeHits:Int = OpenFlAssets.existsCallCount;
    for (_ in 0...200)
    {
      check(Paths.inst('bopeebo') == instSnd, 'repeated Paths.inst returns cached Sound');
    }
    check(OpenFlAssets.existsCallCount == existsBeforeHits, 'sound cache hits perform zero OpenFlAssets.exists probes');

    // Evict song audio while keeping active menu theme:
    Paths.clearStoredMemory();
    Paths.clearUnusedMemory();
    check(!Paths.currentTrackedSounds.exists('assets/songs/bopeebo/Inst.ogg'), 'song Inst evicted from currentTrackedSounds');
    check(!OpenFlAssets.cache.hasSound('songs:assets/songs/bopeebo/Inst.ogg'), 'song Inst evicted from OpenFlAssets.cache');
    check(instSnd.closed, 'evicted stopped sound closed its PCM buffer');
    check(Paths.currentTrackedSounds.exists('assets/music/freakyMenu-Default.ogg'), 'active menu theme retained across clearUnusedMemory');
    check(!menuSnd.closed, 'active menu theme buffer stays open');

    // Mislabelled Ogg container is rejected via 4-byte magic check:
    FileSystem.createDirectory('mods/ModBadAudio/sounds');
    File.saveContent('mods/ModBadAudio/sounds/fake.ogg', 'ID3-not-an-ogg-stream');
    Mods.currentModDirectory = 'ModBadAudio';
    Paths.invalidateAssetLookupCache();
    var threwBadOgg:Bool = false;
    try
    {
      Paths.sound('fake');
    }
    catch (err:Dynamic)
    {
      threwBadOgg = Std.string(err).indexOf('OggS') >= 0;
    }
    check(threwBadOgg, 'invalid Ogg header is rejected');

    File.saveContent('mods/ModBadAudio/sounds/good.ogg', 'OggS-valid-stub-payload');
    final goodModSnd:Sound = Paths.sound('good');
    check(goodModSnd != null, 'valid OggS header loads cleanly');

    // 6. formatToSongPath matches the legacy dual-EReg implementation (including its
    // "only the first match is rewritten" quirk) across realistic and hostile input.
    // The expected strings below are the verified cpp output of the pre-optimization code.
    final cases:Array<Array<String>> = [
      ['Bopeebo', 'bopeebo'],
      ['Dad-Battle (Erect Remix) #1!', 'dad-battle-(erect-remix)--1'],
      ['Guns & Roses: Pt. 2?', 'guns---roses:-pt-2?'],
      ["100% 'Fresh' ~ <Test>\\Path;", "100-'fresh'---<test>\\path;"],
      ['   Multiple   Spaces   ', '---multiple---spaces---'],
      ['Bopeebo Erect', 'bopeebo-erect'],
      ['', ''],
      ['UPPER lower 123', 'upper-lower-123'],
      [null, '']
    ];
    for (pair in cases)
    {
      final sample:String = pair[0];
      final expected:String = pair[1];
      final actual:String = Paths.formatToSongPath(sample);
      check(actual == expected, 'formatToSongPath("$sample"): expected "$expected", got "$actual"');
      check(Paths.formatToSongPath(sample) == actual, 'formatToSongPath is stable & memoized for "$sample"');
      if (sample != null) check(actual == legacyFormatToSongPath(sample), 'legacy parity for "$sample"');
    }

    // 7. initNote(null) and initSplash(null) populate maps under resolved keys and prune on graphic destroy.
    Mods.currentModDirectory = '';
    Paths.invalidateAssetLookupCache();
    OpenFlAssets.registerStubImage('shared:assets/shared/images/noteskins/NOTE_assets.png', 512, 256);
    OpenFlAssets.registerStubText('shared:assets/shared/images/noteskins/NOTE_assets.xml', '<TextureAtlas/>');
    OpenFlAssets.registerStubImage('shared:assets/shared/images/noteSplashes/noteSplashes.png', 256, 256);
    OpenFlAssets.registerStubText('shared:assets/shared/images/noteSplashes/noteSplashes.xml', '<TextureAtlas/>');

    Paths.initDefaultSkin(null);
    Paths.initNote(null);
    Paths.initSplash(null);
    check(Paths.noteSkinFramesMap.exists(Paths.defaultSkin), 'initNote(null) stores under defaultSkin');
    check(Paths.splashSkinFramesMap.exists('noteSplashes/noteSplashes'), 'initSplash(null) stores under resolved splash skin key');

    final noteGraphic = Paths.noteSkinFramesMap.get(Paths.defaultSkin).parent;
    final splashGraphic = Paths.splashSkinFramesMap.get('noteSplashes/noteSplashes').parent;
    check(noteGraphic.useCount == 1 && splashGraphic.useCount == 1, 'template sprites own their graphics');
    final liveNote = new flixel.FlxSprite();
    liveNote.frames = Paths.noteSkinFramesMap.get(Paths.defaultSkin);

    // A trim disposes the template owners even when a live sprite still uses
    // the atlas. The live sprite protects it until its own destruction.
    Paths.clearStoredMemory();
    Paths.clearUnusedMemory();
    check(noteGraphic.useCount == 1 && !noteGraphic.isDestroyed, 'live note protects its atlas after template release');
    check(splashGraphic.isDestroyed, 'unused splash template no longer pins its atlas');
    check(!Paths.noteSkinFramesMap.exists(Paths.defaultSkin), 'trim prunes the noteskin templates');
    check(!Paths.splashSkinFramesMap.exists('noteSplashes/noteSplashes'), 'trim prunes the splash templates');
    liveNote.destroy();
    Paths.clearUnusedMemory();
    check(noteGraphic.isDestroyed, 'released note atlas is reclaimed by the next trim');

    // Explicit teardown releases templates even if public maps were cleared.
    Paths.initNote(null);
    final teardownGraphic = Paths.noteSkinFramesMap.get(Paths.defaultSkin).parent;
    Paths.noteSkinFramesMap.clear();
    Paths.noteSkinAnimsMap.clear();
    Paths.clearSkinCaches();
    check(teardownGraphic.useCount == 0, 'teardown destroys orphaned template sprites');
    Paths.clearStoredMemory();
    Paths.clearUnusedMemory();
    check(teardownGraphic.isDestroyed, 'teardown leaves the atlas evictable');

    // 8. Request-based tracking is not a live-reference count. A deep trim
    // must not destroy graphics still held by sprites or paused FlxSounds.
    OpenFlAssets.registerStubImage('assets/images/live.png', 64, 64);
    final live = Paths.image('live');
    live.useCount = 1;
    final generated = FlxGraphic.fromBitmapData(new openfl.display.BitmapData(8, 8), false, 'generated-live');
    generated.useCount = 1;
    final paused = new Sound();
    final pausedFlx = new flixel.sound.FlxSound();
    pausedFlx._sound = paused;
    pausedFlx.playing = false;
    FlxG.sound.list.members.push(pausedFlx);
    Paths.currentTrackedSounds.set('paused-sound', paused);

    final songStream = new Sound();
    final music = new flixel.sound.FlxSound();
    music._sound = songStream;
    music.playing = false; // persistent music can be resumed after a transition
    FlxG.sound.music = music;
    Paths.currentTrackedSounds.set('stream-music', songStream);
    @:privateAccess Paths.streamSoundKeys.set('stream-music', true);

    final externalStream = new Sound();
    Paths.currentTrackedSounds.set('stream-external', externalStream);
    @:privateAccess Paths.streamSoundKeys.set('stream-external', true);
    Paths.clearStoredMemory();
    Paths.clearUnusedMemory();
    check(!live.isDestroyed && Paths.currentTrackedAssets.exists(live.key), 'live tracked graphic survives a deep trim');
    check(!generated.isDestroyed, 'live generated graphic survives a deep trim');
    check(!paused.closed && Paths.currentTrackedSounds.exists('paused-sound'), 'paused list sound stays resumable');
    check(!songStream.closed && Paths.currentTrackedSounds.exists('stream-music'), 'stopped persistent music stays resumable');
    check(!externalStream.closed && !Paths.currentTrackedSounds.exists('stream-external'),
      'an unlisted stream is untracked without closing a mod-retained Sound');

    live.useCount = generated.useCount = 0;
    FlxG.sound.list.members = [];
    FlxG.sound.music = null;
    Paths.clearStoredMemory();
    Paths.clearUnusedMemory();
    check(live.isDestroyed && generated.isDestroyed, 'released graphics are reclaimed on a later trim');
    check(paused.closed, 'decoded sound is closed after its FlxSound releases it');
    check(!songStream.closed && !Paths.currentTrackedSounds.exists('stream-music'),
      'released stream is untracked without invalidating retained Sound references');

    // 9. Ledger returns to zero engine/mod assets once everything non-excluded is cleared.
    Paths.dumpExclusions.resize(0);
    ClientPrefs.daMenuMusic = 'None';
    Paths.clearStoredMemory();
    Paths.clearUnusedMemory();
    final snap = MemoryLedger.snapshot(1000000, 2000000);
    check(snap.engineAssets.count == 0 && snap.modAssets.count == 0,
      'MemoryLedger returns to 0 tracked assets after full eviction (eng=' + snap.engineAssets.count + ', mod=' + snap.modAssets.count + ')');

    // 10. A mod asset that does not exist is counted for that mod, so the Mods menu
    //     can report it (§19), while engine and shared misses are not.
    ModHealth.clear();
    check(Paths.image('definitely-not-here') == null, 'a missing engine image still returns null');
    check(ModHealth.missingAssets('SomeMod') == 0, 'an engine miss blames no mod');
    final missingModKey = Paths.mods('SomeMod/images/definitely-not-here.png');
    check(!FileSystem.exists(missingModKey), 'the fixture asset really is absent');
    check(Paths.cacheBitmap(missingModKey) == null, 'a missing mod image returns null');
    Paths.cacheBitmap(missingModKey);
    check(ModHealth.missingAssets('SomeMod') == 1, 'the miss is counted once for its mod');
    check(ModHealth.report('SomeMod').missingList[0] == 'images/definitely-not-here.png',
      'the key is listed relative to the mod folder: ' + ModHealth.report('SomeMod').missingList.join(','));
    check(ModHealth.summary('SomeMod') == 'PROBLEMS: 1 missing asset', 'the menu line follows: ' + ModHealth.summary('SomeMod'));
    Paths.cacheBitmap(Paths.mods('images/shared-missing.png'));
    check(ModHealth.missingAssets('images') == 0, 'a loose shared asset under mods/ blames no mod');
    ModHealth.clear();

    Sys.println('AssetCacheSpec: all checks passed');
  }
}
