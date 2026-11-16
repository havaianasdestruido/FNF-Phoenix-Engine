package shaders;

import backend.FlxFixedShader;

/**
 * Nine-tap blur and vertical darkening from Mario Madness' TwoDinThreeD
 * (Apache-2.0): https://github.com/Dewott2501/Mario-Madness/blob/main/source/TwoDinThreeD.hx
 * GLSL ES-safe unrolled taps replace the array constructor; all uniforms are
 * initialized and blur zero skips the extra fetches. Upstream declared gradMax,
 * tiltDeg and xOff but did not use them; they remain for source compatibility.
 */
class TwoDinThreeD extends FlxFixedShader
{
  @:glFragmentSource('
    #pragma header
    uniform float blur;
    uniform float gradMax;
    uniform float tiltDeg;
    uniform float xOff;
    uniform float yOff;
    void main()
    {
      vec2 uv = openfl_TextureCoordv;
      vec2 px = 1.0 / max(openfl_TextureSize, vec2(1.0));
      vec4 center = flixel_texture2D(bitmap, uv);
      vec3 color = center.rgb;
      if (blur > 0.0)
      {
        vec3 sum = center.rgb;
        sum += flixel_texture2D(bitmap, uv + px * vec2(-1.0, -1.0)).rgb;
        sum += flixel_texture2D(bitmap, uv + px * vec2(0.0, -1.0)).rgb;
        sum += flixel_texture2D(bitmap, uv + px * vec2(1.0, -1.0)).rgb;
        sum += flixel_texture2D(bitmap, uv + px * vec2(1.0, 0.0)).rgb;
        sum += flixel_texture2D(bitmap, uv + px * vec2(1.0, 1.0)).rgb;
        sum += flixel_texture2D(bitmap, uv + px * vec2(0.0, 1.0)).rgb;
        sum += flixel_texture2D(bitmap, uv + px * vec2(-1.0, 1.0)).rgb;
        sum += flixel_texture2D(bitmap, uv + px * vec2(-1.0, 0.0)).rgb;
        color = mix(color, sum / 9.0, blur);
      }
      float gradient = (uv.y - yOff / max(openfl_TextureSize.y, 1.0)) * 4.0 + 0.15;
      gl_FragColor = vec4(mix(color, vec3(0.0), gradient), center.a);
    }
  ')

  public function new(blurAmount:Float = 0.0, gradientMax:Float = 0.0, tilt:Float = 0.0)
  {
    super();
    blur.value = [blurAmount];
    gradMax.value = [gradientMax];
    tiltDeg.value = [tilt];
    xOff.value = [0.0];
    yOff.value = [0.0];
  }

  public function setXandY(x:Float, y:Float):Void
  {
    xOff.value[0] = x;
    yOff.value[0] = y;
  }
}
