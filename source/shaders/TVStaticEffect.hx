package shaders;

/**
 * Untuned-television static, the effect Mario Madness runs on its title screen
 * (see `shaders.TVStaticShader`).
 *
 * Ported from Mario Madness' `TitleScreenShaders.TVStatic`; credits and the list
 * of local changes are on the shader class.
 *
 * Usage:
 * ```haxe
 * // On a sprite, the way the title screen would use it:
 * var staticEffect = new shaders.TVStaticEffect();
 * logoBl.shader = staticEffect.shader;
 *
 * // Or as a camera filter from a song script:
 * game.addShaderToCamera('game', staticEffect);
 * ```
 *
 * From Lua/Python/HScript: `addTVStaticEffect('game')`. The effect keeps ticking
 * outside a song (`shaders.EffectTicker`), so it works on the title screen and in
 * menus; when a sprite keeps it across a state switch, hold on to the effect and
 * call `shaders.EffectTicker.remove(effect.update)` if you detach it.
 */
class TVStaticEffect extends Effect
{
  public var shader:TVStaticShader = new TVStaticShader();

  /** Seconds the effect has been running. */
  public var time(get, set):Float;

  /** Overall multiplier on the static strength (1.0 matches upstream). */
  public var strength(default, set):Float = 1.0;

  /** Floor of the pulsing strength (0.3 matches upstream). */
  public var minStrength(default, set):Float = 0.3;

  /** Ceiling of the pulsing strength (0.8 matches upstream). */
  public var maxStrength(default, set):Float = 0.8;

  /** How fast the noise field churns (20.0 matches upstream). */
  public var speed(default, set):Float = 20.0;

  /**
   * @param strength Overall multiplier on the static strength.
   * @param minStrength Floor of the pulsing strength.
   * @param maxStrength Ceiling of the pulsing strength.
   * @param speed How fast the noise field churns.
   */
  public function new(strength:Float = 1.0, minStrength:Float = 0.3, maxStrength:Float = 0.8, speed:Float = 20.0)
  {
    this.strength = strength;
    this.minStrength = minStrength;
    this.maxStrength = maxStrength;
    this.speed = speed;
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

  function set_minStrength(v:Float):Float
  {
    minStrength = v;
    shader.uMinStrength.value[0] = v;
    return v;
  }

  function set_maxStrength(v:Float):Float
  {
    maxStrength = v;
    shader.uMaxStrength.value[0] = v;
    return v;
  }

  function set_speed(v:Float):Float
  {
    speed = v;
    shader.uSpeed.value[0] = v;
    return v;
  }
}
