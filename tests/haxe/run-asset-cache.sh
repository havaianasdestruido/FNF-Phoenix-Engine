#!/usr/bin/env bash
# Exercise backend/Paths.hx + backend/MemoryLedger.hx in the Haxe interpreter
# with lightweight OpenFL/Lime/Flixel stubs (no native build or haxelibs needed).
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT

mkdir -p \
  "$test_source/work" \
  "$test_source/src/backend" \
  "$test_source/src/utils" \
  "$test_source/src/data" \
  "$test_source/src/objects" \
  "$test_source/src/objects/helpers" \
  "$test_source/src/headers" \
  "$test_source/src/play" \
  "$test_source/src/debug" \
  "$test_source/src/flixel/animation" \
  "$test_source/src/flixel/graphics/frames" \
  "$test_source/src/flixel/math" \
  "$test_source/src/flixel/sound" \
  "$test_source/src/flixel/system/frontEnds" \
  "$test_source/src/openfl/display" \
  "$test_source/src/openfl/display3D" \
  "$test_source/src/openfl/display3D/textures" \
  "$test_source/src/openfl/geom" \
  "$test_source/src/openfl/media" \
  "$test_source/src/openfl/system" \
  "$test_source/src/openfl/utils" \
  "$test_source/src/lime/media/vorbis" \
  "$test_source/src/lime/utils"

cp source/backend/Paths.hx "$test_source/src/backend/"
cp source/backend/MemoryLedger.hx "$test_source/src/backend/"
cp source/utils/MemoryUtil.hx "$test_source/src/utils/"
cp tests/haxe/AssetCacheSpec.hx "$test_source/src/"

cat > "$test_source/src/import.hx" <<'HAXE'
#if !macro
import backend.Paths;
import backend.ClientPrefs;
import backend.CoolUtil;
import backend.Mods;
import backend.NoteHelpers;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import lime.utils.Assets;
import openfl.utils.Assets as OpenFlAssets;
import sys.FileSystem;
import sys.io.File;
import utils.DateUtils;

using StringTools;
#end
HAXE

cat > "$test_source/src/backend/VLog.hx" <<'HAXE'
package backend;
class VLog
{
  public static function heapUsedBytes():Float return 1000000;
  public static function formatBytes(b:Float):String return Std.string(Std.int(b)) + 'B';
  public static function assetCached(kind:String, key:String, detail:String):Void {}
  public static function memoryEvent(msg:String):Void {}
}
HAXE

cat > "$test_source/src/backend/ClientPrefs.hx" <<'HAXE'
package backend;
class ClientPrefs
{
  public static var cacheOnGPU:Bool = false;
  public static var daMenuMusic:String = 'Default';
}
HAXE

cat > "$test_source/src/backend/Mods.hx" <<'HAXE'
package backend;
class Mods
{
  public static var currentModDirectory:String = '';
  public static var ignoreModFolders:Array<String> =
    ['images', 'data', 'songs', 'sounds', 'fonts', 'videos', 'weeks', 'scripts', 'stages', 'characters'];
  private static var globalMods:Array<String> = [];
  public static function getGlobalMods():Array<String> return globalMods;
}
HAXE

cat > "$test_source/src/backend/CoolUtil.hx" <<'HAXE'
package backend;
class CoolUtil
{
  public static function coolTextFile(path:String):Array<String> return [];
}
HAXE

cat > "$test_source/src/backend/NoteHelpers.hx" <<'HAXE'
package backend;
class NoteHelpers
{
  public static function getNoteSkinPostfix():String return '';
}
HAXE

cat > "$test_source/src/debug/FrameProfiler.hx" <<'HAXE'
package debug;
class FrameProfiler
{
  public static function beginGC(major:Bool):Void {}
  public static function endGC():Void {}
}
HAXE

cat > "$test_source/src/data/Song.hx" <<'HAXE'
package data;
class Song {}
HAXE

cat > "$test_source/src/headers/Objects.hx" <<'HAXE'
package headers;
class Objects {}
HAXE

cat > "$test_source/src/play/PlayState.hx" <<'HAXE'
package play;
class PlayState
{
  public static var isPixelStage:Bool = false;
}
HAXE

cat > "$test_source/src/objects/Note.hx" <<'HAXE'
package objects;
class Note
{
  public static var colArray:Array<String> = ['purple', 'blue', 'green', 'red'];
}
HAXE

cat > "$test_source/src/objects/NoteSplash.hx" <<'HAXE'
package objects;
typedef NoteSplashConfig = {
  anim:String,
  minFps:Int,
  maxFps:Int,
  offsets:Array<Array<Float>>
}
class NoteSplash
{
  public static function getSplashSkinPostfix():String return '';
}
HAXE

cat > "$test_source/src/openfl/utils/AssetType.hx" <<'HAXE'
package openfl.utils;
enum abstract AssetType(String) from String to String
{
  var BINARY = "BINARY";
  var FONT = "FONT";
  var IMAGE = "IMAGE";
  var MUSIC = "MUSIC";
  var MOVIE_CLIP = "MOVIE_CLIP";
  var SOUND = "SOUND";
  var TEMPLATE = "TEMPLATE";
  var TEXT = "TEXT";
}
HAXE

cat > "$test_source/src/openfl/geom/Rectangle.hx" <<'HAXE'
package openfl.geom;
class Rectangle
{
  public function new(x:Float = 0, y:Float = 0, w:Float = 0, h:Float = 0) {}
}
HAXE

cat > "$test_source/src/openfl/display3D/Context3D.hx" <<'HAXE'
package openfl.display3D;
class Context3D
{
  public function new() {}
}
HAXE

cat > "$test_source/src/openfl/display3D/textures/RectangleTexture.hx" <<'HAXE'
package openfl.display3D.textures;
class RectangleTexture
{
  public var disposed:Bool = false;
  public function new() {}
  public function dispose():Void disposed = true;
}
HAXE

cat > "$test_source/src/openfl/display/BitmapData.hx" <<'HAXE'
package openfl.display;
class FakeImage
{
  public var premultiplied:Bool = false;
  public var data:Dynamic = {};
  public function new() {}
}
class BitmapData
{
  public var width:Int;
  public var height:Int;
  public var readable:Bool = true;
  public var image:FakeImage = new FakeImage();
  public var __texture:openfl.display3D.textures.RectangleTexture = null;
  public var __surface:Dynamic = null;

  public function new(w:Int = 64, h:Int = 64)
  {
    this.width = w;
    this.height = h;
  }

  public static function fromFile(path:String):BitmapData
  {
    return sys.FileSystem.exists(path) ? new BitmapData(64, 64) : null;
  }

  public function lock():Void {}
  public function unlock():Void {}
  public function disposeImage():Void {}
  public function getTexture(ctx:Dynamic):openfl.display3D.textures.RectangleTexture
  {
    if (__texture == null) __texture = new openfl.display3D.textures.RectangleTexture();
    return __texture;
  }
}
HAXE

cat > "$test_source/src/lime/utils/UInt8Array.hx" <<'HAXE'
package lime.utils;
class UInt8Array
{
  public var length:Int;
  public function new(length:Int) this.length = length;
}
HAXE

cat > "$test_source/src/lime/media/AudioBuffer.hx" <<'HAXE'
package lime.media;
class AudioBuffer
{
  public var data:lime.utils.UInt8Array;
  public function new(bytes:Int = 1024) this.data = new lime.utils.UInt8Array(bytes);
  public static function fromVorbisFile(vf:Dynamic):AudioBuffer return new AudioBuffer(1024);
}
HAXE

cat > "$test_source/src/lime/media/vorbis/VorbisFile.hx" <<'HAXE'
package lime.media.vorbis;
class VorbisFile
{
  public static function fromFile(path:String):VorbisFile return new VorbisFile();
  public function new() {}
}
HAXE

cat > "$test_source/src/openfl/media/Sound.hx" <<'HAXE'
package openfl.media;
class Sound
{
  public var bytesTotal:Int = 0;
  public var __buffer:lime.media.AudioBuffer;
  public var closed:Bool = false;

  public function new(pcmBytes:Int = 4096)
  {
    this.__buffer = new lime.media.AudioBuffer(pcmBytes);
  }

  public static function fromFile(path:String):Sound
  {
    return sys.FileSystem.exists(path) ? new Sound(8192) : null;
  }

  public static function fromAudioBuffer(buf:lime.media.AudioBuffer):Sound
  {
    var s = new Sound(0);
    s.__buffer = buf;
    return s;
  }

  public function close():Void
  {
    closed = true;
    __buffer = null;
  }
}
HAXE

cat > "$test_source/src/openfl/system/System.hx" <<'HAXE'
package openfl.system;
class System
{
  public static function gc():Void {}
}
HAXE

cat > "$test_source/src/lime/utils/Assets.hx" <<'HAXE'
package lime.utils;
class LimeCacheStub
{
  public var cleared:Array<String> = [];
  public function new() {}
  public function clear(?prefix:String):Void
  {
    if (prefix != null) cleared.push(prefix);
  }
}
class Assets
{
  public static var cache:LimeCacheStub = new LimeCacheStub();
  public static function exists(id:String, ?type:Dynamic):Bool
  {
    return openfl.utils.Assets.texts.exists(id);
  }
  public static function getText(id:String):String
  {
    if (!openfl.utils.Assets.texts.exists(id)) throw 'LimeAssets missing text: ' + id;
    return openfl.utils.Assets.texts.get(id);
  }
}
HAXE

cat > "$test_source/src/openfl/utils/Assets.hx" <<'HAXE'
package openfl.utils;
import openfl.display.BitmapData;
import openfl.media.Sound;

class OpenFlCacheStub
{
  public var bitmapData:Map<String, BitmapData> = [];
  public var sound:Map<String, Sound> = [];
  public function new() {}
  public function hasBitmapData(id:String):Bool return bitmapData.exists(id);
  public function removeBitmapData(id:String):Void bitmapData.remove(id);
  public function hasSound(id:String):Bool return sound.exists(id);
  public function removeSound(id:String):Void sound.remove(id);
  public function clear(?prefix:String):Void {}
}

class Assets
{
  public static var cache:OpenFlCacheStub = new OpenFlCacheStub();
  public static var imageDims:Map<String, Array<Int>> = [];
  public static var soundSizes:Map<String, Int> = [];
  public static var texts:Map<String, String> = [];
  public static var bitmapDecodeCount:Int = 0;
  public static var existsCallCount:Int = 0;

  public static function registerStubImage(id:String, w:Int, h:Int):Void imageDims.set(id, [w, h]);
  public static function registerStubSound(id:String, bytes:Int):Void soundSizes.set(id, bytes);
  public static function registerStubText(id:String, content:String):Void texts.set(id, content);

  public static function exists(id:String, ?type:AssetType):Bool
  {
    existsCallCount++;
    return imageDims.exists(id) || soundSizes.exists(id) || texts.exists(id);
  }

  public static function getBitmapData(id:String, useCache:Bool = true):BitmapData
  {
    if (useCache && cache.bitmapData.exists(id)) return cache.bitmapData.get(id);
    final dims = imageDims.get(id);
    if (dims == null) return null;
    bitmapDecodeCount++;
    final bmp = new BitmapData(dims[0], dims[1]);
    if (useCache) cache.bitmapData.set(id, bmp);
    return bmp;
  }

  public static function getSound(id:String, useCache:Bool = true):Sound
  {
    if (useCache && cache.sound.exists(id))
    {
      final s = cache.sound.get(id);
      if (s != null && s.__buffer != null) return s;
    }
    final sz = soundSizes.get(id);
    if (sz == null) return null;
    final snd = new Sound(sz);
    if (useCache) cache.sound.set(id, snd);
    return snd;
  }

  public static function getMusic(id:String, useCache:Bool = true):Sound return getSound(id, useCache);
  public static function getText(id:String):String return texts.get(id);
}
HAXE

cat > "$test_source/src/openfl/Assets.hx" <<'HAXE'
package openfl;
typedef Assets = openfl.utils.Assets;
HAXE

cat > "$test_source/src/flixel/math/FlxPoint.hx" <<'HAXE'
package flixel.math;
class FlxPoint
{
  public var x:Float;
  public var y:Float;
  public function new(x:Float = 0, y:Float = 0)
  {
    this.x = x;
    this.y = y;
  }
}
HAXE

cat > "$test_source/src/flixel/graphics/FlxGraphic.hx" <<'HAXE'
package flixel.graphics;
import openfl.display.BitmapData;
import flixel.graphics.frames.FlxAtlasFrames;

class FlxGraphic
{
  public var key:String;
  public var bitmap:BitmapData;
  public var persist:Bool = false;
  public var destroyOnNoUse:Bool = true;
  public var isDestroyed:Bool = false;
  public var atlasFrames:FlxAtlasFrames = null;

  public function new(key:String, bitmap:BitmapData)
  {
    this.key = key;
    this.bitmap = bitmap;
  }

  public static function fromBitmapData(bmp:BitmapData, unique:Bool = false, ?key:String):FlxGraphic
  {
    if (bmp == null) return null;
    var g = new FlxGraphic(key, bmp);
    if (key != null) flixel.FlxG.bitmap.set(key, g);
    return g;
  }

  public function destroy():Void
  {
    isDestroyed = true;
    bitmap = null;
    atlasFrames = null;
  }
}
HAXE

cat > "$test_source/src/flixel/graphics/frames/FlxFramesCollection.hx" <<'HAXE'
package flixel.graphics.frames;
import flixel.graphics.FlxGraphic;

class FlxFramesCollection
{
  public var parent:FlxGraphic;
  public function new(parent:FlxGraphic) this.parent = parent;
}
HAXE

cat > "$test_source/src/flixel/graphics/frames/FlxAtlasFrames.hx" <<'HAXE'
package flixel.graphics.frames;
import flixel.graphics.FlxGraphic;
import flixel.math.FlxPoint;

class FlxAtlasFrames extends FlxFramesCollection
{
  public function new(parent:FlxGraphic)
  {
    super(parent);
  }

  public static function findFrame(graphic:FlxGraphic, ?border:FlxPoint):FlxAtlasFrames
  {
    if (graphic == null || graphic.isDestroyed) return null;
    return graphic.atlasFrames;
  }

  public static function fromSparrow(source:FlxGraphic, xml:Dynamic):FlxAtlasFrames
  {
    if (source == null || xml == null) return null;
    if (source.atlasFrames == null) source.atlasFrames = new FlxAtlasFrames(source);
    return source.atlasFrames;
  }

  public static function fromSpriteSheetPacker(source:FlxGraphic, txt:Dynamic):FlxAtlasFrames
  {
    if (source == null || txt == null) return null;
    if (source.atlasFrames == null) source.atlasFrames = new FlxAtlasFrames(source);
    return source.atlasFrames;
  }

  public static function fromTexturePackerJson(source:FlxGraphic, json:Dynamic):FlxAtlasFrames
  {
    if (source == null || json == null) return null;
    if (source.atlasFrames == null) source.atlasFrames = new FlxAtlasFrames(source);
    return source.atlasFrames;
  }

  public function addAtlas(other:FlxAtlasFrames, overwrite:Bool = false):Void {}
}
HAXE

cat > "$test_source/src/flixel/animation/FlxAnimationController.hx" <<'HAXE'
package flixel.animation;
class FlxAnimationController
{
  var spr:Dynamic;
  public function new(spr:Dynamic) this.spr = spr;
  public function addByPrefix(name:String, prefix:String, frameRate:Float = 30, looped:Bool = true):Void {}
  public function findByPrefix(animFrames:Array<Dynamic>, prefix:String):Void {}
}
HAXE

cat > "$test_source/src/flixel/FlxSprite.hx" <<'HAXE'
package flixel;
import flixel.animation.FlxAnimationController;
import flixel.graphics.frames.FlxFramesCollection;

class FlxSprite
{
  public var frames:FlxFramesCollection;
  public var animation:FlxAnimationController;
  public function new() this.animation = new FlxAnimationController(this);
}
HAXE

cat > "$test_source/src/flixel/sound/FlxSound.hx" <<'HAXE'
package flixel.sound;
class FlxSound
{
  public var playing:Bool = false;
  public var _sound:openfl.media.Sound = null;
  public function new() {}
}
HAXE

cat > "$test_source/src/flixel/system/frontEnds/BitmapFrontEnd.hx" <<'HAXE'
package flixel.system.frontEnds;
import flixel.graphics.FlxGraphic;

class BitmapFrontEnd
{
  public var _cache:Map<String, FlxGraphic> = [];
  public function new() {}
  public function get(key:String):FlxGraphic return _cache.get(key);
  public function set(key:String, g:FlxGraphic):Void _cache.set(key, g);
  public function remove(g:FlxGraphic):Void
  {
    if (g != null)
    {
      if (g.key != null) _cache.remove(g.key);
      g.destroy();
    }
  }
}
HAXE

cat > "$test_source/src/utils/DateUtils.hx" <<'HAXE'
package utils;
class DateUtils
{
  public static function isAprilFools():Bool return false;
}
HAXE

cat > "$test_source/src/flixel/FlxG.hx" <<'HAXE'
package flixel;
import flixel.sound.FlxSound;
import flixel.system.frontEnds.BitmapFrontEnd;

class RandomStub
{
  public function new() {}
  public function int(min:Int = 0, max:Int = 1):Int return min;
}

class SoundListStub
{
  public var members:Array<FlxSound> = [];
  public function new() {}
}

class SoundFrontEndStub
{
  public var music:FlxSound = null;
  public var list:SoundListStub = new SoundListStub();
  public function new() {}
  public function playMusic(snd:openfl.media.Sound, volume:Float = 1, looped:Bool = true):Void
  {
    music = new FlxSound();
    music.playing = true;
    music._sound = snd;
  }
}

class StageStub
{
  public var context3D:openfl.display3D.Context3D = null;
  public function new() {}
}

class FlxG
{
  public static var bitmap:BitmapFrontEnd = new BitmapFrontEnd();
  public static var sound:SoundFrontEndStub = new SoundFrontEndStub();
  public static var stage:StageStub = new StageStub();
  public static var random:RandomStub = new RandomStub();
}
HAXE

(
  cd "$test_source/work"
  haxe -cp "$test_source/src" -D MODS_ALLOWED --main AssetCacheSpec --interp
  haxe -cp "$test_source/src" --no-output backend.Paths
)
