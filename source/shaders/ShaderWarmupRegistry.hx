package shaders;

import openfl.display.Shader;

import shaders.BlockedGlitchShader;
import shaders.BloomShader;
import shaders.BuildingShader;
import shaders.ChromaticAberrationShader;
import shaders.DistantNoteShader;
import shaders.DistortBGShader;
import shaders.GlitchShader;
import shaders.Grain;
import shaders.GreyscaleShader;
import shaders.InvertShader;
import shaders.PulseShader;
import shaders.RainShader;
import shaders.RGBPalette.RGBPaletteShader;
import shaders.Scanline;
import shaders.ThreeDShader;
import shaders.Tiltshift;
import shaders.VCRDistortionShader;
import shaders.VFDOverlay;

import shaders.ShaderWarmupPlan;

/**
 * Built-in shaders a stage/song can ask for by name, so `shaders.ShaderWarmup`
 * can compile them without a stage class having to create them first.
 *
 * Stages declare them in their JSON, next to `defaultZoom`, `stageUI` and the
 * character positions:
 *
 * ```json
 * {
 *   "directory": "",
 *   "defaultZoom": 0.9,
 *   "shaders": ["rain", "glitch"]
 * }
 * ```
 *
 * Names are matched through `ShaderWarmupPlan.normalizeName`, so `Rain`,
 * `rain.frag` and `shaders/rain.frag` all resolve to `rain`. Anything that is
 * not registered here is treated as a mod shader and loaded from
 * `<mod>/shaders/<name>.frag`, exactly like Lua's `initShader`.
 */
class ShaderWarmupRegistry
{
  /** Lazily built name -> factory table. */
  static var factories:Map<String, Void->Shader> = null;

  /**
   * Whether `name` is a built-in shader this registry can create.
   * @param name Name as declared by the stage (any spelling/case).
   */
  public static function exists(name:Null<String>):Bool
  {
    return factory(name) != null;
  }

  /**
   * Creates a fresh instance of the named built-in shader. The caller warms it
   * up (or renders with it) and can throw it away: what matters is the GLSL,
   * which is shared through the backend's program cache.
   *
   * @param name Name as declared by the stage (any spelling/case).
   * @return The shader, or `null` when the name is not a built-in.
   */
  public static function create(name:Null<String>):Shader
  {
    var make:Void->Shader = factory(name);
    return make != null ? make() : null;
  }

  /** Sorted list of every accepted name (for diagnostics and docs). */
  public static function names():Array<String>
  {
    var out:Array<String> = [];
    for (name in table().keys())
      out.push(name);
    out.sort(Reflect.compare);
    return out;
  }

  static function factory(name:Null<String>):Void->Shader
  {
    var normalized:String = ShaderWarmupPlan.normalizeName(name);
    if (normalized.length == 0) return null;
    return table().get(normalized);
  }

  static function table():Map<String, Void->Shader>
  {
    if (factories != null) return factories;

    factories = [
      '3d' => function():Shader return new ThreeDShader(),
      '3dshader' => function():Shader return new ThreeDShader(),
      'blockedglitch' => function():Shader return new BlockedGlitchShader(),
      'bloom' => function():Shader return new BloomShader(),
      'building' => function():Shader return new BuildingShader(),
      'chromatic' => function():Shader return new ChromaticAberrationShader(),
      'chromaticaberration' => function():Shader return new ChromaticAberrationShader(),
      'distant' => function():Shader return new DistantNoteShader(),
      'distantnote' => function():Shader return new DistantNoteShader(),
      'distortbg' => function():Shader return new DistortBGShader(),
      'glitch' => function():Shader return new GlitchShader(),
      'grain' => function():Shader return new Grain(),
      'grayscale' => function():Shader return new GreyscaleShader(),
      'greyscale' => function():Shader return new GreyscaleShader(),
      'invert' => function():Shader return new InvertShader(),
      'rain' => function():Shader return new RainShader(),
      'rgbpalette' => function():Shader return new RGBPaletteShader(),
      'scanline' => function():Shader return new Scanline(),
      'threed' => function():Shader return new ThreeDShader(),
      'tiltshift' => function():Shader return new Tiltshift(),
      'vcr' => function():Shader return new VCRDistortionShader(),
      'vcrdistortion' => function():Shader return new VCRDistortionShader(),
      'vfd' => function():Shader return new VFDOverlay()
    ];

    // `PulseShader` drives the song-wide `RuntimeShaders.pulseEffect`; it only
    // exists as a real shader on the backends that support runtime shaders.
    #if (SHADERS_ALLOWED && !flash && !neko)
    factories.set('pulse', function():Shader return new PulseShader());
    #end

    return factories;
  }
}
