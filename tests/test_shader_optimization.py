#!/usr/bin/env python3
"""Static regression tests for the shader optimization pass.

The built-in GLSL shaders run per-pixel over whole cameras or over every
note on screen, so redundant work in them (extra texture fetches, time-only
math recomputed inside per-channel helpers, dead code drivers still have to
compile, a full HSV round-trip for an identity color swap) costs real frame
time on the weak devices this engine targets. The Haxe side had the twin
problem: uniform setters allocating a fresh Array on every call, including
from per-frame Lua-driven effect updates.

These guards assert the optimized shapes so the costs cannot silently come
back. They need no toolchain. For a real GLSL compile check (Khronos
glslangValidator, ES 1.00 / GLSL 1.20 / ES 3.00 as rewritten by
FlxFixedShader) run tools/validate_shaders.py locally.

Run:  python3 -m unittest discover -s tests -p 'test_*.py' -v
  or: python3 tests/test_shader_optimization.py
"""
from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SHADERS = ROOT / "source" / "shaders"


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8", errors="ignore")


def shader(rel: str) -> str:
    return read(f"source/shaders/{rel}")


def code(source: str) -> str:
    """Source with // and /* */ comments removed, so prose never trips guards."""
    source = re.sub(r"/\*.*?\*/", "", source, flags=re.S)
    return re.sub(r"//[^\n]*", "", source)


def fetch_count(source: str) -> int:
    """Texture sampling calls in a GLSL-bearing Haxe file."""
    return len(re.findall(r"(?:flixel_texture2D|texture2D)\s*\(\s*bitmap", source))


class TextureFetchBudgetTests(unittest.TestCase):
    def test_bloom_fetches_center_once(self):
        # 2x8 blur taps + 1 center; the center used to be fetched 3 times.
        self.assertLessEqual(fetch_count(shader("BloomShader.hx")), 17)

    def test_blocked_glitch_shares_rb_fetch(self):
        self.assertLessEqual(fetch_count(shader("BlockedGlitchShader.hx")), 3)

    def test_three_d_single_fetch(self):
        # Used to be 3: a dead pre-fetch plus the same uv sampled twice.
        self.assertLessEqual(fetch_count(shader("ThreeDShader.hx")), 1)

    def test_grain_single_fetch(self):
        self.assertLessEqual(fetch_count(shader("Grain.hx")), 1)

    def test_chromatic_aberration_reuses_g_fetch_for_alpha(self):
        src = shader("ChromaticAberrationShader.hx")
        self.assertIn("gOffset == 0.0", src)
        self.assertLessEqual(fetch_count(src), 4)

    def test_vfd_overlay_has_no_discarded_fetch(self):
        # The overlay computes its color procedurally; its one fetch was
        # overwritten before use.
        self.assertEqual(fetch_count(shader("VFDOverlay.hx")), 0)


class GlslWorkTests(unittest.TestCase):
    def test_color_swap_skips_hsv_round_trip_by_default(self):
        src = code(read("source/objects/ColorSwap.hx"))
        self.assertIn("uTime == vec3(0.0)", src)
        # Diagonal mat4 built per fetch -> component-wise multiply.
        self.assertNotIn("mat4 colorMultiplier", src)

    def test_vcr_hoists_time_only_math_out_of_get_video(self):
        src = code(shader("VCRDistortionShader.hx"))
        self.assertNotIn("scandistort", src)
        get_video = src[src.index("vec4 getVideo"):src.index("vec2 screenDistort")]
        self.assertNotIn("onOff(", get_video)
        self.assertEqual(src.count("onOff(4.0,4.0,0.3)"), 1)
        self.assertEqual(src.count("onOff(2.0,3.0,0.9)"), 1)

    def test_rain_shader_has_no_dead_glsl(self):
        src = code(shader("RainShader.hx"))
        for dead in ("float snoise", "vec2 puddleDisplace", "vec3 lightUp",
                     "float rippleHeight", "worldToBackground"):
            self.assertNotIn(dead, src, dead)
        self.assertIn("uIntensity <= 0.0", src)

    def test_grain_colored_path_is_compile_time_dead(self):
        src = shader("Grain.hx")
        self.assertIn("const bool colored = false", src)
        # Non-constant global initializers are illegal in GLSL ES 1.00.
        self.assertNotIn("float width = openfl_TextureSize", src)

    def test_triangle_defines_its_helpers_and_hoists_mvp(self):
        src = shader("TriangleShader.hx")
        for fn in ("mat4 perspective", "mat4 translate", "mat4 rotateX",
                   "mat4 rotateY", "vec3 bary", "float baryLerp", "vec2 uvLerp"):
            self.assertIn(fn, src, fn)
        pixel = src[src.index("vec4 pixel("):src.index("void main()")]
        self.assertNotIn("perspective(", pixel)

    def test_rgb_palette_has_no_dead_alpha_branch(self):
        src = code(shader("RGBPalette.hx"))
        self.assertNotIn("newColor", src)
        self.assertIn("color.rgb = mix(color.rgb, mapped, mult)", src)

    def test_pulse_hoists_amplitude_squared(self):
        src = code(shader("RuntimeShaders.hx"))
        self.assertIn("float amp2 = uWaveAmplitude * uWaveAmplitude", src)
        self.assertEqual(src.count("uWaveAmplitude * uWaveAmplitude"), 1)

    def test_tiltshift_has_zero_amount_fast_path(self):
        src = shader("Tiltshift.hx")
        self.assertIn("if (amount == 0.0)", src)
        self.assertNotIn("pow((openfl_TextureCoordv.y", src)

    def test_wiggle_skips_sine_at_zero_amplitude(self):
        self.assertIn("uWaveAmplitude != 0.0", shader("WiggleEffect.hx"))


class HaxeSideAllocationTests(unittest.TestCase):
    def test_effect_setters_do_not_reallocate_uniform_arrays(self):
        # After construction the parameter arrays exist, so setters must
        # write value[0] (guarded) instead of replacing the array.
        plain_set = re.compile(r"shader\.\w+\.value = \[")
        ctor_ok = {"BloomEffect.hx", "ThreeDEffect.hx", "GrainEffect.hx",
                   "BuildingEffect.hx"}
        for path in sorted(SHADERS.glob("*Effect*.hx")):
            if path.name in ctor_ok or path.name == "Effect.hx":
                continue
            src = path.read_text(encoding="utf-8", errors="ignore")
            for m in plain_set.finditer(src):
                # The first allocation inside a constructor is legitimate;
                # everywhere else the assignment must be null-guarded so the
                # common path mutates value[0] in place.
                enclosing = src.rfind("function ", 0, m.start())
                if src[enclosing:enclosing + 20].startswith("function new"):
                    continue
                line = src[src.rfind("\n", 0, m.start()) + 1:src.find("\n", m.end())]
                self.assertIn("== null", "\n".join(
                    src[max(0, m.start() - 200):m.start()].splitlines()[-3:]),
                    f"{path.name}: unguarded reallocating setter: {line.strip()}")

    def test_vcr_update_does_not_reallocate_resolution_every_frame(self):
        src = shader("VCRDistortionEffect.hx")
        update = src[src.index("function update"):]
        self.assertNotIn("iResolution.value = [", update)

    def test_wiggle_enum_index_instead_of_reflection(self):
        for name in ("WiggleEffect.hx", "WiggleEffectLua.hx"):
            src = code(shader(name))
            self.assertIn("Type.enumIndex(v)", src, name)
            self.assertNotIn("getConstructors()", src, name)

    def test_wiggle_constructor_uses_type_argument(self):
        src = shader("WiggleEffect.hx")
        self.assertIn("this.effectType = typeOfEffect;", src)

    def test_playstate_shader_updates_use_indexed_loop(self):
        src = code(read("source/play/PlayState.hx"))
        self.assertIn("shaderUpdates[shaderUpdateIndex](elapsed)", src)
        self.assertNotIn("for (i in shaderUpdates)", src)


class ValidateShadersToolTests(unittest.TestCase):
    def test_extraction_produces_brace_balanced_glsl(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location(
            "validate_shaders", ROOT / "tools" / "validate_shaders.py")
        tool = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(tool)
        checked = 0
        for rel in tool.SHADER_FILES:
            text = tool.read_source(rel, None)
            meta = tool.extract(text)
            runtime = (tool.extract_runtime_shader_strings(text)
                       if rel.endswith("RuntimeShaders.hx") else {})
            for _label, frag, vert in tool.assemble(meta, runtime):
                for src in (frag, vert):
                    self.assertEqual(src.count("{"), src.count("}"), rel)
                    self.assertNotIn("#pragma header", src, rel)
                checked += 1
        self.assertGreaterEqual(checked, 20)


if __name__ == "__main__":
    unittest.main(verbosity=2)
