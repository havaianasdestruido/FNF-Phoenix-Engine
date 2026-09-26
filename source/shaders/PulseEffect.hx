package shaders;

import play.PlayState;

class PulseEffect extends Effect
{
  public var shader:PulseShader;

  public var waveSpeed(default, set):Float = 0;
  public var waveFrequency(default, set):Float = 0;
  public var waveAmplitude(default, set):Float = 0;
  public var enabled(default, set):Bool = false;

  /**
   * Executes the `new` operation.
   * @param waveSpeed Input value for `waveSpeed`.
   * @param waveFrequency Input value for `waveFrequency`.
   * @param waveAmplitude Input value for `waveAmplitude`.
   */
  public function new(waveSpeed:Float, waveFrequency:Float, waveAmplitude:Float):Void
  {
    shader = new PulseShader();

    this.waveSpeed = waveSpeed;
    this.waveFrequency = waveFrequency;
    this.waveAmplitude = waveAmplitude;
    this.enabled = false;

    // PulseShader constructor already sets defaults,
    // but we override with our specific values
    shader.speed = waveSpeed;
    shader.frequency = waveFrequency;
    shader.waveAmplitude = waveAmplitude;
    shader.enabled = false;
    shader.time = 0;

    PlayState.instance.shaderUpdates.push(update);
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
