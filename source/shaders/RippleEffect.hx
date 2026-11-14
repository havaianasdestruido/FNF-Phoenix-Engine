package shaders;

/**
 * Water ripple distortion (see `shaders.RippleShader`).
 *
 * Ported from Mario Madness (`RippleShader`, after https://www.shadertoy.com/view/XtsSzN);
 * credits and the list of local changes are on the shader class.
 *
 * Usage:
 * ```haxe
 * var water = new shaders.RippleEffect();
 * game.addShaderToCamera('game', water);
 * water.strength = 25.0;   // rougher water
 * water.speed = 1.0;       // and moving faster
 * ```
 *
 * From Lua/Python/HScript: `addRippleEffect('game')`. Works outside a song too
 * (title screen, menus) through `shaders.EffectTicker`.
 */
class RippleEffect extends Effect
{
  public var shader:RippleShader = new RippleShader();

  /** Seconds the effect has been running. */
  public var time(get, set):Float;

  /** Displacement strength in thousandths of the screen (10.0 matches upstream). */
  public var strength(default, set):Float = 10.0;

  /** How fast the water moves (0.5 matches upstream). */
  public var speed(default, set):Float = 0.5;

  /** Coordinate scale of the noise field: bigger is smaller, tighter ripples. */
  public var scale(default, set):Float = 1.0;

  /**
   * @param strength Displacement strength in thousandths of the screen.
   * @param speed How fast the water moves.
   * @param scale Coordinate scale of the noise field.
   */
  public function new(strength:Float = 10.0, speed:Float = 0.5, scale:Float = 1.0)
  {
    this.strength = strength;
    this.speed = speed;
    this.scale = scale;
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

  function set_strength(v:Float):Float
  {
    strength = v;
    shader.uStrength.value[0] = v;
    return v;
  }

  function set_speed(v:Float):Float
  {
    speed = v;
    shader.uSpeed.value[0] = v;
    return v;
  }

  function set_scale(v:Float):Float
  {
    scale = v;
    // A zero or negative scale collapses the noise field onto one point and the
    // ripple stops moving; keep it positive.
    shader.uScale.value[0] = Math.max(0.0001, v);
    return v;
  }
}
