package backend;

import flixel.FlxSprite;
import flixel.addons.effects.chainable.FlxEffectSprite;
import flixel.addons.effects.chainable.FlxGlitchEffect;
import flixel.addons.effects.chainable.FlxGlitchEffect.FlxGlitchDirection;
import flixel.addons.effects.chainable.FlxOutlineEffect;
import flixel.addons.effects.chainable.FlxOutlineEffect.FlxOutlineMode;
import flixel.addons.effects.chainable.FlxRainbowEffect;
import flixel.addons.effects.chainable.FlxShakeEffect;
import flixel.addons.effects.chainable.FlxTrailEffect;
import flixel.addons.effects.chainable.FlxWaveEffect;
import flixel.addons.effects.chainable.FlxWaveEffect.FlxWaveDirection;
import flixel.addons.effects.chainable.FlxWaveEffect.FlxWaveMode;
import flixel.addons.effects.chainable.IFlxEffect;
import flixel.util.FlxAxes;
import play.PlayState;

/**
 * Script wrapper for `flixel.addons.effects.chainable`.
 *
 * A chainable effect is not a camera filter: it rewrites a sprite's pixels every
 * frame (`FlxEffectSprite` draws a copy of its target through a list of
 * `IFlxEffect`s), which is how shake, wave, glitch, rainbow, outline and trail
 * work on characters. The addon expects to own that pairing, so this class keeps
 * one `FlxEffectSprite` per scripted sprite and exposes the pieces scripts want:
 *
 * - `attach()` / `detach()` swap a sprite in and out of its effect sprite;
 * - one factory per effect, plus `apply()` which takes a type string so a Lua
 *   script can build a chain from a table without importing Haxe classes;
 * - a shared registry so the effects can be found again by sprite tag.
 *
 * Because `FlxEffectSprite` replaces the drawn sprite, chainable effects and
 * filters on the same sprite are independent: a filter lives on the sprite's
 * `filters` array and the effect sprite adds its own pixels on top.
 */
class ChainableEffects
{
  /** One scripted sprite and the effect sprite standing in for it. */
  public static var attached:Map<String, ChainableEntry> = new Map<String, ChainableEntry>();

  /** Effect type names `apply()` understands, for docs and error messages. */
  public static final TYPES:Array<String> = ['shake', 'wave', 'glitch', 'rainbow', 'outline', 'trail'];

  /**
   * Starts drawing `sprite` through an effect sprite.
   *
   * @param tag    Script name for the sprite.
   * @param sprite The sprite to wrap.
   * @param front  Where the effect sprite goes in the state if the original was
   *               already added: `true` puts it on top of everything.
   * @param effects Initial effect chain (see `apply()`).
   * @return The entry, or `null` when the sprite cannot be resolved.
   */
  public static function attach(tag:String, sprite:FlxSprite, front:Bool = false, ?effects:Array<IFlxEffect>):ChainableEntry
  {
    if (sprite == null) return null;
    if (tag == null || tag.length == 0) tag = Std.string(sprite);

    // Re-attaching keeps the chain: only the wrapper is rebuilt.
    final existing:ChainableEntry = attached.get(tag);
    if (existing != null && existing.effectSprite.target == sprite) return existing;

    detach(tag);

    final game:PlayState = PlayState.instance;
    final effectSprite:FlxEffectSprite = new FlxEffectSprite(sprite, effects == null ? [] : effects);
    effectSprite.cameras = sprite.cameras;
    effectSprite.antialiasing = sprite.antialiasing;
    effectSprite.scrollFactor.copyFrom(sprite.scrollFactor);
    effectSprite.updateTargetAnimation = false;

    // The original was on screen: put the wrapper in its place so the sprite
    // does not jump behind or in front of the stage.
    final index:Int = game == null ? -1 : game.members.indexOf(sprite);
    if (index >= 0)
    {
      game.remove(sprite, false);
      if (front) game.add(effectSprite);
      else game.insert(index, effectSprite);
    }

    final entry:ChainableEntry = {tag: tag, effectSprite: effectSprite, sprite: sprite};
    attached.set(tag, entry);
    return entry;
  }

  /** Stops drawing `tag` through its effect sprite and destroys the wrapper. */
  public static function detach(tag:String):Bool
  {
    final entry:ChainableEntry = attached.get(tag);
    if (entry == null) return false;

    final game:PlayState = PlayState.instance;
    final effectSprite:FlxEffectSprite = entry.effectSprite;
    if (game != null && effectSprite != null)
    {
      final index:Int = game.members.indexOf(effectSprite);
      if (index >= 0)
      {
        game.remove(effectSprite, false);
        // Put the original sprite back where the wrapper was, untouched.
        if (entry.sprite != null && !game.members.contains(entry.sprite)) game.insert(index, entry.sprite);
      }
    }

    entry.effectSprite = null;
    attached.remove(tag);
    return true;
  }

  /** The entry for `tag`, creating one when `create` is set. */
  public static function entry(tag:String, create:Bool = true):ChainableEntry
  {
    if (tag == null) return null;
    final found:ChainableEntry = attached.get(tag);
    if (found != null || !create) return found;

    final sprite:FlxSprite = ScreenFilters.spriteFromString(tag);
    if (sprite == null) return null;
    return attach(tag, sprite);
  }

  /** Every effect currently chained on `tag`. */
  public static function effects(tag:String):Array<IFlxEffect>
  {
    final found:ChainableEntry = attached.get(tag);
    return found == null || found.effectSprite == null ? [] : found.effectSprite.effects;
  }

  /** Adds an already built effect to `tag`'s chain, wrapping the sprite if needed. */
  public static function push(tag:String, effect:IFlxEffect):Bool
  {
    if (effect == null) return false;
    final found:ChainableEntry = entry(tag);
    if (found == null) return false;
    found.effectSprite.effects.push(effect);
    return true;
  }

  /**
   * Removes one effect from `tag`'s chain.
   *
   * @param tag    Script name of the sprite.
   * @param index  0-based position; `-1` (default) removes the last effect.
   * @return `true` when something was removed.
   */
  public static function pop(tag:String, index:Int = -1):Bool
  {
    final found:ChainableEntry = attached.get(tag);
    if (found == null || found.effectSprite == null) return false;
    final list:Array<IFlxEffect> = found.effectSprite.effects;
    if (list.length == 0) return false;
    if (index < 0 || index >= list.length) index = list.length - 1;
    list.splice(index, 1);
    return true;
  }

  /** Removes every effect from `tag`, keeping the wrapper (cheap to reuse). */
  public static function clear(tag:String):Bool
  {
    final found:ChainableEntry = attached.get(tag);
    if (found == null || found.effectSprite == null) return false;
    found.effectSprite.effects = [];
    return true;
  }

  /** Freezes (`false`) or resumes (`true`) the effect chain and its updates. */
  public static function setEnabled(tag:String, enabled:Bool):Bool
  {
    final found:ChainableEntry = attached.get(tag);
    if (found == null || found.effectSprite == null) return false;
    found.effectSprite.effectsEnabled = enabled;
    return true;
  }

  /** Whether `tag` is currently drawn through an effect sprite. */
  public static function isAttached(tag:String):Bool
    return attached.exists(tag);

  /** Drops every entry; called when a `PlayState` is torn down. */
  public static function reset():Void
  {
    final tags:Array<String> = [];
    for (tag in attached.keys()) tags.push(tag);
    for (tag in tags) detach(tag);
    attached = new Map<String, ChainableEntry>();
  }

  // ------------------------------------------------------------------ //
  //                             FACTORIES                              //
  // ------------------------------------------------------------------ //

  /** Random pixel jitter that decays over `duration` seconds. */
  public static function shake(intensity:Float = 5, duration:Float = 0.5, ?axes:FlxAxes):IFlxEffect
  {
    final effect:FlxShakeEffect = new FlxShakeEffect(intensity, duration, null, axes);
    effect.reset(intensity, duration, null, axes);
    return effect;
  }

  /** Sine wave distortion; `direction` is `'horizontal'`/`'vertical'`. */
  public static function wave(strength:Int = 10, wavelength:Int = 5, speed:Float = 3, center:Float = 0.5,
      mode:String = 'all', direction:String = 'horizontal'):IFlxEffect
    return new FlxWaveEffect(waveMode(mode), strength, center, speed, wavelength, waveDirection(direction));

  /** Slice displacement; `direction` is `'horizontal'`/`'vertical'`. */
  public static function glitch(strength:Int = 4, size:Int = 1, delay:Float = 0.05, direction:String = 'horizontal'):IFlxEffect
    return new FlxGlitchEffect(strength, size, delay, glitchDirection(direction));

  /** Colour cycling using the sprite as a mask. */
  public static function rainbow(alpha:Float = 1, brightness:Float = 1, speed:Float = 5, startHue:Int = 0):IFlxEffect
    return new FlxRainbowEffect(alpha, brightness, speed, startHue);

  /** Solid outline around the sprite's silhouette. */
  public static function outline(color:Dynamic = 0xFFFFFF, thickness:Int = 1, mode:String = 'fast', threshold:Int = 0, quality:Float = 1):IFlxEffect
  {
    final effect:FlxOutlineEffect = new FlxOutlineEffect(outlineMode(mode), ScreenFilters.toColor(color), thickness, threshold, quality);
    effect.dirty = true;
    return effect;
  }

  /**
   * Position trail. The addon's trail needs the effect sprite, so `tag` is
   * required and the trail is only useful once the sprite is attached.
   */
  public static function trail(tag:String, length:Int = 10, alpha:Float = 0.5, framesDelay:Int = 2, cachePixels:Bool = true):IFlxEffect
  {
    final found:ChainableEntry = entry(tag);
    if (found == null) return null;
    return new FlxTrailEffect(found.effectSprite, length, alpha, framesDelay, cachePixels);
  }

  /**
   * Builds one effect from a type name, so a script can spell a chain without
   * importing Haxe classes:
   *
   * ```lua
   * for _, e in ipairs({{'rainbow'}, {'wave', 8, 4, 3}, {'outline', 'black', 2}}) do
   *     addChainableEffect('boyfriend', e[1], e[2], e[3], e[4])
   * end
   * ```
   *
   * @param tag  Sprite tag the effect is for (the trail needs it).
   * @param type One of `TYPES`.
   * @param a    First numeric/colour argument for the effect.
   * @param b    Second argument.
   * @param c    Third argument.
   * @param d    Fourth argument.
   */
  public static function build(tag:String, type:String, a:Dynamic = null, b:Dynamic = null, c:Dynamic = null, d:Dynamic = null):IFlxEffect
  {
    final name:String = type == null ? '' : type.toLowerCase().trim();
    return switch (name)
    {
      case 'shake': shake(num(a, 5), num(b, 0.5), axesFromString(d));
      case 'wave': wave(int(a, 10), int(b, 5), num(c, 3), num(d, 0.5));
      case 'glitch': glitch(int(a, 4), int(b, 1), num(c, 0.05), d == null ? 'horizontal' : Std.string(d));
      case 'rainbow': rainbow(num(a, 1), num(b, 1), num(c, 5), int(d, 0));
      case 'outline': outline(a == null ? 0xFFFFFF : a, int(b, 1), c == null ? 'fast' : Std.string(c), int(d, 0));
      case 'trail': trail(tag, int(a, 10), num(b, 0.5), int(c, 2));
      case _: null;
    };
  }

  // ------------------------------------------------------------------ //
  //                          NAME CONVERSION                           //
  // ------------------------------------------------------------------ //

  public static function waveMode(mode:String):FlxWaveMode
  {
    return switch (mode == null ? '' : mode.toLowerCase().trim())
    {
      case 'start': FlxWaveMode.START;
      case 'end': FlxWaveMode.END;
      case _: FlxWaveMode.ALL;
    };
  }

  public static function waveDirection(direction:String):FlxWaveDirection
  {
    return switch (direction == null ? '' : direction.toLowerCase().trim())
    {
      case 'vertical' | 'y': FlxWaveDirection.VERTICAL;
      case _: FlxWaveDirection.HORIZONTAL;
    };
  }

  public static function glitchDirection(direction:String):FlxGlitchDirection
  {
    return switch (direction == null ? '' : direction.toLowerCase().trim())
    {
      case 'vertical' | 'y': FlxGlitchDirection.VERTICAL;
      case _: FlxGlitchDirection.HORIZONTAL;
    };
  }

  public static function outlineMode(mode:String):FlxOutlineMode
  {
    return switch (mode == null ? '' : mode.toLowerCase().trim())
    {
      case 'normal': FlxOutlineMode.NORMAL;
      case 'pixelbypixel' | 'pixel_by_pixel' | 'pixel': FlxOutlineMode.PIXEL_BY_PIXEL;
      case _: FlxOutlineMode.FAST;
    };
  }

  /** `'x'`, `'y'`, `'xy'` or `null` (both axes) as a `FlxAxes`. */
  public static function axesFromString(axes:Dynamic):FlxAxes
  {
    if (axes == null) return FlxAxes.XY;
    final text:String = Std.string(axes).toLowerCase().trim();
    return switch (text)
    {
      case 'x' | 'horizontal': FlxAxes.X;
      case 'y' | 'vertical': FlxAxes.Y;
      case 'none': FlxAxes.NONE;
      case _: FlxAxes.XY;
    };
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

/** A scripted sprite drawn through `FlxEffectSprite`. */
typedef ChainableEntry = {
  /** Script-facing sprite name. */
  var tag:String;
  /** The wrapper that draws the chain; `null` once detached. */
  var effectSprite:FlxEffectSprite;
  /** The original sprite, kept so `detach()` can restore it. */
  var sprite:FlxSprite;
}
