package backend;

import objects.Note;
import headers.Objects;
import objects.NoteSplash;
import play.PlayState;
import flixel.animation.FlxAnimationController;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxFramesCollection;
import haxe.io.Bytes;
import haxe.io.Path;
#if lime_vorbis
import lime.media.AudioBuffer;
import lime.media.vorbis.VorbisFile;
#end
import openfl.display.BitmapData;
import openfl.display3D.textures.RectangleTexture;
import openfl.geom.Rectangle;
import openfl.media.Sound;
import openfl.system.System;
import openfl.utils.AssetType;

import data.Song;
#if cpp
import cpp.vm.Gc;
#elseif hl
import hl.Gc;
#end

@:access(openfl.display.BitmapData)
// @:nullSafety // not yet
class Paths
{
  /**
   * Audio container the engine prefers (and the one built-in content ships as).
   *
   * Ogg Vorbis decodes faster and seeks more accurately than MP3 for the same
   * bitrate, which is exactly what a rhythm game needs, so it wins on desktop,
   * mobile and HTML5 alike. Only Flash/AIR is stuck with MP3, because the SWF
   * audio backend cannot decode Ogg at all.
   */
  inline public static var SOUND_EXT = #if flash "mp3" #else "ogg" #end;

  /**
   * Every audio container the engine can load, best first.
   *
   * Sound resolution (`returnSound`, `inst`, `voices`, `modsSounds`, ...)
   * walks this list and uses the first file that actually exists, so a mod may
   * ship either format -- and the repository never needs to keep an OGG *and*
   * an MP3 copy of the same track. See also `resolveSoundAsset`.
   */
  public static var SOUND_EXTENSIONS:Array<String> = #if flash ["mp3", "ogg"] #else ["ogg", "mp3"] #end;

  inline public static var VIDEO_EXT = "mp4";
  inline public static var IMAGE_EXT = "png";

  public static var defaultNoteSprite:FlxSprite;

  public static var noteSkinFramesMap:Map<String, FlxFramesCollection> = new Map();
  public static var noteSkinAnimsMap:Map<String, FlxAnimationController> = new Map();

  private static var splashFrames:FlxFramesCollection;
  private static var splashAnimation:FlxAnimationController;

  public static var splashSkinFramesMap:Map<String, FlxFramesCollection> = new Map();
  public static var splashSkinAnimsMap:Map<String, FlxAnimationController> = new Map();

  public static var splashConfigs:Map<String, objects.NoteSplash.NoteSplashConfig> = new Map();
  public static var splashAnimCountMap:Map<String, Int> = new Map();

  public static var defaultSkin = 'noteskins/NOTE_assets' + NoteHelpers.getNoteSkinPostfix();

  // Function that initializes the first note. This way, we can recycle the notes
  public static function initDefaultSkin(?noteSkin:String, ?inEditor:Bool = false)
  {
    if (noteSkin != null && noteSkin.length > 0) defaultSkin = noteSkin;
    else if (!PlayState.isPixelStage) defaultSkin = 'noteskins/NOTE_assets' + NoteHelpers.getNoteSkinPostfix();
    else
      defaultSkin = 'noteskins/NOTE_assets';
    #if MAIN_DEBUG
    #if MAIN_DEBUG
    trace(defaultSkin);
    #end
    #end
  }

  public static function initNote(?noteSkin:String)
  {
    // Do this to be able to just copy over the note animations and not reallocate it
    if (noteSkin == null || noteSkin.length < 1) noteSkin = defaultSkin;
    final existingFrames:FlxFramesCollection = noteSkinFramesMap.get(noteSkin);
    if (existingFrames != null && existingFrames.parent != null && !existingFrames.parent.isDestroyed && noteSkinAnimsMap.exists(noteSkin))
    {
      trackLocalAsset(existingFrames.parent.key);
      return;
    }

    final noteFrames:FlxAtlasFrames = getSparrowAtlas(noteSkin.length > 1 ? noteSkin : defaultSkin);
    if (noteFrames == null) return;

    var spr:FlxSprite = new FlxSprite();
    spr.frames = noteFrames;

    // Use a for loop for adding all of the animations in the note spritesheet, otherwise it won't find the animations for the next recycle
    for (d in 0...Note.colArray.length)
    {
      if (d == 0) spr.animation.addByPrefix('purpleholdend', 'pruple end hold'); // ?????
      spr.animation.addByPrefix(Note.colArray[d] + 'holdend', Note.colArray[d] + ' hold end');
      spr.animation.addByPrefix(Note.colArray[d] + 'hold', Note.colArray[d] + ' hold piece');
      spr.animation.addByPrefix(Note.colArray[d] + 'Scroll', Note.colArray[d] + '0');
    }
    noteSkinFramesMap.set(noteSkin, spr.frames);
    noteSkinAnimsMap.set(noteSkin, spr.animation);
    VLog.assetCached('noteskin', noteSkin, 'atlas + note animations cached in RAM');
  }

  // Note Splash initialization
  public static function initSplash(?splashSkin:String)
  {
    var skin:String = (splashSkin != null && splashSkin.length > 0) ? splashSkin : 'noteSplashes/noteSplashes' + NoteSplash.getSplashSkinPostfix();
    final existingFrames:FlxFramesCollection = splashSkinFramesMap.get(skin);
    if (existingFrames != null && existingFrames.parent != null && !existingFrames.parent.isDestroyed && splashSkinAnimsMap.exists(skin))
    {
      splashFrames = existingFrames;
      splashAnimation = splashSkinAnimsMap.get(skin);
      trackLocalAsset(existingFrames.parent.key);
      if (splashSkin != null && splashSkin != skin)
      {
        splashSkinFramesMap.set(splashSkin, existingFrames);
        splashSkinAnimsMap.set(splashSkin, splashAnimation);
        final count:Null<Int> = splashAnimCountMap.get(skin);
        if (count != null) splashAnimCountMap.set(splashSkin, count);
      }
      return;
    }

    splashFrames = getSparrowAtlas(skin);
    if (splashFrames == null) splashFrames = getSparrowAtlas('noteSplashes/noteSplashes' + NoteSplash.getSplashSkinPostfix());
    if (splashFrames == null) return;

    // Do this to be able to just copy over the splash animations and not reallocate it

    var spr:FlxSprite = new FlxSprite();
    spr.frames = splashFrames;
    splashAnimation = new FlxAnimationController(spr);

    // Use a for loop for adding all of the animations in the splash spritesheet, otherwise it won't find the animations for the next recycle

    var config = splashConfigs.get(skin);
    if (config == null) config = initSplashConfig(skin);
    var maxAnims:Int = 0;
    var animName:String = (config != null && config.anim != null && config.anim.length > 0) ? config.anim : "note splash";

    var shouldBreakLoop = false;
    while (!shouldBreakLoop)
    {
      var animID:Int = maxAnims + 1;
      for (i in 0...Note.colArray.length)
      {
        if (!addAnimAndCheck('note$i-$animID', '$animName ${Note.colArray[i]} $animID', 24, false))
        {
          // Reached the maximum amount of anims, break the loop
          shouldBreakLoop = true;
          break;
        }
      }
      if (!shouldBreakLoop) maxAnims++;
      else
        break;
    }
    splashSkinFramesMap.set(skin, splashFrames);
    splashSkinAnimsMap.set(skin, splashAnimation);
    splashAnimCountMap.set(skin, maxAnims);
    if (splashSkin != null && splashSkin != skin)
    {
      splashSkinFramesMap.set(splashSkin, splashFrames);
      splashSkinAnimsMap.set(splashSkin, splashAnimation);
      splashAnimCountMap.set(splashSkin, maxAnims);
    }
    VLog.assetCached('noteskin', 'splash: ' + skin, maxAnims + ' splash animations cached in RAM');
  }

  public static function addAnimAndCheck(name:String, anim:String, ?framerate:Int = 24, ?loop:Bool = false)
  {
    var animFrames = [];
    @:privateAccess
    splashAnimation.findByPrefix(animFrames, anim); // adds valid frames to animFrames

    if (animFrames.length < 1) return false;

    splashAnimation.addByPrefix(name, anim, framerate, loop);
    return true;
  }

  public static function initSplashConfig(skin:String)
  {
    var path:String = Paths.getSharedPath('images/' + skin + '.txt');
    #if sys
    #if MODS_ALLOWED
    if (!FileSystem.exists(path)) path = Paths.modsTxt(skin);
    #end
    if (!FileSystem.exists(path)) path = Paths.getSharedPath('images/noteSplashes/noteSplashes' + NoteSplash.getSplashSkinPostfix() + '.txt');
    #end

    var configFile:Array<String> = CoolUtil.coolTextFile(path);

    if (configFile.length < 1) return null;

    var framerates:Array<String> = configFile[1].split(' ');
    var offs:Array<Array<Float>> = [];
    for (i in 2...configFile.length)
    {
      var animOffs:Array<String> = configFile[i].split(' ');
      offs.push([Std.parseFloat(animOffs[0]), Std.parseFloat(animOffs[1])]);
    }
    var config:objects.NoteSplash.NoteSplashConfig =
      {
        anim: configFile[0],
        minFps: Std.parseInt(framerates[0]),
        maxFps: Std.parseInt(framerates[1]),
        offsets: offs
      };
    splashConfigs.set(skin, config);
    return config;
  }

  private static inline var MISSING_SENTINEL:String = "\x00";
  private static var dumpExclusionSet:Map<String, Bool> = [];
  private static var dumpExclusionsSyncedLen:Int = -1;
  private static var localTrackedAssetSet:Map<String, Bool> = [];
  private static var localTrackedSyncedLen:Int = 0;

  private static var resolvedImageKeyCache:Map<String, String> = [];
  private static var resolvedImageFileCache:Map<String, String> = [];
  private static var resolvedSoundCache:Map<String, String> = [];
  private static var resolvedExistsCache:Map<String, Bool> = [];
  private static var formattedSongPathCache:Map<String, String> = [];
  private static var soundAssetIds:Map<String, String> = [];
  private static var lastLookupModDir:String = null;
  private static var lastLookupLevel:String = null;

  public static function invalidateAssetLookupCache():Void
  {
    resolvedImageKeyCache.clear();
    resolvedImageFileCache.clear();
    resolvedSoundCache.clear();
    resolvedExistsCache.clear();
    lastLookupModDir = null;
    lastLookupLevel = null;
  }

  private static inline function syncLookupContext():Void
  {
    final curMod:String = #if MODS_ALLOWED (Mods.currentModDirectory != null ? Mods.currentModDirectory : '') #else '' #end;
    final curLvl:String = (currentLevel != null) ? currentLevel : '';
    if (lastLookupModDir != curMod || lastLookupLevel != curLvl)
    {
      resolvedImageKeyCache.clear();
      resolvedImageFileCache.clear();
      resolvedSoundCache.clear();
      resolvedExistsCache.clear();
      lastLookupModDir = curMod;
      lastLookupLevel = curLvl;
    }
  }

  private static function syncDumpExclusionSet():Void
  {
    dumpExclusionSet.clear();
    for (entry in dumpExclusions)
    {
      if (entry != null) dumpExclusionSet.set(entry, true);
    }
    dumpExclusionsSyncedLen = dumpExclusions.length;
  }

  private static function syncLocalTrackedSet():Void
  {
    localTrackedAssetSet.clear();
    for (entry in localTrackedAssets)
    {
      if (entry != null) localTrackedAssetSet.set(entry, true);
    }
    localTrackedSyncedLen = localTrackedAssets.length;
  }

  public static inline function trackLocalAsset(key:String):Void
  {
    if (key != null)
    {
      if (localTrackedAssets.length != localTrackedSyncedLen) syncLocalTrackedSet();
      if (!localTrackedAssetSet.exists(key))
      {
        localTrackedAssetSet.set(key, true);
        localTrackedAssets.push(key);
        localTrackedSyncedLen = localTrackedAssets.length;
      }
    }
  }

  private static inline function isLocallyTracked(key:String):Bool
  {
    if (key == null) return false;
    if (localTrackedAssets.length != localTrackedSyncedLen) syncLocalTrackedSet();
    return localTrackedAssetSet.exists(key);
  }

  private static function isDumpExcluded(key:String):Bool
  {
    if (key == null) return false;
    if (dumpExclusions.length != dumpExclusionsSyncedLen) syncDumpExclusionSet();
    if (dumpExclusionSet.exists(key)) return true;
    final activeMenuTheme:String = 'assets/music/freakyMenu-' + ClientPrefs.daMenuMusic + '.$SOUND_EXT';
    return key == activeMenuTheme;
  }

  public static function excludeAsset(key:String)
  {
    if (key == null) return;
    if (dumpExclusions.length != dumpExclusionsSyncedLen) syncDumpExclusionSet();
    if (!dumpExclusionSet.exists(key))
    {
      dumpExclusionSet.set(key, true);
      dumpExclusions.push(key);
      dumpExclusionsSyncedLen = dumpExclusions.length;
    }
  }

  public static var dumpExclusions:Array<String> = [
    'assets/music/freakyMenu.$SOUND_EXT',
    'assets/shared/music/breakfast.$SOUND_EXT',
    'assets/shared/music/tea-time.$SOUND_EXT',
  ];

  @:noCompletion private inline static function _gc(major:Bool)
  {
    #if cpp
    final vlogHeapBefore:Float = Gc.memInfo64(Gc.MEM_INFO_USAGE);
    debug.FrameProfiler.beginGC(major);
    Gc.run(major);
    debug.FrameProfiler.endGC();
    VLog.memoryEvent('explicit GC ' + (major ? 'major' : 'minor') + ': heap ' + VLog.formatBytes(vlogHeapBefore) + ' -> ' + VLog.formatBytes(Gc.memInfo64(Gc.MEM_INFO_USAGE)));
    #elseif hl
    final vlogStatsBefore = Gc.stats();
    final vlogHeapBefore:Float = vlogStatsBefore != null ? vlogStatsBefore.currentMemory : -1.0;
    debug.FrameProfiler.beginGC(major);
    Gc.major();
    debug.FrameProfiler.endGC();
    final vlogStatsAfter = Gc.stats();
    VLog.memoryEvent('explicit GC ' + (major ? 'major' : 'minor') + ' (hl): heap ' + VLog.formatBytes(vlogHeapBefore) + ' -> ' + (vlogStatsAfter != null ? VLog.formatBytes(vlogStatsAfter.currentMemory) : 'n/a'));
    #end
  }

  @:noCompletion public inline static function compress()
  {
    #if cpp
    final vlogHeapBefore:Float = Gc.memInfo64(Gc.MEM_INFO_USAGE);
    debug.FrameProfiler.beginGC(true);
    Gc.compact();
    debug.FrameProfiler.endGC();
    VLog.memoryEvent('heap compact: ' + VLog.formatBytes(vlogHeapBefore) + ' -> ' + VLog.formatBytes(Gc.memInfo64(Gc.MEM_INFO_USAGE)));
    #elseif hl
    final vlogStatsBefore = Gc.stats();
    final vlogHeapBefore:Float = vlogStatsBefore != null ? vlogStatsBefore.currentMemory : -1.0;
    debug.FrameProfiler.beginGC(true);
    Gc.major();
    debug.FrameProfiler.endGC();
    final vlogStatsAfter = Gc.stats();
    VLog.memoryEvent('heap compact (hl): ' + VLog.formatBytes(vlogHeapBefore) + ' -> ' + (vlogStatsAfter != null ? VLog.formatBytes(vlogStatsAfter.currentMemory) : 'n/a'));
    #end
  }

  public inline static function gc(major:Bool = false, repeat:Int = 1)
  {
    while (repeat-- > 0)
      _gc(major);
  }

  private static function evictUnusedSounds():Int
  {
    var freedSounds:Int = 0;
    for (key in currentTrackedSounds.keys())
    {
      if (key != null && !localTrackedAssetSet.exists(key) && !isDumpExcluded(key))
      {
        final sound:Sound = currentTrackedSounds.get(key);
        if (isMusicSound(sound)) continue;

        final assetId:String = soundAssetIds.get(key);
        if (assetId != null)
        {
          OpenFlAssets.cache.removeSound(assetId);
          Assets.cache.clear(assetId);
          soundAssetIds.remove(key);
        }
        OpenFlAssets.cache.removeSound(key);
        Assets.cache.clear(key);
        if (sound != null && !isSoundPlayingInList(sound))
        {
          try
          {
            sound.close();
          }
          catch (_:Dynamic) {}
        }
        currentTrackedSounds.remove(key);
        MemoryLedger.untrackAsset(key); // ...and from the per-area RAM ledger
        freedSounds++;
      }
    }
    return freedSounds;
  }

  /// haya I love you for the base cache dump I took to the max
  public static function clearUnusedMemory()
  {
    if (localTrackedAssets.length != localTrackedSyncedLen) syncLocalTrackedSet();
    if (dumpExclusions.length != dumpExclusionsSyncedLen) syncDumpExclusionSet();

    var vlogFreed:Int = 0;
    final vlogHeapBefore:Float = VLog.heapUsedBytes();
    // clear non local assets in the tracked assets list
    for (key in currentTrackedAssets.keys())
    {
      // if it is not currently contained within the used local assets
      if (!localTrackedAssetSet.exists(key) && !isDumpExcluded(key))
      {
        destroyGraphic(currentTrackedAssets.get(key)); // get rid of the graphic
        currentTrackedAssets.remove(key); // and remove the key from local cache map
        MemoryLedger.untrackAsset(key); // ...and from the per-area RAM ledger
        vlogFreed++;
      }
    }
    final vlogFreedSounds:Int = evictUnusedSounds();
    if (vlogFreed > 0 || vlogFreedSounds > 0)
    {
      gc(true);
      compress();
    }
    VLog.memoryEvent('clearUnusedMemory: freed ' + vlogFreed + ' tracked images and ' + vlogFreedSounds
      + ' cached sounds | heap ' + VLog.formatBytes(vlogHeapBefore) + ' -> ' + VLog.formatBytes(VLog.heapUsedBytes()));
  }

  // define the locally tracked assets
  public static var localTrackedAssets:Array<String> = [];

  @:access(flixel.sound.FlxSound)
  private static function isMusicSound(sound:Sound):Bool
  {
    return sound != null && FlxG.sound != null && FlxG.sound.music != null && FlxG.sound.music.playing && FlxG.sound.music._sound == sound;
  }

  @:access(flixel.sound.FlxSound)
  private static function isSoundPlayingInList(sound:Sound):Bool
  {
    if (sound == null || FlxG.sound == null || FlxG.sound.list == null) return false;
    for (item in FlxG.sound.list.members)
    {
      if (item != null && item.playing && item._sound == sound) return true;
    }
    return false;
  }

  @:access(flixel.system.frontEnds.BitmapFrontEnd._cache)
  public static function clearStoredMemory(?cleanUnused:Bool = false)
  {
    if (localTrackedAssets.length != localTrackedSyncedLen) syncLocalTrackedSet();
    if (dumpExclusions.length != dumpExclusionsSyncedLen) syncDumpExclusionSet();
    invalidateAssetLookupCache();

    var vlogFreedBitmaps:Int = 0;
    // clear anything not in the tracked assets list
    for (key in FlxG.bitmap._cache.keys())
    {
      if (!currentTrackedAssets.exists(key))
      {
        destroyGraphic(FlxG.bitmap.get(key));
        vlogFreedBitmaps++;
      }
    }
    // clear all sounds that are cached
    final vlogFreedSounds:Int = evictUnusedSounds();
    VLog.memoryEvent('clearStoredMemory: freed ' + vlogFreedBitmaps + ' bitmap cache entries and ' + vlogFreedSounds + ' cached sounds');
    // flags everything to be cleared out next unused memory clear
    localTrackedAssets.resize(0);
    localTrackedAssetSet.clear();
    localTrackedSyncedLen = 0;
    #if !html5
    openfl.Assets.cache.clear("songs");
    #end
    if (vlogFreedBitmaps > 0 || vlogFreedSounds > 0)
    {
      gc(true);
      compress();
    }
  }

  private static function pruneSkinCachesForGraphic(graphic:FlxGraphic):Void
  {
    if (graphic == null) return;
    for (skinKey in noteSkinFramesMap.keys())
    {
      final frames:FlxFramesCollection = noteSkinFramesMap.get(skinKey);
      if (frames == null || frames.parent == null || frames.parent == graphic || frames.parent.isDestroyed)
      {
        noteSkinFramesMap.remove(skinKey);
        noteSkinAnimsMap.remove(skinKey);
      }
    }
    for (skinKey in splashSkinFramesMap.keys())
    {
      final frames:FlxFramesCollection = splashSkinFramesMap.get(skinKey);
      if (frames == null || frames.parent == null || frames.parent == graphic || frames.parent.isDestroyed)
      {
        splashSkinFramesMap.remove(skinKey);
        splashSkinAnimsMap.remove(skinKey);
        splashAnimCountMap.remove(skinKey);
      }
    }
  }

  inline static function destroyGraphic(graphic:FlxGraphic)
  {
    if (graphic != null)
    {
      pruneSkinCachesForGraphic(graphic);
      // free some gpu memory
      #if !flash
      if (graphic.bitmap != null && graphic.bitmap.__texture != null) graphic.bitmap.__texture.dispose();
      #end
      // Safety net: drop the graphic from the per-area RAM ledger too (no-op when
      // it was never tracked, e.g. engine-generated Flixel graphics).
      if (graphic.key != null)
      {
        OpenFlAssets.cache.removeBitmapData(graphic.key);
        MemoryLedger.untrackAsset(graphic.key);
      }
      FlxG.bitmap.remove(graphic);
    }
  }

  static public var currentLevel:String;

  static public function setCurrentLevel(name:String)
  {
    final nextLevel:String = name.toLowerCase();
    if (currentLevel != nextLevel)
    {
      currentLevel = nextLevel;
      invalidateAssetLookupCache();
    }
  }

  public static function getPath(file:String, ?type:AssetType = TEXT, ?library:Null<String> = null, ?modsAllowed:Bool = false):String
  {
    #if MODS_ALLOWED
    if (modsAllowed)
    {
      var customFile:String = file;
      if (library != null) customFile = '$library/$file';

      var modded:String = modFolders(customFile);
      if (FileSystem.exists(modded)) return modded;
    }
    #end

    if (library != null)
    {
      // trace(getLibraryPath(file, library));
      return getLibraryPath(file, library);
    }

    if (currentLevel != null)
    {
      var levelPath:String = '';
      if (currentLevel != 'shared')
      {
        levelPath = getLibraryPathForce(file, currentLevel);
        // `getLibraryPathForce()` falls back to a loose on-disk level path
        // (`assets/week7/images/tankSky.png`) when the level library isn't
        // registered (content-stripped / compact builds). `OpenFlAssets.exists()`
        // only knows registered library ids, so probe the loose file too —
        // exactly like `getTextFromFile()` already does — instead of falling
        // through to a preload path that nothing owns.
        if (OpenFlAssets.exists(levelPath, type)
            #if sys
            || FileSystem.exists(levelPath)
            #end
        )
        {
          // trace(levelPath);
          return levelPath;
        }
      }

      levelPath = getLibraryPathForce(file, "shared");
      if (OpenFlAssets.exists(levelPath, type)
          #if sys
          || FileSystem.exists(levelPath)
          #end
      )
      {
        // trace(levelPath);
        return levelPath;
      }
    }
    // trace(getPreloadPath(file));
    return getPreloadPath(file);
  }

  public static inline function readDirectory(path:String):Array<String>
  {
    #if sys
    return FileSystem.readDirectory(path);
    #else
    // original by Karim Akra
    var files:Array<String> = [];

    for (possibleFile in Assets.list().filter((f) -> f.contains(path)))
    {
      var file:String = possibleFile.replace('${path}/', "");
      if (file.contains("/")) file = file.replace(file.substring(file.indexOf("/"), file.length), "");

      if (!files.contains(file)) files.push(file);
    }

    files.sort((a, b) -> {
      a = a.toUpperCase();
      b = b.toUpperCase();
      return (a < b) ? -1 : (a > b) ? 1 : 0;
    });

    return files;
    #end
  }

  static public function getLibraryPath(file:String, library = "preload")
  {
    return if (library == "preload" || library == "default") getPreloadPath(file); else getLibraryPathForce(file, library);
  }

  inline static function getLibraryPathForce(file:String, library:String, ?level:String)
  {
    if (level == null) level = library;
    var returnPath = '$library:assets/$level/$file';
    if (OpenFlAssets.exists(returnPath))
    {
      return returnPath;
    } else
    {
      return 'assets/$level/$file';
    }
  }

  inline public static function getPreloadPath(file:String = '')
  {
    return 'assets/$file';
  }

  inline public static function getSharedPath(file:String = '')
  {
    return 'assets/shared/$file';
  }

  inline static public function file(file:String, type:AssetType = TEXT, ?library:String)
  {
    return getPath(file, type, library);
  }

  inline static public function txt(key:String, ?library:String)
  {
    return getPath('data/$key.txt', TEXT, library);
  }

  inline static public function xml(key:String, ?library:String)
  {
    return getPath('data/$key.xml', TEXT, library);
  }

  inline static public function json(key:String, ?library:String)
  {
    return getPath('data/' + key + '.json', TEXT, library);
  }

  inline static public function shaderFragment(key:String, ?library:String)
  {
    return getPath('shaders/$key.frag', TEXT, library);
  }

  inline static public function shaderVertex(key:String, ?library:String)
  {
    return getPath('shaders/$key.vert', TEXT, library);
  }

  inline static public function lua(key:String, ?library:String)
  {
    return getPath('$key.lua', TEXT, library);
  }

  // Video loading (part of it)
  static public function video(key:String, ?library:String = null)
  {
    #if MODS_ALLOWED
    var file:String = modsVideo(key);
    if (FileSystem.exists(file))
    {
      return file;
    }
    #end
    final path:String = ('assets/${(library != null) ? '$library/' : ''}videos/$key.$VIDEO_EXT');
    // trace('Video Path before being passed to hxCodec: $path');
    return path;
  }

  // Sound loading.
  static public function sound(key:String, ?library:String):Sound
  {
    var sound:Sound = returnSound('sounds', key, library);
    return sound;
  }

  // Random sound loading.
  inline static public function soundRandom(key:String, min:Int, max:Int, ?library:String)
  {
    return sound(key + FlxG.random.int(min, max), library);
  }

  // Music loading. Loads anything in assets/data/music, OR mods/data/music (if mods are allowed)
  inline static public function music(key:String, ?library:String):Sound
  {
    var file:Sound = returnSound('music', key, library);
    return file;
  }

  // Loads the Voices. Crucial for generateSong
  static public function voices(song:String, ?difficulty:String = '', ?postfix:String = null):Any
  {
    var formattedDifficulty:String = formatToSongPath(difficulty);
    if (difficulty != null && difficulty.contains(' ')) difficulty = formattedDifficulty;
    #if (html5 || flash)
    return songAudioAsset(formatToSongPath(song), 'Voices');
    #else
    if (difficulty != null && difficulty.length > 0)
    {
      var songKey:String = '${formatToSongPath(song)}/Voices';
      if (postfix != null) songKey += '-' + postfix;
      songKey += '-$difficulty';
      if (songKeyExists(songKey)) return returnSound('songs', songKey);
    }
    var songKey:String = '${formatToSongPath(song)}/Voices';
    if (postfix != null) songKey += '-' + postfix;
    return returnSound('songs', songKey);
    #end
  }

  // Loads the instrumental. Crucial for generateSong
  static public function inst(song:String, ?difficulty:String = ''):Any
  {
    var formattedDifficulty:String = formatToSongPath(difficulty);
    if (difficulty != null && difficulty.contains(' ')) difficulty = formattedDifficulty;
    #if (html5 || flash)
    return songAudioAsset(formatToSongPath(song), 'Inst');
    #else
    if (difficulty != null && difficulty.length > 0)
    {
      var songKey:String = '${formatToSongPath(song)}/Inst-$difficulty';
      if (songKeyExists(songKey)) return returnSound('songs', songKey);
    }
    return returnSound('songs', '${formatToSongPath(song)}/Inst');
    #end
  }

  /**
   * Asset id (`songs:` library) of a song track for the web targets, which
   * play the file straight out of the asset library instead of loading it from
   * disk. Tries every container in `SOUND_EXTENSIONS` so a song may ship as
   * `.ogg` or `.mp3`, and falls back to the preferred extension when the song
   * has no audio at all (the caller then fails like it always did).
   */
  static function songAudioAsset(songPath:String, file:String):String
  {
    for (ext in SOUND_EXTENSIONS)
    {
      final assetId:String = 'songs:assets/songs/$songPath/$file.$ext';
      if (OpenFlAssets.exists(assetId, SOUND)) return assetId;
    }
    return 'songs:assets/songs/$songPath/$file.$SOUND_EXT';
  }

  /**
   * Whether `songs/<key>` resolves to a supported audio container.
   * Checks enabled mod folders first (like `modFolders`), then the raw
   * `assets/songs` folder, then the `songs` asset library, and tries every
   * extension in `SOUND_EXTENSIONS`. Ogg and MP3 content are both valid, so
   * nobody has to keep two copies of the same track around.
   */
  static function songKeyExists(key:String):Bool
  {
    syncLookupContext();
    final cacheId:String = 'song:' + key;
    final cached:Null<Bool> = resolvedExistsCache.get(cacheId);
    if (cached != null) return cached;

    final found:Bool = probeSongKeyExists(key);
    resolvedExistsCache.set(cacheId, found);
    return found;
  }

  private static function probeSongKeyExists(key:String):Bool
  {
    #if MODS_ALLOWED
    // modsSounds() falls back to 'mods/<key>' and returns null when missing.
    if (modsSounds('songs', key) != null) return true;
    #end
    #if sys
    for (ext in SOUND_EXTENSIONS)
      if (FileSystem.exists('assets/songs/$key.$ext')) return true;
    #end
    for (ext in SOUND_EXTENSIONS)
      if (OpenFlAssets.exists('songs:assets/songs/$key.$ext', SOUND)) return true;
    return false;
  }

  /**
   * Whether the instrumental for a song can actually be resolved.
   *
   * `inst()` hands back a loaded `Sound` on native builds (an asset URL on
   * web), never a path -- so `FileSystem.exists(Paths.inst(...))` was false for
   * *every* song. Freeplay's "JS Engine Anti-Crash Tool" did exactly that, so
   * picking any song popped a bogus (and, on Windows, modal/blocking) "this
   * song has no JSON or audio" dialog, and mod songs such as bf-clicker never
   * got to load their scripts. Use this Bool helper for existence
   * checks and keep `inst()` for actually loading the audio.
   */
  static public function instExists(song:String, ?difficulty:String = ''):Bool
  {
    return songAudioExists(song, 'Inst', difficulty);
  }

  /**
   * Whether the vocal track for a song can actually be resolved.
   * Same rationale as `instExists` -- `voices()` returns a `Sound`, not a path.
   */
  static public function voicesExists(song:String, ?difficulty:String = ''):Bool
  {
    return songAudioExists(song, 'Voices', difficulty);
  }

  /**
   * Shared resolution check behind `instExists` / `voicesExists`: enabled mod
   * folders first (like `modFolders`), then the raw song folder, then the song
   * library using the same asset id `returnSound` builds. Both the
   * difficulty-specific file (`Inst-hard`) and the plain one are probed, with
   * every container in `SOUND_EXTENSIONS`.
   */
  static function songAudioExists(song:String, file:String, ?difficulty:String = ''):Bool
  {
    final formatted:String = formatToSongPath(song);
    final diff:String = (difficulty != null) ? formatToSongPath(difficulty) : '';
    final keys:Array<String> = (diff.length > 0) ? ['$formatted/$file-$diff', '$formatted/$file'] : ['$formatted/$file'];

    for (key in keys)
      if (songKeyExists(key)) return true;
    return false;
  }

  static public function playMenuMusic(force:Bool = false, volume:Float = 1):Void
  {
    if (FlxG.sound.music == null || force)
    {
      final playAprilFools:Bool = DateUtils.isAprilFools();

      if (playAprilFools)
      {
        FlxG.sound.playMusic(Paths.music('aprilFools'), volume);
      } 
	  else
      {
        final musicName = 'freakyMenu-' + ClientPrefs.daMenuMusic;
        // trace(musicName);

        #if MODS_ALLOWED
        playModMusic(musicName, 'freakyMenu', volume); // TODO: add HScript support here
        #else
        FlxG.sound.playMusic(music(musicName), volume);
        #end
      }
    }
  }

  // For song events.
  static public function songEvents(song:String, ?difficulty:String, ?onlyEventsString:Bool = false):String
  {
    if (difficulty != null)
    {
      var formattedDifficulty:String = formatToSongPath(difficulty);
      if (difficulty.contains(' ')) difficulty = formattedDifficulty;

      var eventsKey:String = formatToSongPath(song) + '/events-${difficulty.toLowerCase()}';
      #if sys
      if (FileSystem.exists(Paths.json(eventsKey))
        #if MODS_ALLOWED || FileSystem.exists(Paths.modsJson(eventsKey)) #end) return (!onlyEventsString ? eventsKey : 'events-${difficulty.toLowerCase()}');
      #else
      if (OpenFlAssets.exists(Paths.json(eventsKey))) return (!onlyEventsString ? eventsKey : 'events-${difficulty.toLowerCase()}');
      #end
    }
    var eventsKey:String = formatToSongPath(song) + '/events';
    return (!onlyEventsString ? eventsKey : 'events');
  }

  public static var IMAGE_EXTS:Array<String> = ["png", "jpg", "jpeg", "webp"];
  public static function imagePath(key:String, ?folder:String):String
  {
    for (ext in IMAGE_EXTS)
    {
      final candidate:String = getPath('images/$key.$ext', IMAGE, folder);
      #if sys
      if (FileSystem.exists(candidate)) return candidate;
      #else
      if (OpenFlAssets.exists(candidate)) return candidate;
      #end
    }
    return getPath('images/$key.png', IMAGE, folder);
  }

  inline public static function imageExists(key:String, ?folder:String):Bool
    return Paths.exists(imagePath(key, folder));

  private static final ZERO_BORDER:flixel.math.FlxPoint = new flixel.math.FlxPoint(0, 0);

  // Loads images.
  public static var currentTrackedAssets:Map<String, FlxGraphic> = [];
  // because the trace is so very annoying sometimes
  public static var warnedMissingAssets:Map<String, Bool> = [];

  static public function image(key:String, ?parentFolder:String = null):FlxGraphic
  {
    syncLookupContext();
    final lookupId:String = (parentFolder == null || parentFolder.length == 0) ? key : parentFolder + ':' + key;
    var cacheKey:String = resolvedImageKeyCache.get(lookupId);
    if (cacheKey == MISSING_SENTINEL) return null;

    if (cacheKey != null)
    {
      final cached:FlxGraphic = currentTrackedAssets.get(cacheKey);
      if (cached != null && !cached.isDestroyed && cached.bitmap != null)
      {
        trackLocalAsset(cacheKey);
        return cached;
      }
      currentTrackedAssets.remove(cacheKey);
    }

    final assetKey:String = imagePath(key, parentFolder);
    final file:String = assetKey;
    #if MODS_ALLOWED
    if (file.startsWith('mods/') && FileSystem.exists(file))
    {
      cacheKey = file;
    }
    else
    #end
    if (parentFolder != null && parentFolder.length > 0 && parentFolder != 'preload' && parentFolder != 'default')
    {
      cacheKey = '$parentFolder:$assetKey';
    }
    else
    {
      cacheKey = assetKey;
    }

    resolvedImageFileCache.set(cacheKey, file);
    final existing:FlxGraphic = currentTrackedAssets.get(cacheKey);
    if (existing != null && !existing.isDestroyed && existing.bitmap != null)
    {
      resolvedImageKeyCache.set(lookupId, cacheKey);
      trackLocalAsset(cacheKey);
      return existing;
    }
    if (existing != null) currentTrackedAssets.remove(cacheKey);

    final loaded:FlxGraphic = cacheBitmap(cacheKey, parentFolder, null);
    resolvedImageKeyCache.set(lookupId, loaded != null ? cacheKey : MISSING_SENTINEL);
    return loaded;
  }

  public static function cacheBitmap(key:String, ?parentFolder:String = null, ?bitmap:BitmapData):FlxGraphic
  {
    if (bitmap == null)
    {
      final existing:FlxGraphic = currentTrackedAssets.get(key);
      if (existing != null && !existing.isDestroyed && existing.bitmap != null)
      {
        trackLocalAsset(key);
        return existing;
      }
      if (existing != null) currentTrackedAssets.remove(key);
    }

    // Resolved path tells the memory ledger whether this is an engine or mod
    // asset (and which mod). Falls back to the key when a bitmap is passed in.
    var vlogSourcePath:String = key;
    if (bitmap == null)
    {
      var file:String = resolvedImageFileCache.get(key);
      if (file == null)
      {
        #if MODS_ALLOWED
        if (FileSystem.exists(key))
        {
          file = key;
        }
        else if (key.startsWith('mods/'))
        {
          return null;
        }
        else
        #end
        file = getPath(key, IMAGE, parentFolder, true);
      }
      vlogSourcePath = file;
      #if MODS_ALLOWED
      if (FileSystem.exists(file))
      {
        bitmap = BitmapData.fromFile(file);
      }
      else
      #end
      if (OpenFlAssets.exists(file, IMAGE))
      {
        if (OpenFlAssets.cache.hasBitmapData(file))
        {
          bitmap = OpenFlAssets.getBitmapData(file, true);
          OpenFlAssets.cache.removeBitmapData(file);
        }
        else
        {
          bitmap = OpenFlAssets.getBitmapData(file, false);
        }
      }

      if (bitmap == null)
      {
        if (!warnedMissingAssets.exists(file))
        {
          warnedMissingAssets.set(file, true);
          #if MAIN_DEBUG
          trace('Missing asset: $file');
          #end
        }
        return null;
      }
    }

    var vlogGpuCached:Bool = false;
    #if !flash
    if (ClientPrefs.cacheOnGPU && bitmap.image != null && FlxG.stage != null && FlxG.stage.context3D != null)
    {
      bitmap.lock();
      if (bitmap.__texture == null)
      {
        bitmap.image.premultiplied = true;
        bitmap.getTexture(FlxG.stage.context3D);
      }
      if (bitmap.__texture != null)
      {
        vlogGpuCached = true;
        bitmap.__surface = null;
        bitmap.disposeImage();
        bitmap.image.data = null;
        bitmap.image = null;
        bitmap.readable = true;
      }
      else
      {
        bitmap.unlock();
      }
    }
    #end

    var graph:FlxGraphic = FlxGraphic.fromBitmapData(bitmap, false, key);
    graph.persist = true;
    graph.destroyOnNoUse = false;

    currentTrackedAssets.set(key, graph);
    trackLocalAsset(key);
    MemoryLedger.trackImage(key, vlogSourcePath, bitmap, vlogGpuCached);
    VLog.assetCached('image', key, bitmap.width + 'x' + bitmap.height
      + ' (~' + VLog.formatBytes(bitmap.width * bitmap.height * 4) + ')'
      + (vlogGpuCached ? ' | GPU texture (CPU pixels freed)' : ' | CPU bitmap in RAM'));
    return graph;
  }

  static public function getTextFromFile(key:String, ?ignoreMods:Bool = false):String
  {
    var text:String = null;
    #if sys
    #if MODS_ALLOWED
    if (!ignoreMods)
    {
      final modPath:String = modFolders(key);
      if (FileSystem.exists(modPath)) text = File.getContent(modPath);
    }
    #end

    if (text == null)
    {
      final preloadPath:String = getPreloadPath(key);
      if (FileSystem.exists(preloadPath)) text = File.getContent(preloadPath);
    }

    if (text == null && currentLevel != null)
    {
      var levelPath:String = '';
      if (currentLevel != 'shared')
      {
        levelPath = getLibraryPathForce(key, currentLevel);
        if (FileSystem.exists(levelPath)) text = File.getContent(levelPath);
      }

      if (text == null)
      {
        levelPath = getLibraryPathForce(key, 'shared');
        if (FileSystem.exists(levelPath)) text = File.getContent(levelPath);
      }
    }
    #end
    if (text == null)
    {
      final assetPath:String = getPath(key, TEXT);
      if (Assets.exists(assetPath, TEXT)) text = Assets.getText(assetPath);
    }

    if (text != null && text.charCodeAt(0) == 0xFEFF) text = text.substr(1); // Strip BOM to prevent Json.parse errors
    return text;
  }

  inline static public function font(key:String)
  {
    #if MODS_ALLOWED
    var file:String = modsFont(key);
    if (FileSystem.exists(file))
    {
      return file;
    }
    #end
    return 'assets/fonts/$key';
  }

  public static function fileExists(key:String, type:AssetType, ?ignoreMods:Bool = false)
  {
    syncLookupContext();
    final cacheId:String = (ignoreMods ? '1:' : '0:') + key;
    final cached:Null<Bool> = resolvedExistsCache.get(cacheId);
    if (cached != null) return cached;

    var found:Bool = false;
    #if MODS_ALLOWED
    if (!ignoreMods)
    {
      if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0 && FileSystem.exists(mods(Mods.currentModDirectory + '/' + key)))
      {
        found = true;
      }
      else
      {
        for (mod in Mods.getGlobalMods())
        {
          if (FileSystem.exists(mods('$mod/$key')))
          {
            found = true;
            break;
          }
        }
        if (!found && FileSystem.exists(mods(key))) found = true;
      }
    }
    #end

    if (!found && OpenFlAssets.exists(getPath(key, type)))
    {
      found = true;
    }
    resolvedExistsCache.set(cacheId, found);
    return found;
  }

  // Temporary asset lookup helper.
  inline static public function exists(key:String, type:AssetType = null, ?library:String)
  {
    #if sys
    if (FileSystem.exists(key))
    {
      return true;
    }
    #end

    if (OpenFlAssets.exists(key, type))
    {
      return true;
    }
    return false;
  }

  inline static public function existsPath(key:String, type:AssetType = null, ?library:String)
  {
    final resolvedPath:String = getPath(key, type, library);
    #if sys
    if (FileSystem.exists(resolvedPath))
    {
      return true;
    }
    #end

    if (OpenFlAssets.exists(resolvedPath, type))
    {
      return true;
    }
    return false;
  }

  inline public static function getContent(path:String)
  {
    #if sys
    if (path.contains(':')) path = path.substring(path.indexOf(':') + 1);
    if (FileSystem.exists(path)) return File.getContent(path);
    return null;
    #else
    return OpenFlAssets.getText(path);
    #end
  }

  static public function getAtlas(key:String, ?parentFolder:String = null):FlxAtlasFrames
  {
    var imageLoaded:FlxGraphic = image(key, parentFolder);
    if (imageLoaded == null) return null;

    final cachedAtlas:FlxAtlasFrames = FlxAtlasFrames.findFrame(imageLoaded, ZERO_BORDER);
    if (cachedAtlas != null) return cachedAtlas;

    var useMod = false;
    var myXml:Dynamic = getPath('images/$key.xml', TEXT, parentFolder, true);
    if (OpenFlAssets.exists(myXml) #if MODS_ALLOWED || (FileSystem.exists(myXml) && (useMod = true)) #end)
    {
      #if MODS_ALLOWED
      return FlxAtlasFrames.fromSparrow(imageLoaded, (useMod ? File.getContent(myXml) : myXml));
      #else
      return FlxAtlasFrames.fromSparrow(imageLoaded, myXml);
      #end
    } else
    {
      var myJson:Dynamic = getPath('images/$key.json', TEXT, parentFolder, true);
      if (OpenFlAssets.exists(myJson) #if MODS_ALLOWED || (FileSystem.exists(myJson) && (useMod = true)) #end)
      {
        #if MODS_ALLOWED
        return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, (useMod ? File.getContent(myJson) : myJson));
        #else
        return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, myJson);
        #end
      }
    }
    return getPackerAtlas(key, parentFolder);
  }

  static public function getMultiAtlas(keys:Array<String>, ?parentFolder:String = null):FlxAtlasFrames
  {
    var parentFrames:FlxAtlasFrames = Paths.getAtlas(keys[0].trim());
    if (keys.length > 1)
    {
      var original:FlxAtlasFrames = parentFrames;
      parentFrames = new FlxAtlasFrames(parentFrames.parent);
      parentFrames.addAtlas(original, true);
      for (i in 1...keys.length)
      {
        var extraFrames:FlxAtlasFrames = Paths.getAtlas(keys[i].trim(), parentFolder);
        if (extraFrames != null) parentFrames.addAtlas(extraFrames, true);
      }
    }
    return parentFrames;
  }

  /**
   * Reads an atlas descriptor (`.xml`, `.txt`, `.json`) as text.
   *
   * `getPath()` resolves through the compiled OpenFL asset library, so for a
   * file that is shipped loose on disk but is not part of an embedded library
   * (level folders in `NO_BUILTIN_CONTENT` builds, a level library that was
   * not packed, a hand-edited install) it returns a path nothing owns. Passing
   * that unusable path straight to `FlxAtlasFrames` made the atlas come back
   * `null`, and callers then dereferenced the animation they could never
   * create (`ABotSpeaker.new()` -> `curAnim.finish()` was the crash in the
   * 2026-11-11 bundle). `getTextFromFile()` already probes mods, the preload
   * folder, the current level folder and `shared` on disk — it is what
   * `loadAnimateAtlas()` uses — so reuse it here and keep both atlas flavours
   * resolvable the same way.
   */
  static function atlasText(file:String, ?parentFolder:String = null):String
  {
    if (parentFolder != null && parentFolder.length > 0)
    {
      // An explicit folder/library: keep the library id around, because that
      // is how an embedded asset is read (`getTextFromFile` only knows the
      // current level folder, not one a caller picked).
      final libraryPath:String = getPath(file, TEXT, parentFolder);
      if (OpenFlAssets.exists(libraryPath, TEXT)) return OpenFlAssets.getText(libraryPath);

      final diskText:String = getContent(libraryPath);
      if (diskText != null) return diskText;
    }
    return getTextFromFile(file);
  }

  /**
   * Reports an atlas that could not be built. Without this the failure only
   * surfaced as a null reference deep inside a caller, which told crash triage
   * nothing about which asset was missing.
   */
  static function warnAtlasFailure(key:String, part:String):Void
  {
    // Once per key/part: a stage that retries the load must not spam the vlog.
    final warnId:String = 'atlas|' + key + '|' + part;
    if (warnedMissingAssets.exists(warnId)) return;
    warnedMissingAssets.set(warnId, true);
    VLog.assetCached('atlas', key, 'UNAVAILABLE (' + part + ' not found) — animations fall back to a still frame');
  }

  /**
   * Flags an atlas that parsed to no usable frames. Such an atlas is returned
   * unchanged (callers relied on that), but it is logged: a descriptor with no
   * frames silently makes `animation.addByPrefix()` add nothing, and the
   * caller then blows up on the null `curAnim` — exactly what the 2026-11-11
   * bundle showed at `ABotSpeaker.new()`, with nothing in the log pointing at
   * the asset.
   */
  static function warnIfEmptyAtlas(key:String, frames:FlxAtlasFrames):FlxAtlasFrames
  {
    if (frames == null || frames.numFrames < 1) warnAtlasFailure(key, 'frames');
    return frames;
  }

  static public function getSparrowAtlas(key:String, ?parentFolder:String = null):FlxAtlasFrames
  {
    var imageLoaded:FlxGraphic = image(key, parentFolder);
    if (imageLoaded == null)
    {
      warnAtlasFailure(key, 'image');
      return null;
    }

    final cachedAtlas:FlxAtlasFrames = FlxAtlasFrames.findFrame(imageLoaded, ZERO_BORDER);
    if (cachedAtlas != null) return cachedAtlas;

    final xmlText:String = atlasText('images/$key' + '.xml', parentFolder);
    if (xmlText == null)
    {
      warnAtlasFailure(key, 'xml');
      return null;
    }
    return warnIfEmptyAtlas(key, FlxAtlasFrames.fromSparrow(imageLoaded, xmlText));
  }

  static public function getPackerAtlas(key:String, ?parentFolder:String = null):FlxAtlasFrames
  {
    var imageLoaded:FlxGraphic = image(key, parentFolder);
    if (imageLoaded == null)
    {
      warnAtlasFailure(key, 'image');
      return null;
    }

    final cachedAtlas:FlxAtlasFrames = FlxAtlasFrames.findFrame(imageLoaded, ZERO_BORDER);
    if (cachedAtlas != null) return cachedAtlas;

    final txtText:String = atlasText('images/$key' + '.txt', parentFolder);
    if (txtText == null)
    {
      warnAtlasFailure(key, 'txt');
      return null;
    }
    return warnIfEmptyAtlas(key, FlxAtlasFrames.fromSpriteSheetPacker(imageLoaded, txtText));
  }

  static public function getAsepriteAtlas(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
  {
    var imageLoaded:FlxGraphic = image(key, parentFolder);
    if (imageLoaded == null)
    {
      warnAtlasFailure(key, 'image');
      return null;
    }

    final cachedAtlas:FlxAtlasFrames = FlxAtlasFrames.findFrame(imageLoaded, ZERO_BORDER);
    if (cachedAtlas != null) return cachedAtlas;

    final jsonText:String = atlasText('images/$key' + '.json', parentFolder);
    if (jsonText == null)
    {
      warnAtlasFailure(key, 'json');
      return null;
    }
    return warnIfEmptyAtlas(key, FlxAtlasFrames.fromTexturePackerJson(imageLoaded, jsonText));
  }

  /**
   * Lowercases a song/difficulty name and turns it into a filesystem-safe folder
   * name. Memoized, and allocation-free on repeat calls -- the old version built
   * two `EReg`s plus three throwaway strings per call, and it runs several times
   * per state transition (`PlayState`, `FreeplayState`, `Highscore`, Lua/HScript
   * variables...).
   *
   * The legacy semantics are kept *exactly*, including the quirk that only the
   * first matching character is rewritten: the original implementation used
   * non-global `EReg.split`, so a second `#` or `?` in a song name was left
   * alone. Chart folders created by older builds (and by Psych Engine itself)
   * must keep resolving to the same path.
   */
  static public function formatToSongPath(path:String):String
  {
    if (path == null) return '';
    final cached:String = formattedSongPathCache.get(path);
    if (cached != null) return cached;

    var buf:StringBuf = new StringBuf();
    var replacedInvalid:Bool = false;
    var removedHidden:Bool = false;
    for (i in 0...path.length)
    {
      final code:Int = StringTools.fastCodeAt(path, i);
      if (code == 32) buf.addChar(45); // ' ' -> '-'
      else if (!replacedInvalid && isSongPathInvalidChar(code))
      {
        replacedInvalid = true;
        buf.addChar(45); // first '~', '&', '\', ';', ':', '<', '>', '#' -> '-'
      }
      else if (!removedHidden && isSongPathHiddenChar(code))
      {
        removedHidden = true; // first '.', ',', '\'', '"', '%', '?', '!' is dropped
      }
      else buf.addChar(code);
    }
    final formatted:String = buf.toString().toLowerCase();
    formattedSongPathCache.set(path, formatted);
    return formatted;
  }

  private static inline function isSongPathInvalidChar(code:Int):Bool
  {
    return code == 126 || code == 38 || code == 92 || code == 59 || code == 58 || code == 60 || code == 62 || code == 35;
  }

  private static inline function isSongPathHiddenChar(code:Int):Bool
  {
    return code == 46 || code == 44 || code == 39 || code == 34 || code == 37 || code == 63 || code == 33;
  }

  inline static function isOggFile(file:String):Bool
  {
    return file != null && file.toLowerCase().endsWith('.ogg');
  }

  private static function hasOggMagic(file:String):Bool
  {
    #if sys
    var input = File.read(file, true);
    try
    {
      final header:Bytes = Bytes.alloc(4);
      final readCount:Int = input.readBytes(header, 0, 4);
      input.close();
      return readCount == 4 && header.toString() == "OggS";
    }
    catch (_:Dynamic)
    {
      try
      {
        input.close();
      }
      catch (_:Dynamic) {}
      return false;
    }
    #else
    return true;
    #end
  }

  /**
   * Resolves the asset-library id of a sound.
   *
   * `dir` is the asset folder (`sounds`, `music`, `songs`, ...) and `key` the
   * file name *without* extension; `library` optionally names an asset library
   * (`shared`, `songs`, ...). Every container in `SOUND_EXTENSIONS` is probed
   * in order (ogg first), so content may ship either format -- the engine no
   * longer needs an OGG *and* an MP3 copy of the same audio.
   *
   * Returns `null` when no supported container exists.
   */
  public static function resolveSoundAsset(dir:String, key:String, ?library:String):String
  {
    for (ext in SOUND_EXTENSIONS)
    {
      var assetId:String = getPath('$dir/$key.$ext', SOUND, library);
      // The songs library is namespaced ('songs:assets/songs/...'), while
      // getPath() drops the prefix when it resolves through a level folder.
      if (dir == 'songs' && !assetId.startsWith('songs:')) assetId = 'songs:' + assetId;
      if (OpenFlAssets.exists(assetId, SOUND)) return assetId;
    }
    return null;
  }

  // Asset loading has been rewritten.
  public static var currentTrackedSounds:Map<String, Sound> = [];

  // Returns sounds which is useful for all the sfx
  public static function returnSound(path:String, key:String, ?library:String, stream:Bool = false)
  {
    syncLookupContext();
    final lookupKey:String = (library == null || library.length == 0) ? '$path/$key' : '$library:$path/$key';
    final cachedFile:String = resolvedSoundCache.get(lookupKey);
    if (cachedFile == MISSING_SENTINEL) return null;

    if (cachedFile != null && !stream)
    {
      final fastHit:Sound = currentTrackedSounds.get(cachedFile);
      if (fastHit != null && @:privateAccess fastHit.__buffer != null)
      {
        trackLocalAsset(cachedFile);
        return fastHit;
      }
      currentTrackedSounds.remove(cachedFile);
    }

    var sound:Sound = null;
    var file:String = null;

    #if MODS_ALLOWED
    // modsSounds() walks SOUND_EXTENSIONS and returns null when the mod ships
    // neither .ogg nor .mp3, in which case we fall through to the libraries.
    file = modsSounds(path, key);
    if (file != null)
    {
      final existingModSound:Sound = currentTrackedSounds.get(file);
      if (!stream && existingModSound != null && @:privateAccess existingModSound.__buffer != null)
      {
        resolvedSoundCache.set(lookupKey, file);
        trackLocalAsset(file);
        return existingModSound;
      }
      if (FileSystem.exists(file))
      {
        #if lime_vorbis
        if (stream) sound = Sound.fromAudioBuffer(AudioBuffer.fromVorbisFile(VorbisFile.fromFile(file)));
        else
        #end
        try
        {
          // Only Ogg files get the container sanity check; MP3 is decoded by
          // OpenFL/Windows/Android natively and has no magic header to look for.
          if (isOggFile(file))
          {
            if (!hasOggMagic(file))
            {
              throw 'The file "$file" is not a valid OGG file (missing OggS header). It may have been renamed from '
                + 'another format like MP3 -- either rename it back to .mp3 or re-encode it as Ogg.';
            }
          }

          sound = Sound.fromFile(file);
        }
        catch (e)
        {
          VLog.assetCached('sound', file, 'DECODE FAILED: ' + Std.string(e));
          throw 'Cannot load sound file: $file\nMake sure it is a properly encoded .ogg (or .mp3) file.\nError: $e';
        }
      }
    }
    #end

    if (sound == null)
    {
      // This fallback avoids repeated sound lookup failures.
      final gottenPath:String = resolveSoundAsset(path, key, library);
      if (gottenPath == null)
      {
        file = '$path/$key.$SOUND_EXT';
      }
      else
      {
        file = gottenPath.substring(gottenPath.indexOf(':') + 1, gottenPath.length);
        soundAssetIds.set(file, gottenPath);
        final existingLibSound:Sound = currentTrackedSounds.get(file);
        if (!stream && existingLibSound != null && @:privateAccess existingLibSound.__buffer != null)
        {
          resolvedSoundCache.set(lookupKey, file);
          trackLocalAsset(file);
          return existingLibSound;
        }
        #if lime_vorbis
        if (stream) sound = OpenFlAssets.getMusic(gottenPath);
        else
        #end
        sound = OpenFlAssets.getSound(gottenPath);
      }
    }

    if (sound != null)
    {
      resolvedSoundCache.set(lookupKey, file);
      trackLocalAsset(file);
      currentTrackedSounds.set(file, sound);
      MemoryLedger.trackSound(file, file, sound);
      VLog.assetCached('sound', file, 'decoded into RAM (tracked for cache clearing)');
      return sound;
    }

    resolvedSoundCache.set(lookupKey, MISSING_SENTINEL);
    VLog.assetCached('sound', file, 'MISSING — not found on disk or in the asset libraries');
    #if MAIN_DEBUG
    trace('Missing asset: $file');
    #end
    return null;
  }

  #if MODS_ALLOWED
  // Loads mods.
  inline static public function mods(key:String = '')
  {
    return (RecoveryBoot.disableMods ? RecoveryBoot.disabledModsPath() : 'mods/') + key;
  }

  // Loads fonts in mods/fonts.
  inline static public function modsFont(key:String)
  {
    return modFolders('fonts/' + key);
  }

  // Loads jsons in mods/data.
  inline static public function modsJson(key:String)
  {
    return modFolders('data/' + key + '.json');
  }

  // Loads videos in mods/videos.
  inline static public function modsVideo(key:String)
  {
    return modFolders('videos/' + key + '.' + VIDEO_EXT);
  }

  /**
   * Resolves a sound inside the enabled mod folders, e.g.
   * `modsSounds('songs', 'bopeebo/Inst')`.
   *
   * Returns the first existing container from `SOUND_EXTENSIONS` (ogg, then
   * mp3), or `null` when the mod ships neither -- callers then fall back to the
   * engine's own asset libraries.
   */
  static public function modsSounds(path:String, key:String):String
  {
    for (ext in SOUND_EXTENSIONS)
    {
      final candidate:String = modFolders(path + '/' + key + '.' + ext);
      if (FileSystem.exists(candidate)) return candidate;
    }
    return null;
  }

  // Loads images in mods/images.
  inline static public function modsImages(key:String)
  {
    return modFolders('images/' + key + '.png');
  }

  // Loads xml files in mods/images.
  inline static public function modsXml(key:String)
  {
    return modFolders('images/' + key + '.xml');
  }

  // Loads txt files in mods/images.
  inline static public function modsTxt(key:String)
  {
    return modFolders('images/' + key + '.txt');
  }

  inline static public function modsImagesJson(key:String)
    return modFolders('images/' + key + '.json');

  public static function playModMusic(file:String, fallback:String, volume:Float = 1):Void
  {
    // modsSounds() already walks SOUND_EXTENSIONS (ogg then mp3) and returns
    // null when the track is absent, so menu themes can ship either format.
    for (key in [file, fallback])
    {
      final track:String = Paths.modsSounds('music', key);
      if (track != null)
      {
        FlxG.sound.playMusic(Paths.music(key), volume, true);
        return;
      }
    }
    if (Paths.resolveSoundAsset('music', file) != null)
    {
      FlxG.sound.playMusic(Paths.music(file), volume);
      #if MAIN_DEBUG
      trace('fallback to base selected theme: ' + file);
      #end
    } else
    {
      FlxG.sound.playMusic(Paths.music(fallback), volume);
      #if MAIN_DEBUG
      trace('fallback to default: ' + fallback);
      #end
    }
  }

  static public function modFolders(key:String)
  {
    // A key that already points inside mods/ (e.g. a mod's `pack.png` icon,
    // passed as `mods/<folder>/pack.png`) is a complete path. Prepending the
    // mods root again would look for `mods/mods/...`, which never exists, so
    // the asset silently failed to load and every mod fell back to the
    // placeholder icon in the mods menu. Return it unchanged.
    if (RecoveryBoot.disableMods) return mods(key);
    if (key.startsWith('mods/')) return key;

    if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
    {
      var fileToCheck:String = mods(Mods.currentModDirectory + '/' + key);
      if (FileSystem.exists(fileToCheck))
      {
        return fileToCheck;
      }
    }

    for (mod in Mods.getGlobalMods())
    {
      var fileToCheck:String = mods(mod + '/' + key);
      if (FileSystem.exists(fileToCheck)) return fileToCheck;
    }
    return mods(key);
  }

  public static function getBackupFilePath(songPath:String, diff:String):String
  {
    final fileName = songPath + "-" + diff + ".json";
    return Paths.modsJson("$songPath/$fileName");
  }
  #end

  #if flxanimate
  public static function loadAnimateAtlas(spr:FlxAnimate, folderOrImg:Dynamic, spriteJson:Dynamic = null, animationJson:Dynamic = null)
  {
    var changedAnimJson = false;
    var changedAtlasJson = false;
    var changedImage = false;

    if (spriteJson != null)
    {
      changedAtlasJson = true;
      #if sys
      spriteJson = File.getContent(spriteJson);
      #else
      spriteJson = Assets.getText(spriteJson);
      #end
    }

    if (animationJson != null)
    {
      changedAnimJson = true;
      #if sys
      animationJson = File.getContent(animationJson);
      #else
      animationJson = Assets.getText(animationJson);
      #end
    }

    // is folder or image path
    if (Std.isOfType(folderOrImg, String))
    {
      var originalPath:String = folderOrImg;
      for (i in 0...10)
      {
        var st:String = '$i';
        if (i == 0) st = '';

        if (!changedAtlasJson)
        {
          if (fileExists('images/$originalPath/spritemap$st.json', TEXT, false))
          {
            spriteJson = getTextFromFile('images/$originalPath/spritemap$st.json');
            if (spriteJson != null)
            {
              // trace('found Sprite Json');
              changedImage = true;
              changedAtlasJson = true;
              folderOrImg = image('$originalPath/spritemap$st');
              break;
            }
          }
        } else if (fileExists('images/$originalPath/spritemap$st.png', IMAGE))
        {
          // trace('found Sprite PNG');
          changedImage = true;
          folderOrImg = image('$originalPath/spritemap$st');
          break;
        }
      }

      if (!changedImage)
      {
        // trace('Changing folderOrImg to FlxGraphic');
        changedImage = true;
        folderOrImg = image(originalPath);
      }

      if (!changedAnimJson)
      {
        // trace('found Animation Json');
        changedAnimJson = true;
        animationJson = getTextFromFile('images/$originalPath/Animation.json');
      }
    }
    spr.loadAtlasEx(folderOrImg, spriteJson, animationJson);
  }
  #end
}
