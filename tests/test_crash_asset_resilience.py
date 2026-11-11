"""Regression guards for the 2026-11-11 crash bundle (darnell / PhillyStreets).

Three unrelated failures showed up in that bundle and are covered here:

* ``stages/objects/ABotSpeaker.new() [line 63]`` — a null object reference on
  ``curAnim.finish()`` because the ``abot/aBotViz`` spritesheet descriptor
  could not be resolved (compact ``NO_BUILTIN_CONTENT`` builds ship the week
  folders loose on disk but do not register their asset libraries, and
  ``Paths.getPath()`` only checked the library).
* ``Rating.increase: no PlayState field for counter "sicks"`` — 30 silent
  rating losses because ``Reflect.hasField()`` is unreliable on hxcpp.
* ``[ASSET SOUND] sounds/gameOverEnd.ogg | MISSING`` — the preloader routed a
  shared/music track through ``Paths.sound()``.
"""
from __future__ import annotations

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8", errors="ignore")


def function_body(source: str, signature: str, end_marker: str) -> str:
    start = source.index(signature)
    return source[start : source.index(end_marker, start)]


def strip_comments(source: str) -> str:
    """Drops `//` line comments so assertions only see executable code."""
    lines = []
    for line in source.splitlines():
        marker = line.find("//")
        lines.append(line if marker < 0 else line[:marker])
    return "\n".join(lines)


class AtlasDescriptorResolutionTest(unittest.TestCase):
    def test_atlas_loaders_read_descriptors_through_the_disk_aware_helper(self):
        paths = read("source/backend/Paths.hx")
        for loader, ext in (
            ("getSparrowAtlas", ".xml"),
            ("getPackerAtlas", ".txt"),
            ("getAsepriteAtlas", ".json"),
        ):
            with self.subTest(loader=loader):
                body = function_body(paths, f"static public function {loader}(", "\n  static ")
                # The descriptor has to come from atlasText(), which probes the
                # filesystem; handing getPath() output to FlxAtlasFrames only
                # works when the level library is embedded.
                self.assertIn(f"atlasText('images/$key' + '{ext}'", body)
                # ... and the descriptor must never be handed to FlxAtlasFrames
                # as a bare getPath() id (that string is a library path only).
                self.assertNotIn("getPath('images/$key", body)
                self.assertIn("FlxAtlasFrames.findFrame(imageLoaded, ZERO_BORDER)", body)

    def test_atlas_text_helper_probes_the_filesystem(self):
        paths = read("source/backend/Paths.hx")
        helper = function_body(paths, "static function atlasText(", "\n  /*")
        self.assertIn("return getTextFromFile(file);", helper)

    def test_missing_atlas_parts_are_logged_for_triage(self):
        paths = read("source/backend/Paths.hx")
        helper = function_body(paths, "static function warnAtlasFailure(", "\n  /*")
        self.assertIn("VLog.assetCached('atlas'", helper)
        self.assertIn("warnedMissingAssets", helper)


class ABotSpeakerResilienceTest(unittest.TestCase):
    def setUp(self):
        self.speaker = read("source/stages/objects/ABotSpeaker.hx")

    def test_equalizer_bars_never_dereference_a_missing_animation(self):
        bar = function_body(self.speaker, "function addVizBar(", "\n\t#if flxanimate")
        self.assertIn("if (vizFrames == null) return;", bar)
        self.assertIn("if (!viz.animation.exists('VIZ'))", bar)
        self.assertIn("if (viz.animation.curAnim == null) return;", bar)
        # The finish() call must come after both guards.
        self.assertGreater(bar.index("curAnim.finish()"), bar.index("exists('VIZ')"))
        self.assertGreater(bar.index("curAnim.finish()"), bar.index("curAnim == null"))

    def test_update_skips_bars_without_a_current_animation(self):
        update = function_body(self.speaker, "override function update(elapsed:Float)", "\n\t#end")
        self.assertIn("if (anim == null) continue;", update)
        self.assertNotIn("vizSprites[i].animation.curAnim.curFrame", update)

    def test_optional_abot_art_is_guarded(self):
        self.assertIn("final bgGraphic = Paths.image('abot/stereoBG');", self.speaker)
        self.assertIn("function makeAnimate(", self.speaker)
        for guard in (
            "if (speaker != null && speaker.anim != null)",
            "&& eyes != null && eyes.anim != null",
            "if (snd == null || vizSprites.length == 0) return;",
        ):
            with self.subTest(guard=guard):
                self.assertIn(guard, self.speaker)

    def test_philly_streets_guards_the_eye_animation(self):
        stage = read("source/stages/PhillyStreets.hx")
        eye = function_body(stage, "function updateABotEye(", "\n\toverride function startSong")
        self.assertIn("if (abot == null) return;", eye)
        self.assertIn("abot.eyes != null && abot.eyes.anim != null", eye)


class RatingCounterTest(unittest.TestCase):
    def setUp(self):
        self.conductor = read("source/backend/Conductor.hx")
        self.increase = strip_comments(
            function_body(self.conductor, "public function increase(blah:Int = 1)", "\n}")
        )

    def test_increase_does_not_depend_on_hxcpp_reflect_has_field(self):
        self.assertNotIn("Reflect.hasField", self.increase)

    def test_builtin_counters_are_incremented_statically(self):
        for counter, field in (
            ("perfects", "state.perfects"),
            ("sicks", "state.sicks"),
            ("goods", "state.goods"),
            ("bads", "state.bads"),
            ("poorRatings", "state.poorRatings"),
        ):
            with self.subTest(counter=counter):
                self.assertIn(f"case '{counter}': {field} += blah;", self.increase)

    def test_mod_counters_stay_supported_and_fail_once(self):
        self.assertIn("Reflect.setField(state, counter,", self.increase)
        self.assertIn("catch (e:Dynamic)", self.increase)
        self.assertIn("unwritableCounters.set(counter, true);", self.increase)


class PreloadRoutingTest(unittest.TestCase):
    def test_game_over_retry_music_is_preloaded_as_music(self):
        loading = read("source/states/LoadingState.hx")
        preload = function_body(loading, "function preloadPlayStuff(", "\n\toverride public function onResize")
        self.assertIn("preSounds.push('music/gameOverEnd');", preload)
        self.assertNotIn("preSounds.push('sounds/gameOverEnd');", preload)
        self.assertIn("if (snd.startsWith('music/')) Paths.music(snd.substr(6));", preload)


if __name__ == "__main__":
    unittest.main()
