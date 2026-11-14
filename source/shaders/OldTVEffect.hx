package shaders;

/**
 * Broken old television filter: rolling picture-offset bar, optional smear,
 * black/white sploches and analogue static (see `shaders.OldTVShader`).
 *
 * Ported from Mario Madness (`OldTVShader`); credits and the list of local
 * changes are on the shader class.
 *
 * Usage:
 * ```haxe
 * var tv = new shaders.OldTVEffect();
 * game.addShaderToCamera('game', tv);
 * tv.blur = 3.0;          // the smeared upstream look, at a price
 * tv.damage = 0.25;       // barely-broken set
 * ```
 *
 * From Lua/Python/HScript: `addOldTVEffect('game')`. Works outside a song too
 * (title screen, menus) through `shaders.EffectTicker`.
 */
class OldTVEffect extends Effect
{
  public var shader:OldTVShader = new OldTVShader();

  /** Seconds the effect has been running. Writing it re-seeds every animated term. */
  public var time(get, set):Float;

  /** Whether the rolling picture-offset bar travels down the screen. */
  public var bar(default, set):Bool = true;

  /** How far the bar displaces its rows, in UV units (0.01 matches upstream). */
  public var barOffset(default, set):Float = 0.01;

  /** Smear radius in render-target pixels. 0.0 (the default) skips the blur loop; 2.0-4.0 is the upstream look. */
  public var blur(default, set):Float = 0.0;

  /** How much static is mixed over the picture, 0.0 to 1.0 (0.05 matches upstream). */
  public var staticAmount(default, set):Float = 0.05;

  /** Overall damage, 0.0 (static only) to 1.0 (everything upstream does). */
  public var damage(default, set):Float = 1.0;

  /**
   * @param staticAmount How much static is mixed over the picture (0.05 matches upstream).
   * @param damage Overall damage, 0.0 to 1.0.
   * @param blur Smear radius in pixels; 0.0 keeps the cheap path.
   * @param bar Whether the rolling picture-offset bar is drawn.
   * @param barOffset How far the bar displaces its rows, in UV units.
   */
  public function new(staticAmount:Float = 0.05, damage:Float = 1.0, blur:Float = 0.0, bar:Bool = true, barOffset:Float = 0.01)
  {
    this.staticAmount = staticAmount;
    this.damage = damage;
    this.blur = blur;
    this.bar = bar;
    this.barOffset = barOffset;
    EffectTicker.add(update);
  }

  /** Advances `uTime`; called once per frame by `shaders.EffectTicker`. */
  public function update(elapsed:Float):Void
  {
    shader.uTime.value[0] += elapsed;
  }

  function get_time():Float
  {
    return shader.uTime.value[0];
  }

  function set_time(v:Float):Float
  {
    shader.uTime.value[0] = v;
    return v;
  }

  function set_bar(v:Bool):Bool
  {
    bar = v;
    shader.uBar.value[0] = v;
    return v;
  }

  function set_barOffset(v:Float):Float
  {
    barOffset = v;
    shader.uBarOffset.value[0] = Math.max(0.0, v);
    return v;
  }

  function set_blur(v:Float):Float
  {
    blur = v;
    shader.uBlur.value[0] = Math.max(0.0, v);
    return v;
  }

  function set_staticAmount(v:Float):Float
  {
    staticAmount = v;
    shader.uStatic.value[0] = Math.max(0.0, v);
    return v;
  }

  function set_damage(v:Float):Float
  {
    damage = v;
    shader.uDamage.value[0] = Math.max(0.0, v);
    return v;
  }
}
