package shaders;

import play.PlayState;

class DistortBGEffect extends Effect
{
  public var shader:DistortBGShader = new DistortBGShader();

  public var waveSpeed(default, set):Float = 0;
  public var waveFrequency(default, set):Float = 0;
  public var waveAmplitude(default, set):Float = 0;

  public function new(waveSpeed:Float, waveFrequency:Float, waveAmplitude:Float):Void
  {
    this.waveSpeed = waveSpeed;
    this.waveFrequency = waveFrequency;
    this.waveAmplitude = waveAmplitude;
    shader.uTime.value = [0.0];
    PlayState.instance.shaderUpdates.push(update);
  }

  public function update(elapsed:Float):Void
  {
    shader.uTime.value[0] += elapsed;
  }

  function set_waveSpeed(v:Float):Float
  {
    waveSpeed = v;
    if (shader.uSpeed.value == null)
      shader.uSpeed.value = [waveSpeed];
    else
      shader.uSpeed.value[0] = waveSpeed;
    return v;
  }

  function set_waveFrequency(v:Float):Float
  {
    waveFrequency = v;
    if (shader.uFrequency.value == null)
      shader.uFrequency.value = [waveFrequency];
    else
      shader.uFrequency.value[0] = waveFrequency;
    return v;
  }

  function set_waveAmplitude(v:Float):Float
  {
    waveAmplitude = v;
    if (shader.uWaveAmplitude.value == null)
      shader.uWaveAmplitude.value = [waveAmplitude];
    else
      shader.uWaveAmplitude.value[0] = waveAmplitude;
    return v;
  }
}
