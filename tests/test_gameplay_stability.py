"""Regression guards for pooled gameplay state and hot-path behavior."""
from __future__ import annotations

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8", errors="ignore")


class GameplayStabilityTest(unittest.TestCase):
    def test_recycled_notes_reset_mod_owned_state(self):
        note = read("source/objects/Note.hx")
        for value in (
            "extraData.clear();",
            "noteSplashData.disabled = false;",
            "noteSplashData.texture = null;",
            "noteSplashDisabled = false;",
            "offsetX = offsetY = offsetAngle = 0;",
            "copyX = copyY = copyAngle = copyAlpha = copyScaleX = copyScaleY = true;",
            "earlyHitMult = 0.5;",
            "ratingDisabled = false;",
            "hitsoundDisabled = false;",
        ):
            with self.subTest(value=value):
                self.assertIn(value, note)
        self.assertIn("@:bypassAccessor noteType = null;", note)
        self.assertIn("noMissAnimation = chartNoteData.noMissAnimation;", note)

    def test_missing_note_type_data_is_cached_and_safe(self):
        config = read("source/backend/NoteTypesConfig.hx")
        missing_file_branch = config.split("#if sys", 1)[1].split("#end", 1)[0]
        self.assertIn("noteTypesData.set(name, null);", missing_file_branch)
        self.assertIn("if (str == null)", config)
        self.assertNotIn("!str.contains(':') || !str.contains('=')", config)

    def test_note_kill_queue_dequeues_in_constant_time(self):
        helpers = read("source/play/helpers/PlayStateNoteHelpers.hx")
        self.assertIn("killList.pop()", helpers)
        self.assertNotIn("killList.shift()", helpers)

    def test_sustain_follow_updates_its_hitbox_once(self):
        note = read("source/objects/Note.hx")
        follow = note.split("inline public function followStrum", 1)[1].split(
            "public function clipToStrumNote", 1
        )[0]
        self.assertEqual(follow.count("updateHitbox();"), 1)

    def test_recycled_sustains_are_centred_on_the_lane_arrow(self):
        note = read("source/objects/Note.hx")
        # Hold bodies are centred with (arrow width - hold width) / 2. The arrow width
        # has to come from `laneArrowWidth`: `width` still describes the hold frame at
        # that point, so the old `offsetX += width / 2 ... -= width / 2` dance centred
        # a fresh note correctly but left recycled holds ~37px off their lane.
        self.assertIn("laneArrowWidth = width;", note)
        self.assertIn(
            "final laneWidth:Float = (laneArrowWidth > 0 ? laneArrowWidth : width);", note
        )
        self.assertIn("offsetX = (laneWidth - width) / 2;", note)
        # Only the pixel path may still recentre from the pre-play width (its
        # `reloadNote()` already re-measured the frame, so it is a no-op there).
        self.assertEqual(note.count("offsetX += width / 2;"), 1)
        self.assertEqual(note.count("offsetX -= width / 2;"), 1)

    def test_lane_arrow_width_survives_recycling(self):
        note = read("source/objects/Note.hx")
        # `laneArrowWidth` describes the noteskin, so it is captured when the skin
        # loads and must not be reset with the per-chart-note pooled state.
        skin_load = note.split("if (!changeSize)", 1)[1].split("offsetX = 0;", 1)[0]
        self.assertIn("laneArrowWidth = width;", skin_load)
        reset = note.split("private function resetPooledState", 1)[1]
        self.assertNotIn("laneArrowWidth", reset)

    def test_spawn_queue_does_not_require_an_unneeded_lookahead(self):
        notes = read("source/play/helpers/PlayStateNotes.hx")
        spawn = notes.split("public static function spawnNotes", 1)[1].split(
            "public static function updateNote", 1
        )[0]
        self.assertNotRegex(spawn, r"notesAddedCount\s*\+\s*1")

    def test_vocal_volume_conditions_keep_chart_sides_separate(self):
        notes = read("source/play/helpers/PlayStateNotes.hx")
        self.assertIn("else if (!PlayState.opponentChart && state.vocals.volume != 0)", notes)
        self.assertIn("else if (!PlayState.opponentChart && state.vocals.volume != vocalVolume)", notes)
        self.assertIn("else if (PlayState.opponentChart && state.vocals.volume != vocalVolume)", notes)
        self.assertNotIn("|| state.vocals.volume != 0)", notes)
        self.assertNotIn("|| state.vocals.volume != vocalVolume)", notes)

    def test_seek_back_into_vocals_checks_the_target_time(self):
        playback = read("source/play/helpers/PlayStatePlayback.hx")
        self.assertIn(
            "time <= state.vocals.length || Conductor.songPosition <= state.vocals.length",
            playback,
        )


if __name__ == "__main__":
    unittest.main()
