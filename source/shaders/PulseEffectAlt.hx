package shaders;

class PulseEffectAlt
{
  public var shader(default, null):PulseShader;

  public var waveSpeed(default, set):Float = 0;
  public var waveFrequency(default, set):Float = 0;
  public var waveAmplitude(default, set):Float = 0;
  public var enabled(default, set):Bool = false;

  /**
   * Executes the `new` operation.
*/
  public function new():Void
  {
    shader = new PulseShader();
    shader.speed = 0;
    shader.frequency = 0;
    shader.waveAmplitude = 0;
    shader.enabled = false;
  }

  /**
   * Executes the `update` operation.
   * @param elapsed Input value for `elapsed`.
   */
  public function update(elapsed:Float):Void
  {
    shader.update(elapsed);
  }

  /**
   * Executes the `set_waveSpeed` operation.
   * @param v Input value for `v`.
   * @return Result produced by `set_waveSpeed`, when applicable.
   */
  function set_waveSpeed(v:Float):Float
  {
    waveSpeed = v;
    shader.speed = v;
    return v;
  }

  /**
   * Executes the `set_enabled` operation.
   * @param v Input value for `v`.
   * @return Result produced by `set_enabled`, when applicable.
   */
  function set_enabled(v:Bool):Bool
  {
    enabled = v;
    shader.enabled = v;
    return v;
  }

  /**
   * Executes the `set_waveFrequency` operation.
   * @param v Input value for `v`.
   * @return Result produced by `set_waveFrequency`, when applicable.
   */
  function set_waveFrequency(v:Float):Float
  {
    waveFrequency = v;
    shader.frequency = v;
    return v;
  }

  /**
   * Executes the `set_waveAmplitude` operation.
   * @param v Input value for `v`.
   * @return Result produced by `set_waveAmplitude`, when applicable.
   */
  function set_waveAmplitude(v:Float):Float
  {
    waveAmplitude = v;
    shader.waveAmplitude = v;
    return v;
  }
}
