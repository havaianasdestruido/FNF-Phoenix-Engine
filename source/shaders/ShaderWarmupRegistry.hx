package shaders;

import openfl.display.Shader;

import shaders.BlockedGlitchShader;
import shaders.BloomShader;
import shaders.BrightnessContrastShader;
import shaders.BuildingShader;
import shaders.ChromaticAberrationShader;
import shaders.CRTShader;
import shaders.DistantNoteShader;
import shaders.DistortBGShader;
import shaders.GlitchShader;
import shaders.Grain;
import shaders.GreyscaleShader;
import shaders.InvertShader;
import shaders.MosaicShader;
import shaders.OldTVShader;
import shaders.PulseShader;
import shaders.RainShader;
import shaders.RGBPalette.RGBPaletteShader;
import shaders.RippleShader;
import shaders.Scanline;
import shaders.SilhouetteShader;
import shaders.ThreeDShader;
import shaders.Tiltshift;
import shaders.TVStaticShader;
import shaders.VCRBorderShader;
import shaders.VCRDistortionShader;
import shaders.VCRFuzzShader;
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
      'brightness' => function():Shader return new BrightnessContrastShader(),
      'brightnesscontrast' => function():Shader return new BrightnessContrastShader(),
      'building' => function():Shader return new BuildingShader(),
      'chromatic' => function():Shader return new ChromaticAberrationShader(),
      'chromaticaberration' => function():Shader return new ChromaticAberrationShader(),
      'crt' => function():Shader return new CRTShader(),
      'distant' => function():Shader return new DistantNoteShader(),
      'distantnote' => function():Shader return new DistantNoteShader(),
      'distantnoteshader' => function():Shader return new DistantNoteShader(),
      'distortbg' => function():Shader return new DistortBGShader(),
      'glitch' => function():Shader return new GlitchShader(),
      'grain' => function():Shader return new Grain(),
      'grayscale' => function():Shader return new GreyscaleShader(),
      'greyscale' => function():Shader return new GreyscaleShader(),
      'invert' => function():Shader return new InvertShader(),
      // `pixelblur` and `smwpixelblur` are the names Mario Madness' wrapper
      // around this shader used (`SMWPixelBlurShader`); `shaders.MosaicEffect`
      // keeps its `setStrength()` for the same reason.
      'mosaic' => function():Shader return new MosaicShader(),
      'oldtv' => function():Shader return new OldTVShader(),
      'pixelblur' => function():Shader return new MosaicShader(),
      'rain' => function():Shader return new RainShader(),
      'rgbpalette' => function():Shader return new RGBPaletteShader(),
      'ripple' => function():Shader return new RippleShader(),
      'scanline' => function():Shader return new Scanline(),
      'silhouette' => function():Shader return new SilhouetteShader(),
      'smwpixelblur' => function():Shader return new MosaicShader(),
      'threed' => function():Shader return new ThreeDShader(),
      'tiltshift' => function():Shader return new Tiltshift(),
      'tvstatic' => function():Shader return new TVStaticShader(),
      'vcr' => function():Shader return new VCRDistortionShader(),
      'vcrborder' => function():Shader return new VCRBorderShader(),
      'vcrdistortion' => function():Shader return new VCRDistortionShader(),
      // `vcrmario85` is the name this shader has upstream; Phoenix calls it
      // `VCRFuzzShader` after what it does rather than after the song.
      'vcrfuzz' => function():Shader return new VCRFuzzShader(),
      'vcrmario85' => function():Shader return new VCRFuzzShader(),
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
