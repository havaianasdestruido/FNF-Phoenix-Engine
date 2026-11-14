#pragma header

// Phoenix Feature Tour runtime shader.
// Warm-up: stages/phoenix-showcase.json declares "showcase", so the engine
// compiles this before gameplay. The song script then attaches it with
// setSpriteShader() and animates the uniforms.

#pragma include "scanline.glsl"

uniform float uIntensity;
uniform float uTimer;
uniform vec3 uTint;
uniform float uTintMix;

void main()
{
    vec2 uv = openfl_TextureCoordv;

    // A cheap chromatic split, scaled by uIntensity.
    float shift = uIntensity * 0.012;
    vec4 base = flixel_texture2D(bitmap, uv);
    vec4 red = flixel_texture2D(bitmap, uv + vec2(shift, 0.0));
    vec4 blue = flixel_texture2D(bitmap, uv - vec2(shift, 0.0));

    base.r = mix(base.r, red.r, 0.85);
    base.b = mix(base.b, blue.b, 0.85);

    // Tint uniform is a float[3], animated with tweenShaderFloatArray().
    base.rgb = mix(base.rgb, uTint, uTintMix);

    // Moving scanline from include/scanline.glsl.
    float scan = showcaseScanline(uv, uTimer) * uIntensity;
    base.rgb += vec3(scan * 0.45, scan * 0.05, scan * 0.35);

    gl_FragColor = base;
}
