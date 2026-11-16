package shaders;

import backend.FlxFixedShader;

/**
 * Line displacement and monochrome noise from Mario Madness' YCBUEndingShader
 * (Apache-2.0): https://github.com/Dewott2501/Mario-Madness/blob/main/source/YCBUEndingShader.hx
 * Replaces the unsigned integer hash and round() with GLSL ES 1.00 equivalents,
 * initializes a deterministic seed, and preserves sampled alpha instead of
 * forcing opacity. The float hash changes the exact noise pattern.
 */
class YCBUEndingShader extends FlxFixedShader
{
  @:glFragmentSource('
    #pragma header
    uniform float seed;
    uniform float intensity;

    float randomValue(vec2 st)
    {
      return fract(sin(dot(st, vec2(12.9898, 78.233))) * 43758.5453123);
    }
    float glitch(vec2 uv, float lines, float r)
    {
      return randomValue(vec2(r, floor(uv.y * lines) / lines)) * (0.5 + intensity * 0.2);
    }
    void main()
    {
      vec2 uv = openfl_TextureCoordv;
      vec2 coord = max(openfl_TextureSize, vec2(1.0)) * uv;
      if (intensity >= 0.6)
        uv.x += sin(sin(mod(coord.y, 200.0) / 15.84) * (intensity - 0.6) * (intensity - 0.6));
      float gl1 = glitch(uv, 16.0, floor(seed * 2.0));
      float gl2 = glitch(uv, 32.0, floor(seed * 5.0));
      float gl3 = glitch(uv, 6.0, floor(seed));
      float d1 = floor(gl1 + 0.5) * gl1;
      float d2 = floor(gl2 + 0.5) * gl2;
      float d3 = floor(gl3 + 0.5) * (0.75 - gl3);
      float displacement = d1 - d2 + d3;
      uv.x += displacement;
      vec4 base = flixel_texture2D(bitmap, uv);
      vec3 rgb = vec3(flixel_texture2D(bitmap, uv + displacement / 6.0).r,
                      base.g, flixel_texture2D(bitmap, uv - displacement / 6.0).b);
      if (intensity > 0.5)
      {
        float amount = clamp((intensity - 0.5) * 2.0, 0.0, 1.0);
        vec3 noise = vec3(randomValue(coord + seed), randomValue(coord + seed + 17.0), randomValue(coord + seed + 43.0));
        rgb = mix(rgb, noise, amount);
        float gray = dot(rgb, vec3(0.59, 0.3, 0.11));
        rgb = mix(rgb, vec3(gray), amount);
      }
      gl_FragColor = vec4(rgb, base.a);
    }
  ')

  public function new()
  {
    super();
    seed.value = [0.0];
    intensity.value = [0.0];
  }

  public function update(amount:Float, elapsed:Float):Void
  {
    seed.value[0] += elapsed;
    intensity.value[0] = Math.max(0.0, Math.min(1.0, intensity.value[0] + amount));
  }
}
