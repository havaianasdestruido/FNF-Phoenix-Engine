package shaders;

import shaders.WiggleEffect.WiggleEffectType;
import shaders.WiggleEffect.WiggleShader;


import play.PlayState;

class WiggleEffectLua extends Effect
{
  public var shader(default, null):WiggleShader = new WiggleShader();
  public var effectType(default, set):WiggleEffectType = DREAMY;
  public var waveSpeed(default, set):Float = 0;
  public var waveFrequency(default, set):Float = 0;
  public var waveAmplitude(default, set):Float = 0;
  public var verticalStrength(default, set):Float = 1;
  public var horizontalStrength(default, set):Float = 1;

  public function new(typeOfEffect:String = 'DREAMY', waveSpeed:Float = 0, waveFrequency:Float = 0, waveAmplitude:Float = 0, ?verticalStrength:Float = 1,
      ?horizontalStrength:Float = 1):Void
  {
    shader.uTime.value = [0.0];
    this.waveSpeed = waveSpeed;
    this.waveFrequency = waveFrequency;
    this.waveAmplitude = waveAmplitude;
    this.verticalStrength = verticalStrength;
    this.horizontalStrength = horizontalStrength;
    this.effectType = effectTypeFromString(typeOfEffect);
    PlayState.instance.shaderUpdates.push(update);
  }

  public function update(elapsed:Float):Void
  {
    shader.uTime.value[0] += elapsed;
  }

  // FIX: converted switch statement to if-else (switch cases unsupported on macOS/miscellaneous platforms)
  private function effectTypeFromString(effectType:String):WiggleEffectType
  {
    var normalized:String = effectType.trim().replace('_', '').replace('-', '').toLowerCase();
    if (normalized == 'dreamy') return DREAMY;
    if (normalized == 'wavy') return WAVY;
    if (normalized == 'horizontal' || normalized == 'heatwavehorizontal') return HEAT_WAVE_HORIZONTAL;
    if (normalized == 'vertical' || normalized == 'heatwavevertical') return HEAT_WAVE_VERTICAL;
    if (normalized == 'flag') return FLAG;
    if (normalized == 'both' || normalized == 'heatwaveboth') return HEAT_WAVE_BOTH;
    return DREAMY;
  }

  function set_effectType(v:WiggleEffectType):WiggleEffectType
  {
    effectType = v;
    if (shader.effectType.value == null)
      shader.effectType.value = [Type.enumIndex(v)];
    else
      shader.effectType.value[0] = Type.enumIndex(v);
    return v;
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

  function set_verticalStrength(v:Float):Float
  {
    verticalStrength = v;
    if (shader.verticalStrength.value == null)
      shader.verticalStrength.value = [verticalStrength];
    else
      shader.verticalStrength.value[0] = verticalStrength;
    return v;
  }

  function set_horizontalStrength(v:Float):Float
  {
    horizontalStrength = v;
    if (shader.horizontalStrength.value == null)
      shader.horizontalStrength.value = [horizontalStrength];
    else
      shader.horizontalStrength.value[0] = horizontalStrength;
    return v;
  }
}
