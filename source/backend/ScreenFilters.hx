package backend;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.util.FlxColor;
import openfl.display.BitmapData;
import openfl.filters.BitmapFilter;
import openfl.filters.BlurFilter;
import openfl.filters.ColorMatrixFilter;
import openfl.filters.ConvolutionFilter;
import openfl.filters.DisplacementMapFilter;
import openfl.filters.DisplacementMapFilterMode;
import openfl.filters.DropShadowFilter;
import openfl.filters.GlowFilter;
import play.PlayState;

/**
 * The non-shader half of the script filter API.
 *
 * `FlxG.camera.filters` and `FlxG.game.filters` (the FlxGame level, patched in
 * `source/source-haxelib-patches/flixel/FlxGame.hx`) take plain OpenFL
 * `BitmapFilter`s: blur, glow, drop shadow, colour matrix, convolution and
 * displacement map. Shaders cover the rest through `shaders/*Effect`, so this
 * class only deals with the six built-ins plus the bookkeeping that makes them
 * scriptable:
 *
 * - a named registry per target, so a script can remove or restyle one filter
 *   later without holding a reference to the OpenFL object (`FlxCamera.filters`
 *   is a plain array; a Lua/Python callback cannot keep one alive safely);
 * - targets addressed by name: `'game'` / `'camGame'` / `'hud'` / `'camNotes'` /
 *   `'camOther'`, a camera made with `createCamera()`, or `'global'` for
 *   `FlxG.game` (the whole window, on top of every camera);
 * - preset colour matrices (invert, greyscale, sepia, gameboy, ...) so the
 *   common "game filter" looks are one call instead of twenty numbers.
 *
 * A `FlxSprite` is deliberately not a filter target: Flixel only filters
 * cameras and the game object (a real `DisplayObject`), while per-sprite looks
 * go through a sprite's `shader` field (`setSpriteShader`) or the pixel-based
 * `flixel.addons.effects.chainable` effects in `backend.ChainableEffects`.
 *
 * Everything here is renderer-agnostic and shared by
 * `psychlua.callbacks.FilterCallbacks` (Lua), `psychlua.pystdlib.PyFilterLib`
 * (Python) and the HScript scope, so all three languages get the same names,
 * the same defaults and the same presets.
 */
class ScreenFilters
{
  /** One filter plus the script-facing name it was added under. */
  public static var registry:Array<FilterEntry> = [];

  /** Named colour matrices, built on demand by `preset()`. */
  public static final PRESETS:Array<String> = [
    'invert', 'greyscale', 'grayscale', 'sepia', 'sepiacold', 'gameboy', 'nightvision',
    'protanopia', 'deuteranopia', 'tritanopia', 'identity'
  ];

  /**
   * Adds `filter` to `target` under `name`.
   *
   * @param target Script target string (`'game'`, `'hud'`, `'global'`, a camera name).
   * @param name   Script name for the filter, used by `remove()`/`update()`.
   * @param filter The OpenFL filter.
   * @param replace Whether an existing filter with the same name is dropped first.
   * @return `true` when the filter was attached.
   */
  public static function add(target:String, name:String, filter:BitmapFilter, replace:Bool = true):Bool
  {
    if (filter == null) return false;
    if (name == null || name.length == 0) name = 'filter' + (registry.length + 1);
    if (replace) remove(target, name, false);

    final attached:Bool = attach(target, filter);
    if (!attached) return false;

    registry.push({name: name, target: normalizeTarget(target), filter: filter});
    return true;
  }

  /**
   * Removes a filter by name.
   *
   * @param target Target it was added to; `null` matches any target.
   * @param name   Script name given to `add()`.
   * @param destroy Whether the filter should also be disposed (bitmap-backed
   *                filters such as the displacement map hold a `BitmapData`).
   * @return `true` when an entry was found and detached.
   */
  public static function remove(target:String, name:String, destroy:Bool = true):Bool
  {
    if (name == null) return false;
    final wanted:String = target == null ? null : normalizeTarget(target);
    var i:Int = registry.length - 1;
    while (i >= 0)
    {
      final entry:FilterEntry = registry[i];
      if (entry.name == name && (wanted == null || entry.target == wanted))
      {
        detach(entry.target, entry.filter);
        registry.splice(i, 1);
        if (destroy) dispose(entry.filter);
        return true;
      }
      i--;
    }
    return false;
  }

  /** Replaces the filter stored under `name` with `filter`, keeping its position. */
  public static function update(target:String, name:String, filter:BitmapFilter):Bool
  {
    if (filter == null || name == null) return false;
    final wanted:String = normalizeTarget(target);
    for (entry in registry)
    {
      if (entry.name != name || entry.target != wanted) continue;
      detach(entry.target, entry.filter);
      if (!attach(entry.target, filter)) return false;
      dispose(entry.filter);
      entry.filter = filter;
      return true;
    }
    return false;
  }

  /** Every filter name currently attached to `target`, in draw order. */
  public static function names(target:String):Array<String>
  {
    final wanted:String = normalizeTarget(target);
    final list:Array<String> = [];
    for (entry in registry) if (entry.target == wanted) list.push(entry.name);
    return list;
  }

  /** The OpenFL filter stored under `name`, or `null`. */
  public static function get(target:String, name:String):BitmapFilter
  {
    final wanted:String = normalizeTarget(target);
    for (entry in registry) if (entry.name == name && entry.target == wanted) return entry.filter;
    return null;
  }

  /** Whether `name` is attached to `target`. */
  public static function exists(target:String, name:String):Bool
    return get(target, name) != null;

  /**
   * Drops every filter this class attached to `target` and leaves filters the
   * engine or a mod added by hand (a stage's rain shader, for example) alone.
   * `target == null` clears every script filter.
   */
  public static function clear(?target:String):Void
  {
    final wanted:String = target == null ? null : normalizeTarget(target);
    var i:Int = registry.length - 1;
    while (i >= 0)
    {
      final entry:FilterEntry = registry[i];
      if (wanted == null || entry.target == wanted)
      {
        detach(entry.target, entry.filter);
        dispose(entry.filter);
        registry.splice(i, 1);
      }
      i--;
    }
  }

  /**
   * Called when a PlayState dies so the next song starts from a clean slate.
   *
   * Every filter is detached, not just forgotten: a camera is destroyed with
   * the state anyway, but `FlxG.game` (the `'global'` target) survives it, so
   * a leftover window filter would tint the menus and the next song.
   */
  public static function reset():Void
  {
    for (entry in registry) detach(entry.target, entry.filter);
    registry = [];
  }

  // ------------------------------------------------------------------ //
  //                          TARGET PLUMBING                           //
  // ------------------------------------------------------------------ //

  /**
   * Resolves a script target string to the object whose `filters` array is
   * written: a camera, or `FlxG.game` for `'global'`.
   *
   * Sprites have no `filters` in Flixel — per-sprite looks are shaders, or the
   * chainable effects in `ChainableEffects` — so a sprite tag resolves to
   * `null` here and the caller reports the bad target.
   */
  public static function resolveTarget(target:String):Dynamic
  {
    if (target == null) return null;
    final key:String = normalizeTarget(target);

    // Whole-window filter: FlxGame is a DisplayObject and takes `filters` too.
    if (key == 'global' || key == 'window' || key == 'gameobject') return FlxG.game;

    return cameraFromString(key);
  }

  /** Lower-cased, trimmed target key used for the registry. */
  public static function normalizeTarget(target:String):String
    return target == null ? '' : target.toLowerCase().trim();

  /** The message `add()` callers trace when a target cannot be resolved. */
  public static function targetError(target:String):String
    return 'could not resolve target "$target" (expected global, game, hud, notes, other or a camera name; sprites take shaders and chainable effects instead)';

  static function attach(target:String, filter:BitmapFilter):Bool
  {
    final object:Dynamic = resolveTarget(target);
    if (object == null) return false;

    // A camera owns its array, exactly like `FlxCamera.addShader()` assumes.
    if (Std.isOfType(object, FlxCamera))
    {
      final camera:FlxCamera = cast object;
      if (camera.filters == null) camera.filters = [];
      camera.filters.push(filter);
      return true;
    }

    // `FlxG.game`: a DisplayObject clones what it is given, so the list is
    // rebuilt per call. That is fine here because the FlxGame patch keeps the
    // array it was handed and writes it straight through to the renderer.
    final existing:Array<BitmapFilter> = Reflect.getProperty(object, 'filters');
    final list:Array<BitmapFilter> = existing == null ? [] : existing.copy();
    list.push(filter);
    Reflect.setProperty(object, 'filters', list);
    return true;
  }

  static function detach(target:String, filter:BitmapFilter):Void
  {
    if (filter == null) return;
    final object:Dynamic = resolveTarget(target);
    if (object == null) return;

    if (Std.isOfType(object, FlxCamera))
    {
      final camera:FlxCamera = cast object;
      if (camera.filters != null) camera.filters.remove(filter);
      return;
    }

    final existing:Array<BitmapFilter> = Reflect.getProperty(object, 'filters');
    if (existing == null) return;
    final list:Array<BitmapFilter> = existing.copy();
    if (list.remove(filter))
    {
      Reflect.setProperty(object, 'filters', list);
      return;
    }

    // Not there by identity: a DisplayObject clones every filter it is given,
    // so the instance a script holds is never the one being rendered. Rebuild
    // the list from this class's registry instead, which keeps draw order and
    // drops only the entry being removed.
    final rebuilt:Array<BitmapFilter> = [];
    for (entry in registry)
      if (entry.target == normalizeTarget(target) && entry.filter != filter) rebuilt.push(entry.filter);
    Reflect.setProperty(object, 'filters', rebuilt);
  }

  static function dispose(filter:BitmapFilter):Void
  {
    final displacement:DisplacementMapFilter = Std.downcast(filter, DisplacementMapFilter);
    if (displacement != null && displacement.mapBitmap != null)
    {
      displacement.mapBitmap.dispose();
      displacement.mapBitmap = null;
    }
  }

  /**
   * Cameras by script name. Mirrors `psychlua.LuaUtils.cameraFromString()` but
   * stays here so the backend does not depend on the scripting package; returns
   * `null` for anything that is not a known camera name.
   */
  static function cameraFromString(name:String):FlxCamera
  {
    final game:PlayState = PlayState.instance;
    if (name == null || game == null) return null;

    final custom:Dynamic = game.variables.get(name);
    if (custom != null && Std.isOfType(custom, FlxCamera)) return cast custom;

    return switch (name.toLowerCase().trim())
    {
      case 'camgame' | 'game': game.camGame;
      case 'camhud' | 'hud': game.camHUD;
      case 'camother' | 'other': game.camOther;
      case 'camnotes' | 'notes' | 'camstrum' | 'strum': game.camNotes != null ? game.camNotes : game.camHUD;
      case _: null;
    }
  }

  /**
   * Sprites by tag: `makeLuaSprite`/`makeAnimatedLuaSprite` objects, shared
   * `variables` entries, or a field of the state (`boyfriend`, `dad`, ...), the
   * same lookup `getProperty()`/`setProperty()` use. Used by
   * `ChainableEffects` to resolve the sprite a chainable effect is for; a
   * filter cannot target a sprite (see `resolveTarget`).
   */
  public static function spriteFromString(name:String):flixel.FlxSprite
  {
    final game:PlayState = PlayState.instance;
    if (name == null || game == null) return null;

    final luaObject:Dynamic = game.getLuaObject(name, false);
    if (Std.isOfType(luaObject, flixel.FlxSprite)) return cast luaObject;

    final value:Dynamic = Reflect.getProperty(game, name);
    if (Std.isOfType(value, flixel.FlxSprite)) return cast value;

    return null;
  }

  // ------------------------------------------------------------------ //
  //                              FILTERS                               //
  // ------------------------------------------------------------------ //

  /** Gaussian blur (`openfl.filters.BlurFilter`). */
  public static function blur(blurX:Float = 4, blurY:Float = 4, quality:Int = 1):BitmapFilter
    return new BlurFilter(blurX, blurY, quality);

  /** Outer (or inner) glow (`openfl.filters.GlowFilter`). */
  public static function glow(color:Dynamic = 0xFF0000, alpha:Float = 1, blurX:Float = 6, blurY:Float = 6, strength:Float = 2, quality:Int = 1,
      inner:Bool = false, knockout:Bool = false):BitmapFilter
  {
    final rgba:FlxColor = toColor(color);
    return new GlowFilter(rgba, alpha, blurX, blurY, strength, quality, inner, knockout);
  }

  /** Drop shadow (`openfl.filters.DropShadowFilter`). */
  public static function shadow(distance:Float = 4, angle:Float = 45, color:Dynamic = 0x000000, alpha:Float = 1, blurX:Float = 4, blurY:Float = 4,
      strength:Float = 1, quality:Int = 1, inner:Bool = false, knockout:Bool = false, hideObject:Bool = false):BitmapFilter
  {
    final rgba:FlxColor = toColor(color);
    return new DropShadowFilter(distance, angle, rgba, alpha, blurX, blurY, strength, quality, inner, knockout, hideObject);
  }

  /**
   * 4x5 colour matrix (`openfl.filters.ColorMatrixFilter`). `matrix` takes the
   * 20 numbers directly, a preset name (`'invert'`, `'sepia'`, `'gameboy'`, ...)
   * or `null` for the identity matrix.
   */
  public static function colorMatrix(matrix:Dynamic = null):BitmapFilter
    return new ColorMatrixFilter(toMatrix(matrix));

  /** 3x3 (or NxM) convolution kernel, e.g. sharpen or edge detect. */
  public static function convolution(matrixX:Int = 3, matrixY:Int = 3, matrix:Array<Float> = null, divisor:Float = 1.0, bias:Float = 0.0,
      preserveAlpha:Bool = true, clamp:Bool = true, color:Dynamic = 0, alpha:Float = 0.0):BitmapFilter
    return new ConvolutionFilter(matrixX, matrixY, matrix, divisor, bias, preserveAlpha, clamp, toColor(color), alpha);

  /** Warps the picture using a map image (`openfl.filters.DisplacementMapFilter`). */
  public static function displacement(mapImage:String, componentX:Int = 1, componentY:Int = 2, scaleX:Float = 10, scaleY:Float = 10,
      mode:String = 'wrap', color:Dynamic = 0, alpha:Float = 0.0):BitmapFilter
  {
    final bitmap:BitmapData = loadMapBitmap(mapImage);
    if (bitmap == null) return null;
    return new DisplacementMapFilter(bitmap, new openfl.geom.Point(), componentX, componentY, scaleX, scaleY,
      displacementMode(mode), toColor(color), alpha);
  }

  /** `openfl.filters.DisplacementMapFilterMode` by name; unknown names wrap. */
  public static function displacementMode(mode:String):DisplacementMapFilterMode
  {
    return switch (mode == null ? '' : mode.toLowerCase().trim())
    {
      case 'clamp': DisplacementMapFilterMode.CLAMP;
      case 'color' | 'colour': DisplacementMapFilterMode.COLOR;
      case 'ignore': DisplacementMapFilterMode.IGNORE;
      case _: DisplacementMapFilterMode.WRAP;
    }
  }

  /**
   * Loads the displacement map as its own `BitmapData`. It must be a private
   * copy: the filter disposes it in `dispose()`, and disposing a cached graphic
   * would blank every sprite that shares it.
   */
  static function loadMapBitmap(image:String):BitmapData
  {
    if (image == null || image.length == 0) return new BitmapData(8, 8, true, 0);
    try
    {
      final graphic:flixel.graphics.FlxGraphic = Paths.image(image);
      if (graphic == null || graphic.bitmap == null) return null;
      return graphic.bitmap.clone();
    }
    catch (e:Dynamic) return null;
  }

  // ------------------------------------------------------------------ //
  //                          PRESET MATRICES                           //
  // ------------------------------------------------------------------ //

  /** A 4x5 colour matrix by preset name, or `null` when the name is unknown. */
  public static function matrixByName(name:String):Array<Float>
  {
    if (name == null) return null;
    return switch (name.toLowerCase().trim())
    {
      case 'invert': [ -1.0, 0, 0, 0, 255.0, 0, -1.0, 0, 0, 255.0, 0, 0, -1.0, 0, 255.0, 0, 0, 0, 1, 0 ];
      case 'greyscale' | 'grayscale': [ 0.299, 0.587, 0.114, 0, 0.0, 0.299, 0.587, 0.114, 0, 0.0, 0.299, 0.587, 0.114, 0, 0.0, 0, 0, 0, 1, 0 ];
      case 'sepia': [ 0.393, 0.769, 0.189, 0, 0.0, 0.349, 0.686, 0.168, 0, 0.0, 0.272, 0.534, 0.131, 0, 0.0, 0, 0, 0, 1, 0 ];
      // Four-shade green LCD, the "Game Boy" palette.
      case 'gameboy': [ 0.0, 0.6, 0.0, 0, 20.0, 0.0, 0.8, 0.0, 0, 40.0, 0.0, 0.4, 0.0, 0, 10.0, 0, 0, 0, 1, 0 ];
      // Brighter, greener sepia for night-vision looks.
      case 'nightvision': [ 0.1, 0.4, 0.1, 0, 0.0, 0.3, 1.0, 0.3, 0, 0.0, 0.1, 0.4, 0.1, 0, 0.0, 0, 0, 0, 1, 0 ];
      // Sepia with the blue channel boosted: cold, sickly, "old photo" mood.
      case 'sepiacold': [ 0.393, 0.769, 0.189, 0, 0.0, 0.349, 0.686, 0.168, 0, 0.0, 0.272, 0.534, 0.131, 0, 40.0, 0, 0, 0, 1, 0 ];
      // Machado et al. (2009) dichromacy simulations, the usual colour-blind presets.
      case 'protanopia': [ 0.567, 0.433, 0.0, 0, 0, 0.558, 0.442, 0.0, 0, 0, 0.0, 0.242, 0.758, 0, 0, 0, 0, 0, 1, 0 ];
      case 'deuteranopia': [ 0.625, 0.375, 0.0, 0, 0, 0.7, 0.3, 0.0, 0, 0, 0.0, 0.3, 0.7, 0, 0, 0, 0, 0, 1, 0 ];
      case 'tritanopia': [ 0.95, 0.05, 0.0, 0, 0, 0.0, 0.433, 0.567, 0, 0, 0.0, 0.475, 0.525, 0, 0, 0, 0, 0, 1, 0 ];
      case 'identity': identityMatrix();
      case _: null;
    };
  }

  /** The identity 4x5 colour matrix. */
  public static function identityMatrix():Array<Float>
    return [ 1.0, 0, 0, 0, 0.0, 0, 1.0, 0, 0, 0.0, 0, 0, 1.0, 0, 0.0, 0, 0, 0, 1, 0 ];

  /**
   * Normalizes whatever a script passed as a colour matrix: a preset name, an
   * array of 20 numbers (Lua/Python tables arrive as arrays) or `null`.
   * Anything else falls back to the identity matrix instead of throwing inside
   * a script callback.
   */
  public static function toMatrix(value:Dynamic):Array<Float>
  {
    if (value == null) return identityMatrix();
    if (Std.isOfType(value, String)) return matrixByName(cast value) ?? identityMatrix();
    if (Std.isOfType(value, Array))
    {
      final list:Array<Dynamic> = cast value;
      final matrix:Array<Float> = [];
      for (entry in list) matrix.push(toFloat(entry));
      return matrix.length == 20 ? matrix : identityMatrix();
    }
    return identityMatrix();
  }

  /** Accepts `0xRRGGBB`, `0xAARRGGBB`, an int, or `'#RRGGBB'` / `'red'`. */
  public static function toColor(value:Dynamic):FlxColor
  {
    if (value == null) return 0x000000;
    if (Std.isOfType(value, String)) return CoolUtil.colorFromString(cast value);
    if (Std.isOfType(value, Int) || Std.isOfType(value, Float)) return FlxColor.fromInt(Std.int(cast(value, Float)));
    return 0x000000;
  }

  static function toFloat(value:Dynamic):Float
  {
    if (value == null) return 0;
    if (Std.isOfType(value, Int) || Std.isOfType(value, Float)) return cast(value, Float);
    if (Std.isOfType(value, String))
    {
      final parsed:Null<Float> = Std.parseFloat(cast value);
      return parsed == null || Math.isNaN(parsed) ? 0 : parsed;
    }
    return 0;
  }
}

/** A filter attached through `ScreenFilters.add()`. */
typedef FilterEntry = {
  /** Script-facing name, unique per target. */
  var name:String;
  /** Normalized target key (`'hud'`, `'global'`, a camera name, ...). */
  var target:String;
  /** The OpenFL filter that was attached. */
  var filter:BitmapFilter;
}
