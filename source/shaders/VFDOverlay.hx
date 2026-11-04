package shaders;


import openfl.display.GraphicsShader;

class VFDOverlay extends GraphicsShader
{
  public var elapsedTime(default, set):Float = 0;

  function set_elapsedTime(value:Float):Float
  {
    // update() goes through this setter every frame; reuse the array.
    if (u_time.value == null)
      u_time.value = [value];
    else
      u_time.value[0] = value;
    return value;
  }

  @:glFragmentSource('#pragma header
    const vec2 s = vec2(1, 1.7320508);

    uniform float u_time;

    float rand(vec2 co){ return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453); }

    void main(void) {
      // This used to start by fetching `bitmap` into `col`, but the value
      // was fully overwritten before use, and the rand(float) overload was
      // never called. Both are gone; normalize(vec2(1.0, sqrt(3.0))) is a
      // compile-time constant ((0.5, 0.8660254)) not a per-pixel sqrt.
      const float tileAmount = 10.0;

      vec2 uv = openfl_TextureCoordv.xy * -100.0;

      vec4 hexCenter = floor(vec4(uv, uv - vec2(0.5, 1.0)) / s.xyxy) + 0.5;
      vec4 offset = vec4(uv - hexCenter.xy * s, uv - (hexCenter.zw + 0.5) * s);
      vec4 hexInfo = dot(offset.xy, offset.xy) < dot(offset.zw, offset.zw) ? vec4(offset.xy, hexCenter.xy) : vec4(offset.zw, hexCenter.zw);

      // Distance to the nearest edge of a hexagon
      vec2 p = abs(hexInfo.xy) ;
      float edgeDist = max(dot(p, vec2(0.5, 0.8660254)), p.x);
      float edgeWidth = 0.05 * tileAmount; // Adjust edge width based on tile amount
      float edgeSharpness = 0.011 * tileAmount;

      float outline = smoothstep(edgeWidth - edgeSharpness, edgeWidth, edgeDist);
      float color_mix = 0.3 * outline; // Mix black outline with white fill

      float flicker = (sin(u_time) * 0.05) + 1.0;
      float sinValue = smoothstep(-3.0, 1.0, sin(uv.y * 3.0));

      vec4 col = vec4(vec3(0.0), color_mix);
      col = mix(col, vec4(0.0, 0.0, 0.0, sinValue), 0.5 * flicker);

      float specs = rand(uv.xy);
      vec4 noise = vec4(0.0, 0.0, 0.0, specs);
      col = mix(col, noise, 0.1);

      gl_FragColor = col;
	}
  ')
  public function new()
  {
    super();

    this.elapsedTime = 0;
  }

  public function update(elapsed:Float):Void
  {
    this.elapsedTime += elapsed;
  }
}
