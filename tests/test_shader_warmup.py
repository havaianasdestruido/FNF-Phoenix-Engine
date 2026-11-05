#!/usr/bin/env python3
"""Guards for the [P3] shader warm-up (TODO.md §18).

GLSL is compiled lazily the first time a shader is drawn, so a stage filter, the
`Pulse` event's `RuntimeShaders.pulseEffect` or any runtime shader a mod creates
stalls the frame that first uses it — normally the first bop of a song. The
fix compiles what the stage/song declares while `PlayState` is still loading:

  `data.StageFile.shaders` (JSON)  ─┐
  `BaseStage.declareShaders()`     ─┼─> `play.helpers.PlayStateShaders.warmUp()`
  `PlayState.screenshader`         ─┤        └─> `shaders.ShaderWarmup.warm()`
  `ShaderWarmup.track()` (scripts) ─┘             └─> OpenFL program cache

These checks keep the wiring, the target guards and the program-cache rules from
silently regressing. They need no toolchain; the interpreter specs
(`tests/haxe/run-shader-warmup.sh`) cover the logic itself.

Run:  python3 -m unittest discover -s tests -p 'test_*.py' -v
  or: python3 tests/test_shader_warmup.py
"""
from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SHADERS = ROOT / "source" / "shaders"


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8", errors="ignore")


def code(source: str) -> str:
    """Source with comments removed, so prose never trips the guards."""
    source = re.sub(r"/\*.*?\*/", "", source, flags=re.S)
    return re.sub(r"//[^\n]*", "", source)


GL_TOKENS = ("__context", "__init()", "context3D", "Context3D")


def gl_uses_outside_shader_guards(source: str) -> list[str]:
    """Lines that touch GL shader objects outside a `#if ... SHADERS_ALLOWED` block."""
    guards: list[bool] = []
    offenders: list[str] = []

    for line in source.splitlines():
        stripped = line.strip()
        if stripped.startswith("#if"):
            guards.append("SHADERS_ALLOWED" in stripped)
            continue
        if stripped.startswith("#else"):
            if guards:
                guards[-1] = not guards[-1]
            continue
        if stripped.startswith("#end"):
            if guards:
                guards.pop()
            continue
        if any(token in stripped for token in GL_TOKENS) and not any(guards):
            offenders.append(stripped)

    return offenders


class WarmupMachineryTests(unittest.TestCase):
    def setUp(self) -> None:
        self.source = read("source/shaders/ShaderWarmup.hx")
        self.body = code(self.source)

    def test_compiles_through_the_renderers_private_init_path(self):
        # `OpenGLRenderer.__initShader` does `shader.__context = __context3D;`
        # then `shader.__init()`. Anything else (a fresh draw call, a dummy
        # BitmapData) either does not compile on every backend or costs a frame.
        self.assertIn("shader.__context", self.body)
        self.assertIn("shader.__init()", self.body)
        # The private access has to be granted for the statement, not the file.
        self.assertRegex(self.body, r"@:privateAccess\s*\{")

    def test_private_gl_access_is_behind_the_shader_target_guard(self):
        # Flash/AIR (no SHADERS_ALLOWED) must still compile this file.
        self.assertEqual(gl_uses_outside_shader_guards(self.body), [])

    def test_unsupported_backends_only_bump_a_counter(self):
        # Flash/AIR/neko builds have no GL shader objects: `warm` must not try
        # to touch them, and must not crash when called.
        self.assertRegex(self.body, r"#else\s+unsupported\+\+;\s+return false;")

    def test_driver_failures_never_escape(self):
        # A broken mod shader must not take the state down while loading.
        self.assertIn("try", self.body)
        self.assertIn("catch (error:Dynamic)", self.body)
        self.assertIn("failed++", self.body)

    def test_program_cache_is_keyed_by_glsl_and_shader_family(self):
        self.assertIn("warmedPrograms", self.body)
        self.assertIn("warmedPrograms.exists(key)", self.body)
        self.assertIn("flavor + ':' + shader.glVertexSource + ':' + shader.glFragmentSource", self.body)

    def test_self_managed_shaders_are_left_alone(self):
        # `custom` shaders compile and reuse their program themselves.
        self.assertIn("function isSelfManaged", self.body)
        self.assertIn("if (isSelfManaged(shader))", self.body)
        self.assertIn("return fixed.custom;", self.body)

    def test_non_sharing_shaders_are_not_remembered(self):
        # `new FlxFixedShader(false)` compiles a program per instance, so the
        # source key must not answer for the next identical shader.
        self.assertIn("function sharesProgram", self.body)
        self.assertIn("return fixed.save;", self.body)

    def test_loading_queue_only_collects_between_begin_and_end(self):
        self.assertIn("public static function beginLoading", self.body)
        self.assertIn("public static function endLoading", self.body)
        self.assertRegex(self.body, r"if \(!collecting \|\| shader == null\) return;")


class StageDeclarationTests(unittest.TestCase):
    def test_stage_file_can_declare_shaders(self):
        stage_file = code(read("source/data/StageData.hx"))
        self.assertIn("@:optional var shaders:Array<String>;", stage_file)

    def test_base_stage_exposes_the_declaration_hook(self):
        base = code(read("source/play/BaseStage.hx"))
        self.assertIn("public function declareShaders():Array<Shader>", base)

    def test_built_in_rain_stages_declare_their_filter(self):
        for stage in ("PhillyBlazin", "PhillyStreets", "PhillyStreetsBF"):
            with self.subTest(stage=stage):
                source = code(read(f"source/stages/{stage}.hx"))
                self.assertIn("import shaders.RainShader;", source)
                self.assertIn("override function declareShaders():Array<Shader>", source)
                self.assertIn("return rainShader != null ? [rainShader] : [];", source)


class PlayStateWiringTests(unittest.TestCase):
    def setUp(self) -> None:
        self.source = code(read("source/play/PlayState.hx"))

    def test_warmup_runs_after_the_stage_exists_and_before_the_countdown(self):
        begin = self.source.index("PlayStateShaders.beginLoad();")
        stage_creation = self.source.index("case 'stage': new stages.StageWeek1();")
        warm_up = self.source.index("PlayStateShaders.warmUp(this, stageData);")
        countdown = self.source.index("startCallback();")

        self.assertLess(begin, stage_creation, "tracking must start before the stage is built")
        self.assertLess(stage_creation, warm_up, "stage shaders must exist before the warm-up")
        self.assertLess(warm_up, countdown, "warm-up must happen while the loading screen is up")

    def test_runtime_shaders_from_scripts_are_queued(self):
        scripts = code(read("source/play/helpers/PlayStateScripts.hx"))
        self.assertIn("ShaderWarmup.track(shader);", scripts)
        # `ErrorHandledRuntimeShader` is a stub (not a Shader) on neko/flash.
        self.assertRegex(scripts, r"#if !neko\s+ShaderWarmup\.track\(shader\);")

    def test_song_wide_pulse_shader_is_warmed(self):
        helper = code(read("source/play/helpers/PlayStateShaders.hx"))
        self.assertIn("ShaderWarmup.warm(PlayState.screenshader.shader, 'pulse')", helper)
        # That shader's GLSL is the runtime string the TODO calls out.
        self.assertIn("shaders.RuntimeShaders.pulseEffect", read("source/shaders/PulseShader.hx"))

    def test_helper_is_inert_where_shaders_do_not_exist(self):
        source = read("source/play/helpers/PlayStateShaders.hx")
        self.assertIn("#if (SHADERS_ALLOWED && !neko)", source)
        self.assertIn("#else", source)
        self.assertIn("public static function warmUp(state:PlayState, stageData:StageFile):Int return 0;", source)

    def test_disabled_shaders_skip_the_whole_thing(self):
        helper = code(read("source/play/helpers/PlayStateShaders.hx"))
        self.assertIn("if (!ClientPrefs.shaders)", helper)
        # The early return must still close the loading phase, or mid-song
        # shaders would pile up in the queue forever.
        self.assertIn("ShaderWarmup.endLoading();", helper)


class RegistryTests(unittest.TestCase):
    def setUp(self) -> None:
        self.source = code(read("source/shaders/ShaderWarmupRegistry.hx"))

    def test_declared_names_are_normalized_lowercase_keys(self):
        keys = re.findall(r"'([a-z0-9]+)' => function\(\):Shader", self.source)
        self.assertGreaterEqual(len(keys), 15)
        self.assertEqual(keys, [key.lower() for key in keys], "registry keys must be lowercase")

    def test_registry_keys_are_unique(self):
        keys = re.findall(r"'([a-z0-9]+)' => function\(\):Shader", self.source)
        self.assertEqual(len(keys), len(set(keys)), "duplicate registry entries silently override")

    def test_every_registered_shader_exists_with_a_no_arg_constructor(self):
        for klass in re.findall(r"function\(\):Shader return new (\w+)\(\)", self.source):
            with self.subTest(shader=klass):
                declaration = None
                for path in SHADERS.glob("*.hx"):
                    text = code(path.read_text(encoding="utf-8", errors="ignore"))
                    marker = f"class {klass} extends"
                    if marker in text:
                        declaration = text[text.index(marker):]
                        break
                self.assertIsNotNone(declaration, f"no shader class {klass} in source/shaders")
                self.assertIn("public function new()", declaration)

    def test_pulse_shader_is_only_registered_where_it_is_a_real_shader(self):
        # `ErrorHandledRuntimeShader` degrades to a stub on neko/flash, so
        # creating a PulseShader is only valid behind the runtime-shader guard.
        self.assertRegex(
            self.source,
            r"#if \(SHADERS_ALLOWED && !flash && !neko\)\s+factories\.set\('pulse'",
        )


class ModFacingDocsTests(unittest.TestCase):
    def test_stage_template_documents_the_hook(self):
        template = read("source/stages/Template.hx")
        self.assertIn("override function declareShaders():Array<Shader>", template)
        self.assertIn('"shaders": ["rain", "glitch"]', template)


if __name__ == "__main__":
    unittest.main(verbosity=2)
