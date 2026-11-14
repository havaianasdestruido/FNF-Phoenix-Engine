import backend.ClientPrefs;
import backend.LowMemory;
import backend.MemoryProfiles;
import backend.Paths;
import backend.PlayerSettings;
import data.Song;
import debug.PoolStats;
import flixel.FlxG;
import flixel.FlxGame;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.addons.transition.FlxTransitionableState;
import lime.utils.AssetLibrary;
import lime.utils.AssetType;
import objects.Note;
import objects.StrumNote;
import openfl.Lib;
import play.PlayState;
import play.helpers.CharacterNoteSkin;
import play.helpers.PlayStateNoteHelpers;
import play.helpers.PlayStateNotes;
import play.helpers.PlayStatePlayback;
import states.LoadingState;
import sys.FileSystem;
import sys.io.File;

/** Empty destination so the production PlayState can be created and destroyed. */
class MemorySmokeMenu extends FlxState {}

/**
 * Optional Linux/Neko integration smoke using the real PlayState, assets,
 * Flixel/OpenFL/Lime, dummy SDL video and OpenAL's null audio driver. The
 * runner supplies a temporary FlxBar initialization shim for Neko and does not
 * enable the optional Lua/Python/HScript libraries. This is not a device,
 * hardware GPU or audible-audio test.
 */
class PlayStateMemoryFlixelSmoke
{
  static function check(ok:Bool, message:String):Void
  {
    if (!ok) throw 'PlayStateMemoryFlixelSmoke: ' + message;
  }

  static function registerFiles(library:AssetLibrary, real:String, key:String):Void
  {
    if (!FileSystem.exists(real)) return;
    for (entry in FileSystem.readDirectory(real))
    {
      final path = real + '/' + entry;
      final id = key + '/' + entry;
      if (FileSystem.isDirectory(path)) registerFiles(library, path, id);
      else
      {
        final ext = entry.toLowerCase().split('.').pop();
        final type:AssetType = switch (ext)
        {
          case 'png' | 'jpg' | 'jpeg' | 'webp': IMAGE;
          case 'ogg' | 'mp3' | 'wav': SOUND;
          case 'ttf' | 'otf': FONT;
          default: TEXT;
        };
        @:privateAccess library.paths.set(id, path);
        @:privateAccess library.types.set(id, type);
      }
    }
  }

  static function registerAssets():Void
  {
    final defaults = new AssetLibrary();
    for (dir in ['characters', 'data', 'images', 'music', 'sounds', 'stages', 'weeks', 'fonts'])
      registerFiles(defaults, 'assets/' + dir, 'assets/' + dir);
    registerFiles(defaults, Sys.getEnv('FLIXEL_PATH') + '/assets/fonts', 'flixel/fonts');
    registerFiles(defaults, Sys.getEnv('FLIXEL_UI_PATH') + '/assets/images', 'flixel/flixel-ui/img');
    registerFiles(defaults, Sys.getEnv('FLIXEL_UI_PATH') + '/assets/xml', 'flixel/flixel-ui/xml');
    lime.utils.Assets.registerLibrary('default', defaults);

    final shared = new AssetLibrary();
    registerFiles(shared, 'assets/shared', 'assets/shared');
    lime.utils.Assets.registerLibrary('shared', shared);
    final songs = new AssetLibrary();
    registerFiles(songs, 'assets/songs', 'assets/songs');
    lime.utils.Assets.registerLibrary('songs', songs);
    for (week in ['week2', 'week3', 'week4', 'week5', 'week6', 'week7', 'weekend1'])
    {
      final library = new AssetLibrary();
      registerFiles(library, 'assets/' + week, 'assets/' + week);
      lime.utils.Assets.registerLibrary(week, library);
    }
  }

  static function checkSkinCache():Void
  {
    Paths.initDefaultSkin(null);
    Paths.initNote(null);
    Paths.initSplash(null);
    final noteFrames = Paths.noteSkinFramesMap.get(Paths.defaultSkin);
    final splashFrames = Paths.splashSkinFramesMap.get('noteSplashes/noteSplashes');
    check(noteFrames != null && splashFrames != null, 'real note and splash atlases load');
    final noteGraphic = noteFrames.parent;
    final splashGraphic = splashFrames.parent;
    check(noteGraphic.useCount == 1 && splashGraphic.useCount == 1, 'template sprites own their atlases');

    final live = new FlxSprite();
    live.frames = noteFrames;
    live.animation.copyFrom(Paths.noteSkinAnimsMap.get(Paths.defaultSkin));
    check(live.animation.getByName('purpleScroll') != null, 'cached animations copy to a live sprite');
    Paths.clearStoredMemory();
    Paths.clearUnusedMemory();
    check(!noteGraphic.isDestroyed && noteGraphic.useCount == 1, 'live sprite retains the atlas after trim');
    check(splashGraphic.isDestroyed, 'unused splash template is released');
    check(!Paths.noteSkinFramesMap.exists(Paths.defaultSkin), 'note template map is pruned');
    check(live.animation.getByName('purpleScroll') != null, 'copied animations survive template release');
    live.destroy();
    Paths.clearUnusedMemory();
    check(noteGraphic.isDestroyed, 'released atlas is evicted on the next trim');
  }

  static function checkStrumSkins():Void
  {
    PlayState.SONG = Song.dummySong('test');
    PlayState.SONG.arrowSkin = 'noteskins/NOTE_assets-classic';
    PlayState.isPixelStage = false;
    ClientPrefs.noteSkin = 'Default';
    final strum = new StrumNote(0, 0, 0, 0);
    check(strum.texture == 'noteskins/NOTE_assets-classic', 'normal chart skin');
    strum.updateNoteSkin('NOTE_assets-chip');
    check(strum.texture == 'noteskins/NOTE_assets-chip', 'normal character skin');
    strum.updateNoteSkin(null);
    check(strum.texture == 'noteskins/NOTE_assets-classic', 'normal chart skin restored');
    strum.destroy();

    PlayState.isPixelStage = true;
    PlayState.SONG.arrowSkin = '';
    ClientPrefs.noteSkin = 'Future';
    final pixel = new StrumNote(0, 0, 0, 0);
    check(pixel.texture == 'noteskins/NOTE_assets-future', 'pixel style checks the pixelUI path');
    check(CharacterNoteSkin.resolve('NOTE_assets-classic', true) == '', 'normal-only atlas is rejected on a pixel stage');
    check(CharacterNoteSkin.resolve('NOTE_assets', true) == 'NOTE_assets', 'complete pixel skin is accepted');
    pixel.updateNoteSkin('NOTE_assets');
    check(pixel.texture == 'noteskins/NOTE_assets', 'pixel character skin');
    pixel.updateNoteSkin('');
    check(pixel.texture == 'noteskins/NOTE_assets-future', 'pixel chart skin restored');
    pixel.destroy();
    PlayState.isPixelStage = false;
    ClientPrefs.noteSkin = 'Default';
  }

  static function main():Void
  {
    #if android
    // The Android-defined --no-output check also reaches the pressure bridge.
    android.platform.AndroidPlatform.init(false, false);
    #end
    final app = new openfl.display.Application();
    app.meta['file'] = 'phoenix-headless-test';
    app.meta['company'] = 'test';
    app.meta['name'] = 'phoenix-headless-test';
    app.createWindow({width: 1280, height: 720, hidden: true, context: {hardware: false, type: CAIRO}});
    registerAssets();
    check(lime.utils.Assets.exists('assets/characters/bf.json'), 'built-in character JSON is registered');

    final game = new FlxGame(1280, 720, MemorySmokeMenu.new, 60, 60, true);
    Lib.current.addChild(game);
    ClientPrefs.loadDefaultStuff();
    PlayerSettings.init();
    backend.CoolUtil.difficulties = ['Easy', 'Normal', 'Hard'];
    Paths.setCurrentLevel('shared');
    checkSkinCache();
    checkStrumSkins();

    LowMemory.setProfile(MemoryProfiles.EXPERIMENTAL, false);
    final pixelSong = Sys.args().indexOf('pixel') >= 0;
    final completePixelSkin = Sys.args().indexOf('complete-pixel-skin') >= 0;
    if (completePixelSkin) ClientPrefs.noteSkin = 'Future';
    final song = pixelSong ? 'senpai' : 'bopeebo';
    #if MODS_ALLOWED
    if (pixelSong)
    {
      // One case provides only a regular Sparrow skin; another supplies both
      // pixel sheets so real heads and sustains can exercise the custom skin.
      FileSystem.createDirectory('mods/characters');
      final data:Dynamic = haxe.Json.parse(File.getContent('assets/characters/bf-pixel.json'));
      data.noteskin = completePixelSkin ? 'smoke-pixel' : 'NOTE_assets-classic';
      File.saveContent('mods/characters/bf-pixel.json', haxe.Json.stringify(data));
      if (completePixelSkin)
      {
        FileSystem.createDirectory('mods/images/pixelUI/noteskins');
        File.copy('assets/shared/images/pixelUI/noteskins/NOTE_assets.png', 'mods/images/pixelUI/noteskins/smoke-pixel.png');
        File.copy('assets/shared/images/pixelUI/noteskins/NOTE_assetsENDS.png', 'mods/images/pixelUI/noteskins/smoke-pixelENDS.png');
        // Only the head has a global-style variant. Character notes should
        // use the same exact skin as their receptor, not a half-present variant.
        File.copy('assets/shared/images/pixelUI/noteskins/NOTE_assets-future.png', 'mods/images/pixelUI/noteskins/smoke-pixel-future.png');
      }
      Paths.invalidateAssetLookupCache();
    }
    #end
    #if MODS_ALLOWED
    if (!pixelSong)
    {
      // Use the temporary mod directory, never the symlinked repository
      // assets, for a real difficulty-specific external event chart.
      FileSystem.createDirectory('mods/data/bopeebo');
      File.saveContent('mods/data/bopeebo/events-normal.json',
        '{"song":{"song":"Bopeebo","notes":[],"events":[[1100,[["Change Character","bf","pico"]]]]}}');
    }
    #end
    PlayState.SONG = Song.loadFromJson(song, song);
    PlayState.SONG.events.push([1000, [['Change Character', '1', 'gf']]]);
    var constructed:Int = 0;
    FlxTransitionableState.skipNextTransIn = true;
    LoadingState.loadAndSwitchState(() -> {
      constructed++;
      final instance = new PlayState();
      instance.ratingPercent = 0; // Neko does not zero-initialize this unassigned Float like C++.
      return instance;
    });
    check(constructed == 0, 'song factory is deferred until the old state is destroyed');
    @:privateAccess game.switchState();
    check(Std.isOfType(FlxG.state, LoadingState) && constructed == 1, 'real loading state previews the song once');
    final loader:LoadingState = cast FlxG.state;
    check(@:privateAccess loader.preloadQueue.length == 0, 'experimental song queue contains no speculative work');
    @:privateAccess loader.changeBarSize(1);
    FlxTransitionableState.skipNextTransIn = true;
    FlxTransitionableState.skipNextTransOut = true;
    @:privateAccess loader.update(1 / 60);
    @:privateAccess game.switchState();
    check(Std.isOfType(FlxG.state, PlayState) && constructed == 1, 'real PlayState created from the preview');
    var state:PlayState = cast FlxG.state;
    check(state.dad.width == 1 && state.boyfriend.width == 1 && state.gf.width == 1, 'tiny metadata characters');
    check(!state.songCharacterVisuals && state.metadataOnlyCharacters, 'song latches metadata-only mode');
    check(!state.dadGroup.visible && !state.boyfriendGroup.visible && !state.gfGroup.visible, 'character groups are invisible');
    check(PlayState.curStage == '' && PlayState.isPixelStage == pixelSong, 'stage visuals suppressed but pixel metadata retained');
    check(state.grpNoteSplashes.length == 0 && state.grpHoldSplashes.length == 0, 'disabled splashes are not warmed');
    #if MODS_ALLOWED
    if (!pixelSong)
    {
      var foundExternal = false;
      for (event in state.eventNotes)
        if (event.event == 'Change Character' && event.value2 == 'pico') foundExternal = true;
      check(foundExternal && state.boyfriendMap.exists('pico'), 'difficulty-specific external character event is loaded and precached');
    }
    #end
    if (pixelSong)
    {
      check(PlayState.SONG.stage == 'school' && state.gf.curCharacter == 'gf-pixel', 'pixel stage and GF fallback preserved');
      check(!Paths.noteSkinFramesMap.exists(Paths.defaultSkin), 'experimental pixel song does not warm the unused normal atlas');
      check(state.bfNoteskin == (completePixelSkin ? 'smoke-pixel' : ''),
        'pixel BF skin is retained only when its sheets are complete');
    }
    check(@:privateAccess state.inst._sound != null, 'instrumental loaded');
    check(@:privateAccess state.inst._sound.__buffer.__srcVorbisFile != null, 'instrumental uses a Vorbis stream');
    check(@:privateAccess state.vocals._sound != null, 'vocals loaded');
    state.triggerEventNote('Change Character', '1', 'gf', 1000);
    check(state.dad.curCharacter == 'gf' && state.dad.width == 1 && !state.dadGroup.visible, 'real opponent event changes an invisible stand-in');
    final nextGf = pixelSong ? 'gf' : 'gf-pixel';
    state.triggerEventNote('Change Character', '2', nextGf, 1000);
    check(state.gf.curCharacter == nextGf && !state.gfGroup.visible, 'real GF event changes an invisible stand-in');

    var chartNote = state.unspawnNotes[0];
    if (pixelSong)
      for (candidate in state.unspawnNotes)
        if (candidate.mustPress && !candidate.isSustainNote) { chartNote = candidate; break; }
    if (pixelSong) check(chartNote.noteskin == (completePixelSkin ? 'smoke-pixel' : ''),
      'pixel chart note uses the resolved character or fallback skin');

    // Stages can hide GF. Skipped GF "Hey!" notes must not dereference a
    // missing character in either player or opponent handling.
    final heyNote:objects.Note.PreloadedChartNote = cast Reflect.copy(chartNote);
    heyNote.gfNote = true;
    heyNote.noteType = 'Hey!';
    final savedGf = state.gf;
    state.gf = null;
    PlayStateNotes.goodNoteHit(state, null, heyNote);
    PlayStateNotes.opponentNoteHit(state, null, heyNote);
    final liveHey = new Note(0, 0);
    liveHey.setupNoteData(heyNote);
    PlayStateNotes.opponentNoteHit(state, liveHey);
    PlayStateNoteHelpers.destroyNotes(state);
    liveHey.destroy();
    state.gf = savedGf;

    if (completePixelSkin)
    {
      check(state.playerStrums.length == 4 && state.playerStrums.members[0].texture == 'noteskins/smoke-pixel',
        'pixel receptor uses the exact character skin');
      final head = new Note(0, chartNote.noteData);
      head.setupNoteData(chartNote);
      check(head.graphic == Paths.image('pixelUI/noteskins/smoke-pixel') && head.animation.curAnim != null,
        'pixel character skin loads on a real head');
      final sustainData:objects.Note.PreloadedChartNote = cast Reflect.copy(chartNote);
      sustainData.isSustainNote = true;
      sustainData.isSustainEnd = true;
      final sustain = new Note(0, chartNote.noteData);
      sustain.setupNoteData(sustainData);
      check(sustain.graphic == Paths.image('pixelUI/noteskins/smoke-pixelENDS') && sustain.animation.curAnim != null,
        'pixel character skin loads on a real sustain');
      head.destroy();
      sustain.destroy();
    }
    PoolStats.reset();
    final note = new Note(0, 0);
    state.notes.add(note);
    note.setupNoteData(chartNote);
    note.strumTime = 100;
    PoolStats.spawn(PoolStats.NOTE, false);
    check(note.graphic != null && note.animation.curAnim != null, 'real chart note loads and animates');
    var graphic = note.graphic;
    final later = new Note(0, 0);
    state.notes.add(later);
    later.setupNoteData(chartNote);
    later.strumTime = 3000;
    PoolStats.spawn(PoolStats.NOTE, false);
    final before = graphic.useCount;
    PlayStateNoteHelpers.invalidateNote(state, note);
    PlayStateNoteHelpers.invalidateNote(state, later);
    PlayStateNoteHelpers.clearNotesBefore(state, 1000);
    check(note.graphic == null && graphic.useCount == before - 1, 'seek destroys the early note and releases its graphic');
    check(state.killNotes.length == 1 && state.killNotes[0] == later, 'seek removes only retired entries from the kill queue');
    PlayStateNoteHelpers.invalidateNote(state, note); // a script may still hold the destroyed note
    check(state.killNotes.length == 1, 'destroyed script-held notes cannot be queued again');
    PlayStateNoteHelpers.destroyNotes(state);
    check(!later.exists && PoolStats.releasedCount(PoolStats.NOTE) == 2, 'remaining queued note returns to the pool once');
    PlayStateNoteHelpers.KillNotes(state);
    check(state.notes.length == 0 && state.killNotes.length == 0 && graphic.useCount == before - 2,
      'destructive reset clears pooled notes and their graphics');
    check(PoolStats.releasedCount(PoolStats.NOTE) == 2, 'already pooled notes are not counted twice');

    final queued = new Note(0, 0);
    state.notes.add(queued);
    queued.setupNoteData(chartNote);
    PoolStats.spawn(PoolStats.NOTE, false);
    PlayStateNoteHelpers.invalidateNote(state, queued);
    PlayStateNoteHelpers.KillNotes(state);
    PlayStateNoteHelpers.invalidateNote(state, queued);
    PlayStateNoteHelpers.destroyNotes(state);
    check(state.killNotes.length == 0 && PoolStats.releasedCount(PoolStats.NOTE) == 3,
      'KillNotes clears pending references and cannot double-release a script-held note');

    @:privateAccess state.songLength = state.inst.length;
    PlayStatePlayback.startSong(state);
    check(FlxG.sound.music.playing, 'streamed instrumental starts');
    FlxG.sound.music.pause();
    check(!FlxG.sound.music.playing, 'instrumental pauses');
    FlxG.sound.music.play();
    PlayStatePlayback.setSongTime(state, 1000);
    check(FlxG.sound.music.time > 900, 'instrumental seeks');
    var originalSongSound = @:privateAccess FlxG.sound.music._sound;
    final profileOff = Sys.args().indexOf('profile-off') >= 0;
    final restart = Sys.args().indexOf('restart') >= 0;
    if (profileOff)
    {
      LowMemory.setProfile(MemoryProfiles.OFF, false);
      check(ClientPrefs.charsAndBG, 'leaving the profile restores the previous character preference');
      state.triggerEventNote('Change Character', '0', 'pico', 2000);
      check(state.boyfriend.curCharacter == 'pico' && state.boyfriend.width == 1 && !state.boyfriendGroup.visible,
        'profile changes do not load full characters halfway through a metadata-only song');
      final placeholderAnimation = state.boyfriend.getAnimationName();
      state.triggerEventNote('Play Animation', 'singLEFT', 'boyfriend', 2000);
      check(!state.songCharacterVisuals && state.boyfriend.getAnimationName() == placeholderAnimation,
        'restoring the preference does not start animating hidden stand-ins mid-song');
    }
    if (restart)
    {
      final oldState = state;
      final oldSound = originalSongSound;
      final oldGraphic = graphic;
      FlxTransitionableState.skipNextTransIn = true;
      FlxTransitionableState.skipNextTransOut = true;
      FlxG.resetState();
      @:privateAccess game.switchState();
      check(Std.isOfType(FlxG.state, PlayState) && FlxG.state != oldState && constructed == 2,
        'real reset creates one fresh PlayState using the original factory');
      check(oldGraphic.isDestroyed, 'restart releases the prior song graphic');
      for (sound in Paths.currentTrackedSounds) check(sound != oldSound, 'restart evicts the prior song sound');
      state = cast FlxG.state;
      if (profileOff)
      {
        check(!state.metadataOnlyCharacters && state.boyfriend.width > 1 && state.boyfriendGroup.visible,
          'restart after disabling the profile restores full characters');
        if (pixelSong) check(PlayState.curStage == 'school' && PlayState.isPixelStage,
          'restart after disabling the profile restores the original pixel stage');
        // Enabling the profile during a normally created song must leave the
        // still-live character groups, change events and animations coherent.
        LowMemory.setProfile(MemoryProfiles.EXPERIMENTAL, false);
        check(!ClientPrefs.charsAndBG && state.songCharacterVisuals, 'profile preference changes but song visuals stay latched');
        state.triggerEventNote('Change Character', '0', 'pico', 3000);
        check(state.boyfriend.curCharacter == 'pico' && state.boyfriend.width > 1 && state.boyfriendGroup.visible,
          'a normally created song still changes full characters after enabling the profile');
        state.triggerEventNote('Play Animation', 'singLEFT', 'boyfriend', 3000);
        check(state.boyfriend.getAnimationName() == 'singLEFT', 'full character animations remain enabled until restart');
      }
      else check(state.metadataOnlyCharacters && !state.boyfriendGroup.visible, 'experimental restart keeps stand-ins');
      final restartedNote = new Note(0, 0);
      state.notes.add(restartedNote);
      restartedNote.setupNoteData(state.unspawnNotes[0]);
      graphic = restartedNote.graphic;
      @:privateAccess state.songLength = state.inst.length;
      PlayStatePlayback.startSong(state);
      originalSongSound = @:privateAccess FlxG.sound.music._sound;
    }
    final replaceMusic = Sys.args().indexOf('replacement') >= 0;
    if (replaceMusic)
    {
      Paths.playMenuMusic(true);
      check(@:privateAccess FlxG.sound.music._sound != originalSongSound, 'menu replaces song music');
    }

    FlxTransitionableState.skipNextTransIn = true;
    FlxTransitionableState.skipNextTransOut = true;
    FlxG.switchState(MemorySmokeMenu.new);
    @:privateAccess game.switchState();
    check(Std.isOfType(FlxG.state, MemorySmokeMenu), 'real PlayState destroyed on transition');
    check(PlayState.instance == null, 'destroyed state no longer held globally');
    check(graphic.isDestroyed, 'song note graphic released after transition');
    if (replaceMusic) check(FlxG.sound.music != null && FlxG.sound.music.playing, 'replacement menu music survives');
    else check(FlxG.sound.music == null, 'persistent song music released on exit');
    for (sound in Paths.currentTrackedSounds) check(sound != originalSongSound, 'song sound evicted from cache');
    trace('PlayStateMemoryFlixelSmoke passed (' + song + (replaceMusic ? ', replacement music' : '')
      + (profileOff ? ', profile off' : '') + (restart ? ', restart' : '')
      + (completePixelSkin ? ', complete pixel skin' : '') + ')');
  }
}
