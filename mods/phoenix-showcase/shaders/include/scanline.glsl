// Shared scanline helper, expanded by the engine's #pragma include loader.
// Keeping it in include/ proves that nested shader imports work from a mod.

float showcaseScanline(vec2 uv, float time)
{
    float wave = sin((uv.y + time * 0.12) * 48.0) * 0.5 + 0.5;
    return smoothstep(0.94, 1.0, wave);
}
