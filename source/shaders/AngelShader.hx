package shaders;

import backend.FlxFixedShader;

/**
 * Pixelated, per-channel random displacement from Mario Madness' AngelShader
 * (Apache-2.0): https://github.com/Dewott2501/Mario-Madness/blob/main/source/AngelShader.hx
 * Uses fixed channel expressions for GLSL ES, clamps the pixel divisor, fixes
 * the scalar strength uniform, and uses Flixel sampling/color transforms.
 * The source pixel alpha is preserved, as in the original.
 */
class AngelShader extends FlxFixedShader
{
	#if flash	public var stronk:Dynamic = {};	public var iTime:Dynamic = {};	public var pixel:Dynamic = {};	#end

  public var strength(get, set):Float;
  public var pixelSize(get, set):Float;

  @:glFragmentSource('
    #pragma header
    uniform float stronk;
    uniform float iTime;
    uniform vec2 pixel;

    float randomValue(vec2 co)
    {
      return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
    }

    float channelSample(float channel, vec3 selector)
    {
      vec2 size = max(openfl_TextureSize, vec2(1.0)) / max(pixel, vec2(1.0));
      vec2 uv = floor(openfl_TextureCoordv * size) / size;
      uv += vec2(sin(channel * stronk), cos(channel * stronk)) * stronk * 0.05;
      float original = dot(flixel_texture2D(bitmap, clamp(uv, 0.0, 1.0)).rgb, selector);
      uv.x += (randomValue(vec2(uv.y + channel, iTime)) * 2.0 - 1.0) * stronk * 0.8 * (original + 0.2);
      uv.y += (randomValue(vec2(uv.x, iTime + channel)) * 2.0 - 1.0) * stronk * 0.1 * (original + 0.2);
      float sampled = dot(flixel_texture2D(bitmap, clamp(uv, 0.0, 1.0)).rgb, selector);
      return (sampled + abs(sampled - original)) * (randomValue(uv) * stronk + 1.0);
    }

    void main()
    {
      vec3 rgb = vec3(channelSample(0.0, vec3(1.0, 0.0, 0.0)),
                      channelSample(1.0, vec3(0.0, 1.0, 0.0)),
                      channelSample(2.0, vec3(0.0, 0.0, 1.0)));
      gl_FragColor = vec4(rgb, flixel_texture2D(bitmap, openfl_TextureCoordv).a);
    }
  ')

  public function new()
  {
    super();
    stronk.value = [0.0];
    iTime.value = [0.0];
    pixel.value = [1.0, 1.0];
  }

  public function update(elapsed:Float):Void iTime.value[0] += elapsed;
  function get_strength():Float return stronk.value[0];
  function set_strength(v:Float):Float { stronk.value[0] = v; return v; }
  function get_pixelSize():Float return (pixel.value[0] + pixel.value[1]) / 2.0;
  function set_pixelSize(v:Float):Float { pixel.value = [Math.max(1.0, v), Math.max(1.0, v)]; return v; }
}
