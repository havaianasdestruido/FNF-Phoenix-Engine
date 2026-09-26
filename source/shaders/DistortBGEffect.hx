package shaders;

import play.PlayState;

class DistortBGEffect extends Effect
{
  public var shader:DistortBGShader = new DistortBGShader();

  public var waveSpeed(default, set):Float = 0;
  public var waveFrequency(default, set):Float = 0;
  public var waveAmplitude(default, set):Float = 0;

  /**
   * Executes the `new` operation.
   * @param waveSpeed Input value for `waveSpeed`.
   * @param waveFrequency Input value for `waveFrequency`.
   * @param waveAmplitude Input value for `waveAmplitude`.
   */
  public function new(waveSpeed:Float, waveFrequency:Float, waveAmplitude:Float):Void
  {
    this.waveSpeed = waveSpeed;
    this.waveFrequency = waveFrequency;
    this.waveAmplitude = waveAmplitude;
    shader.uTime.value = [0.0];
    PlayState.instance.shaderUpdates.push(update);
  }

  /**
   * Executes the `update` operation.
   * @param elapsed Input value for `elapsed`.
   */
  public function update(elapsed:Float):Void
  {
    shader.uTime.value[0] += elapsed;
  }

  /**
   * Executes the `set_waveSpeed` operation.
   * @param v Input value for `v`.
   * @return Result produced by `set_waveSpeed`, when applicable.
   */
  function set_waveSpeed(v:Float):Float
  {
    waveSpeed = v;
    shader.uSpeed.value = [waveSpeed];
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
    shader.uFrequency.value = [waveFrequency];
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
    shader.uWaveAmplitude.value = [waveAmplitude];
    return v;
  }
}
