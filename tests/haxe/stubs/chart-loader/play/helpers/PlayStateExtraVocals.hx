package play.helpers;

import flixel.sound.FlxSound;

/**
 * Minimal stub of `ExtraVocalTrack` for the isolated `ChartLoaderSpec` harness.
 */
class ExtraVocalTrack
{
  public var name:String = '';
  public var file:String = '';
  public var side:String = '';
  public var sound:FlxSound;

  /** @param name Stem label. */
  public function new(name:String = '')
  {
    this.name = name;
  }
}

/**
 * Minimal stub of `PlayStateExtraVocals` for `tests/haxe/run-chart-loader.sh`.
 */
class PlayStateExtraVocals
{
  /**
   * Stubbed stem loader; returns an empty array without touching audio files.
   * @param raw Raw chart `extraVocals` field.
   * @param song Song identifier.
   * @param diff Difficulty string.
   * @param stream Whether streaming audio was requested.
   * @return Empty track list.
   */
  public static function load(raw:Dynamic, song:String, diff:String, stream:Bool):Array<ExtraVocalTrack>
  {
    return [];
  }

  /**
   * Stubbed pitch setter.
   * @param tracks Loaded extra vocal tracks.
   * @param pitch Target playback pitch.
   */
  public static function setPitchAll(tracks:Array<ExtraVocalTrack>, pitch:Float):Void {}

  /**
   * Stubbed track disposer.
   * @param tracks Loaded extra vocal tracks to clear.
   */
  public static function dispose(tracks:Array<ExtraVocalTrack>):Void
  {
    if (tracks != null) tracks.resize(0);
  }
}
