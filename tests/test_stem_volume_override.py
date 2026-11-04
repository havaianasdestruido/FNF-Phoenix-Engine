"""Tests for the global song stem volume overrides (Options -> Gameplay Settings).

Guards the wiring of `overrideInstrumentalVolume` / `instrumentalVolumeOverride` and
`overrideVocalsVolume` / `vocalsVolumeOverride`: the ClientPrefs fields, the option rows that
edit them, and the playback code that resolves a stem's volume through
`play.helpers.PlayStatePlayback` instead of a hardcoded full volume. Miss-muting and Game
Renderer mode must keep priority over the override, and with both toggles off (the default)
the enforcement pass has to stay a no-op.
"""
from __future__ import annotations

from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]

TOGGLES = ("overrideInstrumentalVolume", "overrideVocalsVolume")
VALUES = ("instrumentalVolumeOverride", "vocalsVolumeOverride")
ALL_FIELDS = TOGGLES + VALUES

PLAY_HELPERS = sorted(str(p.relative_to(ROOT)) for p in (ROOT / "source" / "play").rglob("*.hx"))


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8-sig")


def option_variables(source: str) -> list[str]:
    """Every ClientPrefs field an `Option` in this substate points at.

    The variable name always sits right before the type literal ('bool', 'percent', ...).
    """
    return re.findall(r"'(\w+)',\s*\n?\s*'(?:bool|int|integer|float|fl|percent|string|str)'", source)


class StemVolumePreferenceTests(unittest.TestCase):
    def setUp(self):
        self.prefs = read("source/backend/ClientPrefs.hx")

    def test_fields_are_declared_with_untouched_defaults(self):
        # Both toggles default to off, so a fresh install plays exactly like it always did.
        for name in TOGGLES:
            with self.subTest(field=name):
                self.assertRegex(self.prefs, rf"public static var {name}:Bool = false;")
        for name in VALUES:
            with self.subTest(field=name):
                self.assertRegex(self.prefs, rf"public static var {name}:Float = 1;")

    def test_fields_are_saved_reflectively(self):
        # saveSettings()/loadPrefs() reflect over the class fields; a blacklisted name would
        # never persist, and the override would reset on every launch.
        blacklists = re.findall(r'"(?:save|load)BlackList" => \[(.*?)\]', self.prefs, re.S)
        self.assertTrue(blacklists, "save/load blacklists not found")
        for blacklist in blacklists:
            for name in ALL_FIELDS:
                with self.subTest(field=name):
                    self.assertNotIn(f'"{name}"', blacklist)


class StemVolumeOptionTests(unittest.TestCase):
    def setUp(self):
        self.options = read("source/options/GameplaySettingsSubState.hx")
        self.prefs = read("source/backend/ClientPrefs.hx")

    def test_all_four_override_options_are_registered(self):
        variables = option_variables(self.options)
        for name in ALL_FIELDS:
            with self.subTest(field=name):
                self.assertIn(name, variables)

    def test_option_variables_exist_in_client_prefs(self):
        # A typo here is silent at build time: Option reads/writes ClientPrefs through Reflect.
        declared = set(re.findall(r"public static var (\w+)", self.prefs))
        for variable in option_variables(self.options):
            with self.subTest(variable=variable):
                self.assertIn(variable, declared)

    def option_block(self, field: str) -> str:
        """The `new Option(...)` chunk (plus its `option.*` tuning) that edits `field`."""
        for chunk in self.options.split("var option:Option = new Option(")[1:]:
            if f"'{field}'" in chunk:
                return chunk
        self.fail(f"no option registered for {field}")

    def test_volume_options_are_bounded_percentages(self):
        for name in VALUES:
            block = self.option_block(name)
            with self.subTest(field=name):
                self.assertIn("'percent'", block)
                self.assertIn("option.minValue = 0.0;", block)
                self.assertIn("option.maxValue = 1;", block)
                self.assertIn("option.changeValue = 0.1;", block)
                self.assertIn("option.decimals = 1;", block)

    def test_toggle_options_are_booleans_that_default_to_off(self):
        for name in TOGGLES:
            block = self.option_block(name)
            with self.subTest(field=name):
                self.assertIn("'bool'", block)
                self.assertRegex(block, r"'bool',\s*\n\s*false\);")


class StemVolumeResolutionTests(unittest.TestCase):
    def setUp(self):
        self.playback = read("source/play/helpers/PlayStatePlayback.hx")

    def function_body(self, signature: str) -> str:
        self.assertIn(signature, self.playback)
        return self.playback.split(signature, 1)[1].split("\n\t}\n", 1)[0]

    def test_resolver_functions_exist(self):
        for signature in (
            "public static function instrumentalVolume(state:PlayState):Float",
            "public static function vocalsVolume(state:PlayState):Float",
            "public static function enforceStemVolumes(state:PlayState):Void",
        ):
            with self.subTest(signature=signature):
                self.assertIn(signature, self.playback)

    def test_renderer_mode_beats_the_override(self):
        for signature in (
            "public static function instrumentalVolume(state:PlayState):Float",
            "public static function vocalsVolume(state:PlayState):Float",
        ):
            body = self.function_body(signature)
            with self.subTest(signature=signature):
                self.assertRegex(body, r"if \(state\.ffmpegMode\) return 0;")

    def test_resolvers_read_the_matching_preference_pair(self):
        inst = self.function_body("public static function instrumentalVolume(state:PlayState):Float")
        vocals = self.function_body("public static function vocalsVolume(state:PlayState):Float")
        self.assertIn("ClientPrefs.overrideInstrumentalVolume", inst)
        self.assertIn("ClientPrefs.instrumentalVolumeOverride", inst)
        self.assertIn("ClientPrefs.overrideVocalsVolume", vocals)
        self.assertIn("ClientPrefs.vocalsVolumeOverride", vocals)
        # A saved value outside 0..1 (hand-edited save, old default) must not blow the mix up.
        self.assertIn("CoolUtil.boundTo", inst)
        self.assertIn("CoolUtil.boundTo", vocals)
        # With the toggle off the engine keeps its historical full volume.
        self.assertRegex(inst, r"return 1;")
        self.assertRegex(vocals, r"return 1;")

    def test_enforcement_is_a_noop_unless_an_override_is_on(self):
        body = self.function_body("public static function enforceStemVolumes(state:PlayState):Void")
        self.assertIn("if (state.ffmpegMode) return;", body)
        self.assertRegex(
            body,
            r"if \(!ClientPrefs\.overrideInstrumentalVolume && !ClientPrefs\.overrideVocalsVolume\) return;",
        )

    def test_enforcement_keeps_a_muted_stem_muted(self):
        # A miss mutes the vocals to 0; the per-frame pass must not unmute them again.
        body = self.function_body("public static function enforceStemVolumes(state:PlayState):Void")
        self.assertIn("state.vocals.volume > 0", body)
        self.assertIn("state.opponentVocals.volume > 0", body)

    def test_enforcement_respects_the_android_audio_focus_duck(self):
        body = self.function_body("public static function enforceStemVolumes(state:PlayState):Void")
        self.assertIn("!PlayStateAndroidMedia.isDucking()", body)
        # The accessor has to exist on every target: one definition per #if android branch.
        media = read("source/play/helpers/PlayStateAndroidMedia.hx")
        self.assertEqual(media.count("public static function isDucking():Bool"), 2)

    def test_song_start_uses_the_resolved_volumes(self):
        start = self.playback.split("public static function startSong(state:PlayState):Void", 1)[1]
        start = start.split("\n\t}\n", 1)[0]
        self.assertIn("FlxG.sound.playMusic(state.inst._sound, instrumentalVolume(state), false);", start)
        self.assertNotIn("FlxG.sound.playMusic(state.inst._sound, 1, false);", start)
        self.assertIn("if (ClientPrefs.overrideVocalsVolume)", start)
        self.assertIn("vocalsVolume(state)", start)

    def test_seeking_uses_the_resolved_volumes(self):
        seek = self.function_body("public static function setSongTime(state:PlayState, time:Float)")
        self.assertIn("else if (ClientPrefs.overrideInstrumentalVolume)", seek)
        self.assertIn("else if (ClientPrefs.overrideVocalsVolume", seek)


class StemVolumeUnmuteTests(unittest.TestCase):
    """Every unmute has to land on the resolved volume, never on a hardcoded 1."""

    def test_no_hardcoded_full_volume_unmute_left_in_gameplay(self):
        pattern = re.compile(r"vocals(?:\)|)\.volume (?:=|!=) 1\b")
        for path in PLAY_HELPERS:
            source = read(path)
            for match in pattern.finditer(source):
                line = source[: match.start()].count("\n") + 1
                with self.subTest(path=path, line=line):
                    self.fail(f"{path}:{line} still restores a vocal stem to a hardcoded 1")

    def test_unmute_paths_go_through_the_resolver(self):
        for path in ("source/play/helpers/PlayStateNotes.hx", "source/play/helpers/PlayStateRating.hx"):
            source = read(path)
            with self.subTest(path=path):
                self.assertIn("PlayStatePlayback.vocalsVolume(state)", source)
                self.assertIn("import play.helpers.PlayStatePlayback;", source)

    def test_miss_and_end_of_song_still_mute_the_stems(self):
        notes = read("source/play/helpers/PlayStateNotes.hx")
        playback = read("source/play/helpers/PlayStatePlayback.hx")
        self.assertIn("state.vocals.volume = state.opponentVocals.volume = 0;", notes)
        self.assertIn("state.opponentVocals.volume = 0;", notes)
        finish = playback.split("public static function finishSong(", 1)[1].split("\n\t}\n", 1)[0]
        self.assertIn("FlxG.sound.music.volume = 0;", finish)
        self.assertIn("state.vocals.volume = state.opponentVocals.volume = 0;", finish)


class StemVolumeEnforcementCallTests(unittest.TestCase):
    def setUp(self):
        self.state = read("source/play/PlayState.hx")

    def test_update_enforces_while_the_chart_is_live(self):
        self.assertIn("PlayStatePlayback.enforceStemVolumes(this);", self.state)
        guard = self.state.split("PlayStatePlayback.enforceStemVolumes(this);", 1)[0].rsplit("if (", 1)[1]
        for condition in ("!endingSong", "!inCutscene", "!transitioning", "!heyStopTrying", "finishTimer == null"):
            with self.subTest(condition=condition):
                self.assertIn(condition, guard)

    def test_enforcement_only_runs_inside_the_live_audio_block(self):
        # It sits in the `if (!ffmpegMode)` branch of the `startedCountdown && !paused` block, so
        # the pause menu, the game over screen and renderer mode never see it.
        block = self.state.split("if (startedCountdown && !paused)", 1)[1].split("debug.FrameProfiler.endAudio();", 1)[0]
        self.assertIn("if (!ffmpegMode)", block)
        self.assertIn("PlayStatePlayback.enforceStemVolumes(this);", block)


class StemVolumeScopeTests(unittest.TestCase):
    """The editors keep their own volume UI, so they must stay out of the override's way."""

    def test_chart_editor_still_owns_its_volumes(self):
        for path in ("source/editors/ChartingState.hx", "source/editors/EditorPlayState.hx"):
            source = read(path)
            for field in ALL_FIELDS:
                with self.subTest(path=path, field=field):
                    self.assertNotIn(field, source)

    def test_freeplay_preview_levels_untouched(self):
        source = read("source/states/helpers/FreeplayStateHelpers.hx")
        for field in ALL_FIELDS:
            with self.subTest(field=field):
                self.assertNotIn(field, source)


if __name__ == "__main__":
    unittest.main()
