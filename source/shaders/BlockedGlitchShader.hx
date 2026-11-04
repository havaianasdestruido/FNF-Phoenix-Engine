package shaders;

import flixel.system.FlxAssets.FlxShader;

class BlockedGlitchShader extends FlxShader
{
  // https://www.shadertoy.com/view/MlVSD3
  @:glFragmentSource('
    #pragma header

    // ---- gllock required fields -----------------------------------------------------------------------------------------
    #define RATE 0.75
    uniform float time;
    uniform float end;
    uniform sampler2D imageData;
    uniform vec2 screenSize;
    // ---------------------------------------------------------------------------------------------------------------------

    float rand(vec2 co){
      return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453) * 2.0 - 1.0;
    }

    float offset(float blocks, vec2 uv) {
      float shaderTime = time*RATE;
      return rand(vec2(shaderTime, floor(uv.y * blocks)));
    }

    void main(void) {
      vec2 uv = openfl_TextureCoordv;
      // offset() only depends on uv, so the three channel offsets below are
      // scalar multiples of one value: evaluate the hash once instead of three
      // times, and share one fetch between the r and b channels, which sample
      // the exact same coordinates. Alpha still comes from the center texel.
      float o = offset(64.0, uv) * 0.03;
      vec4 rb = flixel_texture2D(bitmap, uv + vec2(o, 0.0));
      vec4 col = vec4(rb.r,
        flixel_texture2D(bitmap, uv + vec2(o * 0.16666666, 0.0)).g,
        rb.b,
        flixel_texture2D(bitmap, uv).a);
      gl_FragColor = col;
    }
    ')
  public function new()
  {
    super();
  }
}
