package shaders;

import shaders.ErrorHandledShader.ErrorHandledRuntimeShader;

class PulseShader extends ErrorHandledRuntimeShader
{
  public var waveAmplitude(default, set):Float = 0;
  public var frequency(default, set):Float = 1;
  public var speed(default, set):Float = 1;
  public var time(default, set):Float = 0;
  public var enabled(default, set):Bool = false;

  /**
   * Executes the `new` operation.
*/
  public function new()
  {
    super('Pulse Effect', shaders.RuntimeShaders.pulseEffect);

    // Initialize with default values
    #if (!neko)
    this.setFloat('uWaveAmplitude', waveAmplitude);
    this.setFloat('uFrequency', frequency);
    this.setFloat('uSpeed', speed);
    this.setFloat('uTime', time);
    this.setBool('uEnabled', enabled);
    #end
  }

  // Setters to automatically update shader uniforms when properties change
  /**
   * Executes the `set_waveAmplitude` operation.
   * @param value Input value for `value`.
   * @return Result produced by `set_waveAmplitude`, when applicable.
   */
  function set_waveAmplitude(value:Float):Float
  {
    waveAmplitude = value;
    #if (!neko) setFloat('uWaveAmplitude', value); #end
    return value;
  }

  /**
   * Executes the `set_frequency` operation.
   * @param value Input value for `value`.
   * @return Result produced by `set_frequency`, when applicable.
   */
  function set_frequency(value:Float):Float
  {
    frequency = value;
    #if (!neko) setFloat('uFrequency', value); #end
    return value;
  }

  /**
   * Executes the `set_speed` operation.
   * @param value Input value for `value`.
   * @return Result produced by `set_speed`, when applicable.
   */
  function set_speed(value:Float):Float
  {
    speed = value;
    #if (!neko) setFloat('uSpeed', value); #end
    return value;
  }

  /**
   * Executes the `set_time` operation.
   * @param value Input value for `value`.
   * @return Result produced by `set_time`, when applicable.
   */
  function set_time(value:Float):Float
  {
    time = value;
    #if (!neko) setFloat('uTime', value); #end
    return value;
  }

  /**
   * Executes the `set_enabled` operation.
   * @param value Input value for `value`.
   * @return Result produced by `set_enabled`, when applicable.
   */
  function set_enabled(value:Bool):Bool
  {
    enabled = value;
    #if (!neko) setBool('uEnabled', value); #end
    return value;
  }

  /**
   * Executes the `update` operation.
   * @param elapsed Input value for `elapsed`.
   */
  public function update(elapsed:Float):Void
  {
    if (enabled) time += elapsed * speed;
  }
}
