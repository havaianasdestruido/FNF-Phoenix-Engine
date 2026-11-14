package states;

import backend.Paths;
import flixel.FlxG;
import flixel.FlxState;
import flixel.util.typeLimit.NextState;
import play.PlayState;

/** Resolves a loading-screen target without calling a factory during the old state. */
class LoadingStateRouter
{
  /**
   * Preview the target exactly once, preserving a factory for FlxG.resetState.
   * Call this only after the previous state has been destroyed, unless the
   * caller already supplied an instance. The returned factory yields the
   * preview on its first call and constructs fresh instances on subsequent calls.
   */
  public static function prepare(target:NextState):{preview:FlxState, target:NextState}
  {
    final preview:FlxState = target.createInstance();
    final raw:Dynamic = cast target;
    if (Std.isOfType(raw, FlxState)) return {preview: preview, target: target};

    var first:FlxState = preview;
    final reusable:NextState = function():FlxState
    {
      if (first != null)
      {
        final result:FlxState = first;
        first = null;
        return result;
      }
      return target.createInstance();
    };
    return {preview: preview, target: reusable};
  }

  /**
   * Instances keep the legacy switchTo semantics. A class or factory is
   * resolved by Flixel after the old state is destroyed, not when requested.
   */
  public static function route(target:NextState, stopMusic:Bool, directory:String):NextState
  {
    final raw:Dynamic = cast target;
    if (Std.isOfType(raw, FlxState)) return choose(prepare(target), stopMusic, directory);
    return function():FlxState return choose(prepare(target), stopMusic, directory).createInstance();
  }

  static function choose(prepared:{preview:FlxState, target:NextState}, stopMusic:Bool, directory:String):NextState
  {
    final isSong:Bool = Std.isOfType(prepared.preview, PlayState);
    if (isSong || Std.isOfType(prepared.preview, TitleState))
    {
      #if NO_PRELOAD_ALL
      var loaded:Bool = false;
      // This old cache probe obtains decoded sounds. Do not do it before the
      // experimental PlayState gets a chance to stream them instead.
      if (PlayState.SONG != null && !(isSong && backend.LowMemory.policy().skipSongPreload))
      {
        try
        {
          loaded = isSoundLoaded(Paths.inst(PlayState.SONG.song))
            && (!PlayState.SONG.needsVoices || isSoundLoaded(Paths.voices(PlayState.SONG.song)))
            && isLibraryLoaded('shared') && isLibraryLoaded(directory);
        }
        catch (_:Dynamic) loaded = false;
      }
      if (!loaded)
      #end
        return new LoadingState(prepared.target, stopMusic, directory);
    }

    if (stopMusic && FlxG.sound.music != null) FlxG.sound.music.stop();
    return prepared.target;
  }

  #if NO_PRELOAD_ALL
  static function isSoundLoaded(path:Dynamic):Bool
  {
    try return OpenFlAssets.cache.hasSound(Std.string(path)) catch (_:Dynamic) return false;
  }

  static function isLibraryLoaded(library:String):Bool
  {
    try return OpenFlAssets.getLibrary(library) != null catch (_:Dynamic) return false;
  }
  #end
}
