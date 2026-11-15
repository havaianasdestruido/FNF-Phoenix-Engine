package psychlua.callbacks;

import backend.ChainableEffects;
import backend.ScreenFilters;
import flixel.util.FlxColor;
import openfl.filters.BitmapFilter;
import play.PlayState;
import psychlua.FunkinLua;
import headers.PsychLua;

/**
 * Plain (non-shader) filters and chainable pixel effects for every script
 * language.
 *
 * Two families live here:
 *
 * - `addFilter` / `addBlurFilter` / `addGlowFilter` / `addDropShadowFilter` /
 *   `addColorMatrixFilter` / `addConvolutionFilter` /
 *   `addDisplacementMapFilter` attach OpenFL `BitmapFilter`s to a camera or to
 *   `'global'` for the whole window (`FlxG.game.filters`). A sprite is not a
 *   filter target in Flixel: per-sprite looks are `sprite.shader` or the
 *   chainable effects below.
 *   Everything registered is addressable by name afterwards
 *   (`removeFilter`, `setFilterProperty`) and `clearFilters` drops only what
 *   scripts added, so a stage's own rain shader survives.
 * - `addChainableEffect` and the `addSprite*Effect` shorthands use
 *   `flixel.addons.effects.chainable` to shake/wave/glitch/rainbow/outline/trail
 *   a sprite's pixels.
 *
 * The whole surface is built once by `api()` and bound by every host, so Lua
 * (`register`), HScript (`seedHScript`) and Python
 * (`psychlua.pystdlib.PyFilterLib`) cannot drift apart. Shader effects keep
 * their own names (`addBloomEffect`, ...); a filter and a shader can sit on the
 * same camera, the filter stack simply runs around it.
 */
class FilterCallbacks
{
  /** Binds the API for a Lua script. */
  public static function register(funk:FunkinLua):Void
  {
    @:privateAccess {
      api(FunkinLua.registerFunction, function(message:String, color:FlxColor) {
        LuaUtils.luaTrace(funk.lua, message, false, false, color);
      });
    }
  }

  /**
   * Seeds the same API into an HScript interpreter's scope.
   *
   * HScript inherits the shared Lua registry when any Lua script is loaded, but
   * a mod that ships only `.hx` scripts has no Lua parent, so the names are set
   * directly (the same reason `WindowCallbacks.seedHScript` exists).
   */
  public static function seedHScript(interp:Dynamic):Void
  {
    api(function(name:String, func:Dynamic) interp.variables.set(name, func), function(message:String, color:FlxColor) {
      trace(message);
      if (PlayState.instance != null) PlayState.instance.addTextToDebug(message, color);
    });
  }

  /**
   * Registers the whole filter/chainable surface.
   *
   * @param register Host binding, `(name, function)`.
   * @param trace    Host warning sink, used for bad targets, unknown types and
   *                 missing presets.
   */
  public static function api(register:(String, Dynamic)->Void, trace:(String, FlxColor)->Void):Void
  {
    // ---------------------------------------------------------------- //
    //                        OPENFL FILTERS                            //
    // ---------------------------------------------------------------- //

    // Attaches a filter in one call. `type` is one of 'blur', 'glow',
    // 'shadow'/'dropshadow', 'colormatrix'/'matrix', 'convolution' or
    // 'displacement'; `name` is what removeFilter()/setFilterProperty() use,
    // and defaults to the type. Omitted arguments fall back to that filter's
    // defaults, so addFilter('hud', 'blur', 'soft', 8) is addBlurFilter('hud',
    // 'soft', 8). `target` is a camera ('game', 'hud', 'notes', 'other'), a
    // camera made with createCamera(), or 'global' for the whole window
    // (FlxG.game, on top of every camera). Sprites are not filter targets.
    register("addFilter", function(target:String, type:String, ?name:String, ?a:Dynamic, ?b:Dynamic, ?c:Dynamic, ?d:Dynamic, ?e:Dynamic) {
      final filter:BitmapFilter = buildFilter(type, a, b, c, d, e);
      if (filter == null) {
        trace('addFilter | unknown filter type "$type" (blur, glow, shadow, colormatrix, convolution, displacement)', FlxColor.RED);
        return false;
      }
      return attachFilter(trace, target, name == null ? type : name, filter);
    });

    // Gaussian blur. `quality` 1 is the cheap one, 2-3 cost more.
    register("addBlurFilter", function(target:String, ?name:String, blurX:Float = 4, blurY:Float = 4, quality:Int = 1) {
      return attachFilter(trace, target, name == null ? 'blur' : name, ScreenFilters.blur(blurX, blurY, quality));
    });

    // Glow around the opaque parts of the camera. `color` takes a
    // number (0xFF0000) or a name ('red', '#FF0000'); `inner` glows inside the
    // edges and `knockout` keeps only the glow.
    register("addGlowFilter", function(target:String, ?name:String, ?color:Dynamic, alpha:Float = 1, blurX:Float = 6, blurY:Float = 6, strength:Float = 2, quality:Int = 1, inner:Bool = false, knockout:Bool = false) {
      return attachFilter(trace, target, name == null ? 'glow' : name, ScreenFilters.glow(color, alpha, blurX, blurY, strength, quality, inner, knockout));
    });

    // Offset shadow. `angle` is in degrees, `distance` in pixels.
    register("addDropShadowFilter", function(target:String, ?name:String, distance:Float = 4, angle:Float = 45, ?color:Dynamic, alpha:Float = 1, blurX:Float = 4, blurY:Float = 4, strength:Float = 1, quality:Int = 1, inner:Bool = false, knockout:Bool = false, hideObject:Bool = false) {
      return attachFilter(trace, target, name == null ? 'shadow' : name, ScreenFilters.shadow(distance, angle, color, alpha, blurX, blurY, strength, quality, inner, knockout, hideObject));
    });

    // 4x5 colour matrix. Pass the 20 numbers, or one of the presets:
    // 'invert', 'greyscale', 'sepia', 'sepiacold', 'gameboy', 'nightvision',
    // 'protanopia', 'deuteranopia', 'tritanopia', 'identity'.
    register("addColorMatrixFilter", function(target:String, ?name:String, ?matrix:Dynamic) {
      return attachFilter(trace, target, name == null ? 'colormatrix' : name, ScreenFilters.colorMatrix(matrix));
    });

    // A preset game look without spelling a matrix: the same preset names as
    // addColorMatrixFilter, e.g. addColorFilter('global', 'gamefilter', 'gameboy').
    register("addColorFilter", function(target:String, ?name:String, preset:String = 'invert') {
      final matrix:Array<Float> = ScreenFilters.matrixByName(preset);
      if (matrix == null) {
        trace('addColorFilter | unknown preset "$preset"', FlxColor.RED);
        return false;
      }
      return attachFilter(trace, target, name == null ? preset : name, ScreenFilters.colorMatrix(matrix));
    });

    // NxM convolution kernel: sharpen, emboss, edge detect. `matrix` is the flat
    // kernel and `divisor` normally equals the sum of its values.
    register("addConvolutionFilter", function(target:String, ?name:String, matrix:Array<Dynamic>, matrixX:Int = 3, matrixY:Int = 3, divisor:Float = 1.0, bias:Float = 0.0, preserveAlpha:Bool = true, clamp:Bool = true) {
      final kernel:Array<Float> = [];
      if (matrix != null)
        for (value in matrix) kernel.push(Std.parseFloat(Std.string(value)));
      return attachFilter(trace, target, name == null ? 'convolution' : name, ScreenFilters.convolution(matrixX, matrixY, kernel, divisor, bias, preserveAlpha, clamp));
    });

    // Warps the picture using a map image from images/ (a greyscale PNG the
    // size of the screen). `mode` is 'wrap' (default), 'clamp', 'ignore' or
    // 'color'; scaleX/scaleY are the displacement in pixels.
    register("addDisplacementMapFilter", function(target:String, ?name:String, mapImage:String, componentX:Int = 1, componentY:Int = 2, scaleX:Float = 10, scaleY:Float = 10, mode:String = 'wrap') {
      final filter:BitmapFilter = ScreenFilters.displacement(mapImage, componentX, componentY, scaleX, scaleY, mode);
      if (filter == null) {
        trace('addDisplacementMapFilter | could not load image "$mapImage"', FlxColor.RED);
        return false;
      }
      return attachFilter(trace, target, name == null ? 'displacement' : name, filter);
    });

    // Removes one filter added through this API.
    register("removeFilter", function(target:String, name:String) {
      return ScreenFilters.remove(target, name);
    });

    // Removes every filter this API added to `target`; filters the engine or a
    // mod attached by hand (a stage rain shader) are left alone.
    register("clearFilters", function(target:String) {
      ScreenFilters.clear(target);
    });

    // Every filter name currently on `target`, in draw order.
    register("getFilters", function(target:String) {
      return ScreenFilters.names(target);
    });

    // Whether `name` is attached to `target`.
    register("hasFilter", function(target:String, name:String) {
      return ScreenFilters.exists(target, name);
    });

    // Restyles one filter in place without removing and re-adding it.
    // `property` is the OpenFL field: 'blurX', 'blurY', 'quality', 'strength',
    // 'color', 'alpha', 'distance', 'angle', 'matrix', ...
    register("setFilterProperty", function(target:String, name:String, property:String, value:Dynamic) {
      final filter:BitmapFilter = ScreenFilters.get(target, name);
      if (filter == null) {
        trace('setFilterProperty | no filter "$name" on "$target"', FlxColor.YELLOW);
        return false;
      }
      try {
        // Colours go through FlxColor so 'red' and 0xFF0000 keep working like
        // they do in the add* calls; everything else is written as-is.
        final field:String = property == null ? '' : property.toLowerCase();
        if (field == 'color' || field == 'colour')
          Reflect.setProperty(filter, 'color', ScreenFilters.toColor(value));
        else
          Reflect.setProperty(filter, property, value);
        return true;
      } catch (e:Dynamic) {
        trace('setFilterProperty | ' + Std.string(e), FlxColor.RED);
        return false;
      }
    });

    // Reads a filter field back, e.g. getFilterProperty('hud', 'blur', 'blurX').
    register("getFilterProperty", function(target:String, name:String, property:String) {
      final filter:BitmapFilter = ScreenFilters.get(target, name);
      return filter == null ? null : Reflect.getProperty(filter, property);
    });

    // Lists the colour-matrix presets addColorFilter() accepts.
    register("getFilterPresets", function() {
      return ScreenFilters.PRESETS.copy();
    });

    // Whole-window filters sit on FlxG.game instead of one camera: every camera
    // is filtered, which is what the old 'game filter' mods do. Called with no
    // type it clears them.
    register("setGameFilters", function(?type:String, ?name:String, ?a:Dynamic, ?b:Dynamic, ?c:Dynamic, ?d:Dynamic, ?e:Dynamic) {
      if (type == null || type.length == 0) {
        ScreenFilters.clear('global');
        return true;
      }
      final filter:BitmapFilter = buildFilter(type, a, b, c, d, e);
      if (filter == null) {
        trace('setGameFilters | unknown filter type "$type"', FlxColor.RED);
        return false;
      }
      return attachFilter(trace, 'global', name == null ? type : name, filter);
    });

    // ---------------------------------------------------------------- //
    //                      CHAINABLE EFFECTS                           //
    // ---------------------------------------------------------------- //

    // Adds one flixel-addons chainable effect to a sprite, wrapping the sprite
    // in an FlxEffectSprite on first use. `type` is 'shake', 'wave', 'glitch',
    // 'rainbow', 'outline' or 'trail'; a, b, c and d map to that effect's
    // arguments (see docs/SHADERS.md for the table).
    register("addChainableEffect", function(tag:String, type:String, ?a:Dynamic, ?b:Dynamic, ?c:Dynamic, ?d:Dynamic) {
      final effect = ChainableEffects.build(tag, type, a, b, c, d);
      if (effect == null) {
        trace('addChainableEffect | unknown effect "$type" (' + ChainableEffects.TYPES.join(', ') + ')', FlxColor.RED);
        return false;
      }
      return ChainableEffects.push(tag, effect);
    });

    // Shorthand: a decaying pixel shake for `duration` seconds. `axes` is 'x',
    // 'y' or 'xy' (default both).
    register("addSpriteShakeEffect", function(tag:String, intensity:Float = 5, duration:Float = 0.5, ?axes:String) {
      return ChainableEffects.push(tag, ChainableEffects.shake(intensity, duration, ChainableEffects.axesFromString(axes)));
    });

    // Shorthand: sine wave distortion. `mode` is 'all' (default), 'start' or
    // 'end'; `direction` is 'horizontal' (default) or 'vertical'.
    register("addSpriteWaveEffect", function(tag:String, strength:Int = 10, wavelength:Int = 5, speed:Float = 3, center:Float = 0.5, mode:String = 'all', direction:String = 'horizontal') {
      return ChainableEffects.push(tag, ChainableEffects.wave(strength, wavelength, speed, center, mode, direction));
    });

    // Shorthand: slice-displacement glitch. `delay` is the seconds between
    // reshuffles.
    register("addSpriteGlitchEffect", function(tag:String, strength:Int = 4, size:Int = 1, delay:Float = 0.05, direction:String = 'horizontal') {
      return ChainableEffects.push(tag, ChainableEffects.glitch(strength, size, delay, direction));
    });

    // Shorthand: hue cycling behind the sprite's silhouette.
    register("addRainbowEffect", function(tag:String, alpha:Float = 1, brightness:Float = 1, speed:Float = 5, startHue:Int = 0) {
      return ChainableEffects.push(tag, ChainableEffects.rainbow(alpha, brightness, speed, startHue));
    });

    // Shorthand: solid outline. `mode` is 'fast' (default), 'normal' or
    // 'pixel'; `quality` 0 uses one draw pass, 1 one pass per pixel of
    // thickness (heavy, best quality).
    register("addSpriteOutlineEffect", function(tag:String, ?color:Dynamic, thickness:Int = 1, mode:String = 'fast', ?quality:Float) {
      return ChainableEffects.push(tag, ChainableEffects.outline(color == null ? 0xFFFFFF : color, thickness, mode, 0, quality == null ? 1 : quality));
    });

    // Shorthand: position trail. `framesDelay` is how many frames pass between
    // samples and `cachePixels` whether each sample keeps its own pixels
    // (disable it for a sprite whose graphic never changes).
    register("addSpriteTrailEffect", function(tag:String, length:Int = 10, alpha:Float = 0.5, framesDelay:Int = 2, cachePixels:Bool = true) {
      return ChainableEffects.push(tag, ChainableEffects.trail(tag, length, alpha, framesDelay, cachePixels));
    });

    // Removes the effect at `index` (0-based), or the last one when omitted.
    register("removeChainableEffect", function(tag:String, ?index:Int = -1) {
      return ChainableEffects.pop(tag, index);
    });

    // The class names of the effects currently chained on `tag`, in draw order.
    register("getChainableEffects", function(tag:String) {
      final names:Array<String> = [];
      for (effect in ChainableEffects.effects(tag)) names.push(Type.getClassName(Type.getClass(effect)));
      return names;
    });

    // Drops every effect from `tag` and puts the original sprite back where the
    // wrapper was.
    register("removeChainableEffects", function(tag:String) {
      return ChainableEffects.detach(tag);
    });

    // Freezes (false) or resumes (true) the chain without removing it.
    register("setChainableEffectsEnabled", function(tag:String, enabled:Bool = true) {
      return ChainableEffects.setEnabled(tag, enabled);
    });

    // Whether `tag` is currently drawn through an effect sprite.
    register("hasChainableEffects", function(tag:String) {
      return ChainableEffects.isAttached(tag);
    });

    // The effect type names addChainableEffect() accepts.
    register("getChainableEffectTypes", function() {
      return ChainableEffects.TYPES.copy();
    });
  }

  /**
   * Shared attach with the message a script author needs when a target does not
   * resolve (a typo in a camera or a sprite tag passed as a target, which
   * filters do not accept).
   */
  static function attachFilter(trace:(String, FlxColor)->Void, target:String, name:String, filter:BitmapFilter):Bool
  {
    if (filter == null) return false;
    if (ScreenFilters.add(target, name, filter)) return true;
    trace('addFilter | ' + ScreenFilters.targetError(target), FlxColor.RED);
    return false;
  }

  /**
   * Builds a filter from the type string `addFilter` takes. Argument meaning
   * follows the dedicated add* function of that type, so
   * `addFilter('hud', 'blur', 'soft', 8, 8, 2)` and
   * `addBlurFilter('hud', 'soft', 8, 8, 2)` are the same call.
   */
  static function buildFilter(type:String, ?a:Dynamic, ?b:Dynamic, ?c:Dynamic, ?d:Dynamic, ?e:Dynamic):BitmapFilter
  {
    final name:String = type == null ? '' : type.toLowerCase().trim();
    return switch (name)
    {
      case 'blur': ScreenFilters.blur(num(a, 4), num(b, 4), int(c, 1));
      case 'glow': ScreenFilters.glow(a, num(b, 1), num(c, 6), num(d, 6), num(e, 2));
      case 'shadow' | 'dropshadow' | 'drop_shadow': ScreenFilters.shadow(num(a, 4), num(b, 45), c, num(d, 1), num(e, 4));
      case 'colormatrix' | 'matrix' | 'color': ScreenFilters.colorMatrix(a);
      case 'convolution': ScreenFilters.convolution(int(a, 3), int(b, 3), kernelFrom(c), num(d, 1));
      case 'displacement' | 'displacementmap': ScreenFilters.displacement(a == null ? null : Std.string(a), int(b, 1), int(c, 2), num(d, 10), num(e, 10));
      case _: null;
    };
  }

  static function kernelFrom(value:Dynamic):Array<Float>
  {
    final kernel:Array<Float> = [];
    if (Std.isOfType(value, Array))
      for (entry in (cast value : Array<Dynamic>)) kernel.push(num(entry, 1));
    return kernel;
  }

  static function num(value:Dynamic, fallback:Float):Float
  {
    if (value == null) return fallback;
    if (Std.isOfType(value, Int) || Std.isOfType(value, Float)) return cast(value, Float);
    final parsed:Null<Float> = Std.parseFloat(Std.string(value));
    return parsed == null || Math.isNaN(parsed) ? fallback : parsed;
  }

  static function int(value:Dynamic, fallback:Int):Int
    return Std.int(num(value, fallback));
}
