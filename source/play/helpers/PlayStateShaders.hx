package play.helpers;

import data.StageData.StageFile;
import play.PlayState;

// The real implementation needs a GL render context and the runtime-shader
// types, which only exist where shaders are supported at all.
#if (SHADERS_ALLOWED && !neko)
import backend.ClientPrefs;
import backend.VLog;
import shaders.ShaderWarmup;
import shaders.ShaderWarmupPlan;
import shaders.ShaderWarmupRegistry;

/**
 * [P3] Shader warm-up for a song.
 *
 * Shaders are compiled lazily by the driver the first time they are drawn, so
 * the first bop of a song pays for the stage's camera filter, for the `Pulse`
 * event's `RuntimeShaders` shader and for any runtime shader a mod created
 * during loading. `PlayState.create()` calls `beginLoad()` first and `warmUp()`
 * right before the countdown starts, so all of that lands while the loading
 * transition is still on screen instead of on a gameplay frame.
 *
 * What gets compiled:
 *  - the song-wide `PlayState.screenshader` (the `Pulse`/`RuntimeShaders` path);
 *  - every instance a stage hands over in `BaseStage.declareShaders()`;
 *  - every name a stage declares in its JSON (`"shaders": ["rain", ...]`),
 *    resolved against `ShaderWarmupRegistry` and then, fallback, against the
 *    mod's `shaders/<name>.frag` files (the same ones Lua's `initShader` uses);
 *  - runtime shaders scripts instantiated while the state was loading, which
 *    `PlayStateScripts.createRuntimeShader()` queues through
 *    `ShaderWarmup.track()`.
 */
class PlayStateShaders
{
  /**
   * Starts the loading phase so shaders created from now on (stage classes,
   * Lua/Python/HScript scripts) are queued for `warmUp()`.
   */
  public static function beginLoad():Void
  {
    if (!ClientPrefs.shaders) return;
    ShaderWarmup.beginLoading();
  }

  /**
   * Compiles everything this stage/song declares.
   *
   * Safe to call on any backend: when shader programs cannot be pre-compiled
   * the calls are counted as unsupported and gameplay is unaffected.
   *
   * @param state The gameplay state being created.
   * @param stageData The stage file `PlayState` already loaded from the chart.
   * @return How many shaders ended up with a usable program.
   */
  public static function warmUp(state:PlayState, stageData:StageFile):Int
  {
    if (!ClientPrefs.shaders)
    {
      // Drop whatever was queued and stop collecting: nothing will be compiled.
      ShaderWarmup.endLoading();
      return 0;
    }

    var warmed:Int = 0;

    // 1. Song-wide runtime shader (`RuntimeShaders.pulseEffect`). The "Pulse"
    //    event attaches it to the camera on its first step, so without this it
    //    is compiled during gameplay.
    if (PlayState.screenshader != null && ShaderWarmup.warm(PlayState.screenshader.shader, 'pulse')) warmed++;

    // 2. Shader instances the stage classes render with.
    if (state != null && state.stages != null)
    {
      for (i in 0...state.stages.length)
      {
        var stage = state.stages[i];
        if (stage == null) continue;
        warmed += ShaderWarmup.warmAll(stage.declareShaders(), Type.getClassName(Type.getClass(stage)));
      }
    }

    // 3. Names the stage JSON declares.
    var declared:Array<String> = ShaderWarmupPlan.declaredNames(stageData != null ? stageData.shaders : null);
    for (i in 0...declared.length)
      if (warmDeclared(state, declared[i])) warmed++;

    // 4. Runtime shaders scripts created while the state was loading.
    warmed += ShaderWarmup.endLoading();

    if (VLog.isActive() && warmed > 0) VLog.log('shader', ShaderWarmup.summary());

    return warmed;
  }

  /**
   * Resolves and compiles one declared name: built-in shader first, then a
   * runtime shader from the active mods' `shaders/` folder.
   */
  static function warmDeclared(state:PlayState, name:String):Bool
  {
    if (ShaderWarmupRegistry.exists(name))
      return ShaderWarmup.warm(ShaderWarmupRegistry.create(name), name);

    if (state == null) return false;

    // Mod shaders live in `shaders/<name>.frag`: same lookup `initShader` does,
    // with the declared spelling (filesystems are case-sensitive). A missing
    // file is reported by `initLuaShader()` itself.
    var fileName:String = ShaderWarmupPlan.runtimeName(name);
    if (fileName.length == 0) return false;

    if (!state.runtimeShaders.exists(fileName)) state.initLuaShader(fileName);

    if (state.runtimeShaders.exists(fileName))
      return ShaderWarmup.warm(state.createRuntimeShader(fileName), name);

    return false;
  }
}
#else
/** Shader pre-compilation is not available on this target: every call is a no-op. */
class PlayStateShaders
{
  public static function beginLoad():Void {}

  public static function warmUp(state:PlayState, stageData:StageFile):Int return 0;
}
#end
