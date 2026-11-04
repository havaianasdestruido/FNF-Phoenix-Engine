#!/usr/bin/env python3
"""Regression guards for JSON chart loading performance.

The behavioral coverage lives in tests/haxe/ChartLoadingSpec.hx and
ChartLoaderSpec.hx (run by the matching run-*.sh scripts). These static guards
keep the quadratic legacy-event removal and per-note queue shifting from coming
back when Haxe is not available.
"""
from __future__ import annotations

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def body(text: str, signature: str) -> str:
    start = text.index(signature)
    open_brace = text.index("{", start)
    depth = 0
    for i in range(open_brace, len(text)):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return text[open_brace + 1 : i]
    raise AssertionError(f"unterminated body for {signature}")


class SongJsonLoadingTests(unittest.TestCase):
    def setUp(self) -> None:
        self.song = read("source/data/Song.hx")

    def test_legacy_events_are_compacted_in_one_pass(self):
        normalize = body(self.song, "private static function onLoadJson(")
        self.assertNotIn("notes.remove(note)", normalize)
        self.assertIn("var write:Int = 0;", normalize)
        self.assertIn("if(write != read) notes[write] = note;", normalize)
        self.assertIn("notes.splice(write, notes.length - write);", normalize)

    def test_parse_json_strips_utf8_bom(self):
        parse = body(self.song, "public static function parseJSON(")
        self.assertIn("charCodeAt(0) == 0xFEFF", parse)
        self.assertIn("rawJson.substr(1)", parse)


class GameplayChartLoaderTests(unittest.TestCase):
    def setUp(self) -> None:
        self.loader = read("source/play/helpers/PlayStateChartLoader.hx")

    def test_event_queues_use_indices_instead_of_shift(self):
        generate = body(self.loader, "public static function generateSong(")
        self.assertNotIn(".shift()", generate)
        self.assertIn("var charChangeIndex:Int = 0;", generate)
        self.assertIn("var multiChangeIndex:Int = 0;", generate)
        self.assertIn("state.charChangeTimes.splice(0, charChangeIndex);", generate)
        self.assertIn("state.multiChangeEvents[0].splice(0, multiChangeIndex);", generate)

    def test_note_type_work_is_hoisted_out_of_sustain_loop(self):
        generate = body(self.loader, "public static function generateSong(")
        self.assertIn("final rawNoteType:Dynamic = songNotes[3];", generate)
        self.assertIn("final rawAnimSuffix:String", generate)
        self.assertIn("final sustainMissHealth:Float", generate)
        self.assertIn("final sustainIgnore:Bool", generate)

    def test_event_loading_filters_before_allocating_subevents(self):
        helper = body(self.loader, "private static function pushEventNotes(")
        self.assertIn("if (eventTime < cutoff) continue;", helper)
        self.assertIn("strumTime: eventTime + ClientPrefs.noteOffset", helper)
        self.assertNotIn("newEventNote", helper)

    def test_restart_cutoff_is_computed_once(self):
        generate = body(self.loader, "public static function generateSong(")
        self.assertIn("final noteCutoff:Float = startingPoint + offsetStart;", generate)
        self.assertNotIn("startingPoint + offsetStart)", generate.replace("final noteCutoff:Float = startingPoint + offsetStart;", ""))


if __name__ == "__main__":
    unittest.main(verbosity=2)
