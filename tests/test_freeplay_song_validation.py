"""Regression tests for freeplay's song validation.

`Paths.inst()` / `Paths.voices()` return a loaded `Sound` on native builds (an
asset URL on web) -- never a filesystem path. Freeplay's "JS Engine
Anti-Crash Tool" fed them straight into `sys.FileSystem.exists()`, and looked
for the chart at `data/<chart>/<chart>.json` instead of
`data/<song>/<chart>.json`, so *every* song looked broken:

* built-in songs  -> "Your song seems to not have an Inst.ogg"
* mod songs       -> "It appears that <song> doesn't actually have a JSON..."

On Windows `CoolUtil.coolError()` is `Window.alert()` -> `SDL_ShowSimpleMessageBox`,
a modal dialog that blocks the main thread, so picking the bundled bf-clicker
mod froze the game before `PlayState` (and the mod's Python script) ever ran.

These tests pin the corrected contract: existence checks must use the Bool
helpers, must be mods-aware, and the bundled mod must satisfy them.

Run:  python3 -m unittest discover -s tests -p 'test_*.py' -v
"""
from __future__ import annotations

import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8", errors="ignore")


class PathsAudioExistenceHelperTests(unittest.TestCase):
    def test_helpers_exist_and_return_bool(self):
        paths = read("source/backend/Paths.hx")
        self.assertIn(
            "static public function instExists(song:String, ?difficulty:String = ''):Bool",
            paths,
        )
        self.assertIn(
            "static public function voicesExists(song:String, ?difficulty:String = ''):Bool",
            paths,
        )
        self.assertIn("static function songAudioExists(", paths)

    def test_helper_checks_mod_folders_difficulty_variant_and_song_library(self):
        paths = read("source/backend/Paths.hx")
        helper = paths[paths.index("static function songAudioExists(") :]
        helper = helper[: helper.index("static public function playMenuMusic")]
        # mod folders first (modFolders falls back to 'mods/<key>' when absent)
        self.assertIn("FileSystem.exists(modFolders('songs/$key.$SOUND_EXT'))", helper)
        # then the raw song folder and the 'songs' library id returnSound builds
        self.assertIn("FileSystem.exists('assets/songs/$key.$SOUND_EXT')", helper)
        self.assertIn("OpenFlAssets.exists('songs:' + gottenPath, SOUND)", helper)
        # difficulty-specific audio (Inst-hard.ogg) then the plain file
        self.assertIn("'$formatted/$file-$diff'", helper)
        self.assertIn("'$formatted/$file'", helper)

    def test_inst_and_voices_still_return_the_loadable_asset(self):
        # The Bool helpers are additive: loading must keep its old signature so
        # generateSong / the chart editor are untouched.
        paths = read("source/backend/Paths.hx")
        self.assertIn("static public function inst(song:String, ?difficulty:String = ''):Any", paths)
        self.assertIn("static public function voices(song:String, ?difficulty:String = '', ?postfix:String = null):Any", paths)


class FreeplayValidationTests(unittest.TestCase):
    def test_no_sound_object_is_ever_passed_to_an_exists_check(self):
        offenders = []
        pattern = re.compile(r"exists\(\s*Paths\.(inst|voices|sound|music)\(")
        for hx in (ROOT / "source").rglob("*.hx"):
            for lineno, line in enumerate(
                hx.read_text(encoding="utf-8", errors="ignore").splitlines(), 1
            ):
                if pattern.search(line) and not line.lstrip().startswith(("*", "//", "#")):
                    offenders.append(f"{hx.relative_to(ROOT)}:{lineno}: {line.strip()}")
        self.assertEqual([], offenders, "Sound objects passed to an exists() check")

    def test_anti_crash_check_uses_the_real_chart_path_and_mods_folders(self):
        freeplay = read("source/states/FreeplayState.hx")
        block = freeplay[freeplay.index("// Anti-crash sanity check for the week author.") :]
        block = block[: block.index("#end", block.index("audioExists"))]

        # data/<song>/<chart>.json, not data/<chart>/<chart>.json
        self.assertIn("final chartName:String = songLowercase + '/' + poop;", block)
        self.assertNotIn("poop + '/' + poop", block)
        # mod charts live under mods/, so both roots must be probed
        self.assertIn("Paths.modsJson(chartName)", block)
        self.assertIn("Paths.json(chartName)", block)
        self.assertIn("Paths.instExists(songLowercase", block)

    def test_all_three_warnings_still_exist_and_only_fire_on_real_gaps(self):
        freeplay = read("source/states/FreeplayState.hx")
        for condition in (
            "if(audioExists && !chartExists)",
            "} else if(chartExists && !audioExists)",
            "} else if(!chartExists && !audioExists)",
        ):
            self.assertIn(condition, freeplay)
        for message in (
            "The JSON's name does not match with",
            "Your song seems to not have an Inst.ogg",
            "doesn't actually have a JSON, nor does it actually have voices/instrumental files",
        ):
            self.assertIn(message, freeplay)

    def test_song_preview_check_is_mods_aware_on_every_target(self):
        freeplay = read("source/states/FreeplayState.hx")
        # sys/MODS_ALLOWED branch and the asset-only branch both use the helper
        # SPACE preview (sys + asset-only branches) and the ENTER anti-crash check
        self.assertEqual(
            3,
            freeplay.count(
                "Paths.instExists(songLowercase, CoolUtil.difficulties[curDifficulty].toLowerCase())"
            ),
            "the preview (SPACE) and accept (ENTER) paths must all use instExists",
        )
        # the web branch used to build a bogus 'songs:assets/songs/<song>/<chart>/Inst' id
        self.assertNotIn("Paths.inst(songLowercase + '/' + poop", freeplay)


class BundledModValidationTests(unittest.TestCase):
    """The shipped bf-clicker mod must pass the checks the engine now performs."""

    MOD = "bf-clicker"

    def test_mod_is_enabled_by_default(self):
        entries = [
            line.strip() for line in read("modsList.txt").splitlines() if line.strip()
        ]
        self.assertIn(f"{self.MOD}|1", entries)

    def test_chart_and_audio_resolve_for_every_difficulty(self):
        for chart in ("bf-clicker", "bf-clicker-easy", "bf-clicker-hard"):
            with self.subTest(chart=chart):
                self.assertTrue(
                    (ROOT / f"mods/{self.MOD}/data/{self.MOD}/{chart}.json").is_file(),
                    "chart must exist under mods/<mod>/data/<song>/",
                )
        # Paths.instExists(): difficulty-specific file is optional, Inst.ogg is not
        self.assertTrue(
            (ROOT / f"mods/{self.MOD}/songs/{self.MOD}/Inst.ogg").is_file(),
            "mods/<mod>/songs/<song>/Inst.ogg must exist or the mod cannot play",
        )

    def test_week_lists_the_song_the_mod_actually_ships(self):
        week = json.loads(read(f"mods/{self.MOD}/weeks/{self.MOD}-week.json"))
        for entry in week["songs"]:
            song = entry[0].lower().replace(" ", "-")
            self.assertTrue(
                (ROOT / f"mods/{self.MOD}/data/{song}/{song}.json").is_file(),
                f"week lists '{entry[0]}' but no chart ships for it",
            )
            self.assertTrue(
                (ROOT / f"mods/{self.MOD}/songs/{song}/Inst.ogg").is_file(),
                f"week lists '{entry[0]}' but no instrumental ships for it",
            )

    def test_inst_is_a_decodable_ogg_container(self):
        # Paths.returnSound() throws unless the first four bytes are 'OggS'.
        head = (ROOT / f"mods/{self.MOD}/songs/{self.MOD}/Inst.ogg").read_bytes()[:4]
        self.assertEqual(b"OggS", head)


if __name__ == "__main__":
    unittest.main(verbosity=2)
