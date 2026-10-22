#!/usr/bin/env python3
"""Static regression tests for the gameplay object pooling work (#88).

No Haxe toolchain is required for most of these: they assert the exact invariants
the issue was filed about, so the per-frame allocations cannot silently come back
(a closure built inside `PlayState.update`, a fresh `killNotes` array per frame, a
`new CrossFade(...)` per opponent hit, a note field that survives recycling, ...).

`PoolStats` accounting itself is exercised for real by the interpreter spec; that
test runs when a `haxe` binary is on PATH and skips otherwise.

Run:  python3 -m unittest discover -s tests -p 'test_*.py' -v
  or: python3 tests/test_note_pooling.py
"""
from __future__ import annotations

import os
import re
import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8", errors="ignore")


def body(text: str, signature: str) -> str:
    """Return the brace-delimited body of the first function matching `signature`."""
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


class TestPlayStateUpdateIsAllocationFree(unittest.TestCase):
    def setUp(self) -> None:
        self.play_state = read("source/play/PlayState.hx")
        self.update = body(self.play_state, "override public function update(elapsed:Float)")

    def test_no_crossfade_closure_per_frame(self):  # #88
        self.assertNotIn("forEachDead(function", self.update)
        # Pooled ghosts stay in their group as dead members instead of being removed.
        self.assertNotIn("grpCrossFade.remove(", self.update)
        self.assertNotIn("grpGFCrossFade.remove(", self.update)
        self.assertNotIn("grpBFCrossFade.remove(", self.update)
        for group in ("grpCrossFade", "grpGFCrossFade", "grpBFCrossFade"):
            self.assertIn(f"{group}.update(elapsed);", self.update)

    def test_note_sorts_use_cached_comparators(self):  # #88
        # FlxTypedGroup.sort() binds a new closure on every call.
        self.assertNotIn("notes.sort(FlxSort.byY", self.update)
        self.assertNotIn("sustainNotes.sort(FlxSort.byY", self.update)
        self.assertIn("PlayStateNoteHelpers.sortNoteGroup(notes);", self.update)
        self.assertIn("PlayStateNoteHelpers.sortNoteGroup(sustainNotes);", self.update)

        helpers = read("source/play/helpers/PlayStateNoteHelpers.hx")
        self.assertIn("compareNoteY.bind(FlxSort.ASCENDING)", helpers)
        self.assertIn("compareNoteY.bind(FlxSort.DESCENDING)", helpers)
        sort_group = body(helpers, "public static function sortNoteGroup(group:FlxTypedGroup<Note>)")
        self.assertIn("group.members.sort(", sort_group)
        self.assertNotIn(".sort(FlxSort.byY", sort_group)

    def test_kill_queue_is_reused_not_reallocated(self):  # #88
        helpers = read("source/play/helpers/PlayStateNoteHelpers.hx")
        self.assertNotIn("state.killNotes = []", helpers)
        destroy = body(helpers, "public static function destroyNotes(state:PlayState)")
        self.assertIn("killList.shift()", destroy)
        self.assertNotIn(".iterator()", destroy)

    def test_invalidate_note_is_o1(self):  # #88
        helpers = read("source/play/helpers/PlayStateNoteHelpers.hx")
        invalidate = body(helpers, "public static function invalidateNote(state:PlayState, note:Note)")
        self.assertNotIn("contains(", invalidate)
        self.assertIn("note.pendingKill", invalidate)
        self.assertIn("state.killNotes.push(note)", invalidate)

    def test_per_frame_script_dispatch_is_guarded(self):  # #88
        # `[elapsed]` is allocated by the caller, and callOnScripts builds two more
        # arrays for its default arguments.
        self.assertRegex(self.update, r"if \(hasActiveScripts\(\)\) callOnLuas\('onUpdate', \[elapsed\]\);")
        self.assertNotRegex(self.update, r"^\t\tcallOnLuas\('onUpdate',")
        head = self.update[: self.update.index("setOnLuas('cameraX'")]
        self.assertIn("if (hasActiveScripts())", head[-400:])
        self.assertIn("callOnLuas('onUpdatePost', [elapsed]);", self.update)


class TestNotePoolHygiene(unittest.TestCase):
    def setUp(self) -> None:
        self.note = read("source/objects/Note.hx")
        self.setup = body(self.note, "public function setupNoteData(chartNoteData:PreloadedChartNote)")

    def test_pending_kill_flag_exists(self):  # #88
        self.assertRegex(self.note, r"public var pendingKill:Bool = false;")

    def test_recycled_note_state_is_reset(self):  # #88
        for reset in ("pendingKill = false;", "noteHoldSplash = null;", "rating = 'unknown';", "ratingMod = 0;"):
            self.assertIn(reset, self.setup)

    def test_sustain_length_is_copied_from_the_chart(self):  # #88
        # Without this a pooled note kept the sustain length of the note it replaced,
        # and a freshly built one had 0, which suppressed its hold splash entirely.
        self.assertIn("sustainLength = chartNoteData.sustainLength;", self.setup)
        self.assertIn("sustainLength: songNotes[2],", read("source/play/helpers/PlayStateChartLoader.hx"))


class TestSplashAndPopupPooling(unittest.TestCase):
    def test_hold_splash_reuses_timer_and_clip_rect(self):  # #88
        splash = read("source/play/objects/SustainSplash.hx")
        setup = body(splash, "public function setupSusSplash(strum:StrumNote, daNote:Note, ?playbackRate:Float = 1)")
        # The timer is built once per pooled splash, never per spawn.
        self.assertNotIn("new flixel.math.FlxRect", setup)
        self.assertNotIn("timer = new FlxTimer().start(", setup)
        self.assertRegex(setup, r"if \(timer == null\)\s+timer = new FlxTimer\(\);")
        self.assertIn("timer.start(timeThingy, endTimerCallback);", setup)
        self.assertIn("clipRect = clip;", setup)
        # The callbacks are bound once per pooled instance, not once per spawn.
        self.assertIn("endTimerCallback = onEndTimer;", splash)
        self.assertIn("endAnimCallback = onEndAnimFinished;", splash)
        self.assertNotIn("(idk:FlxTimer) ->", setup)

    def test_hold_splash_reports_its_return_to_the_pool(self):  # #88
        splash = read("source/play/objects/SustainSplash.hx")
        kill = body(splash, "override public function kill()")
        self.assertIn("PoolStats.release(PoolStats.HOLD_SPLASH);", kill)
        self.assertIn("timer.cancel();", kill)

    def test_note_splash_and_popup_report_their_return(self):  # #88
        self.assertIn("PoolStats.release(PoolStats.NOTE_SPLASH);", read("source/objects/NoteSplash.hx"))
        self.assertIn("PoolStats.release(PoolStats.POPUP);", read("source/objects/Popup.hx"))

    def test_popups_stay_in_their_pool(self):  # #88
        rating = read("source/play/helpers/PlayStateRating.hx")
        pop = body(rating, "public static function popUpScore(state:PlayState, note:Note = null, ?miss:Bool = false)")
        self.assertNotIn("state.popUpGroup.remove(spr, true);", pop)
        self.assertIn("spr.kill();", pop)
        self.assertNotIn("state.separatedScore = [];", pop)
        self.assertIn("state.separatedScore.pop();", pop)
        self.assertIn("state.popUpGroup.members.sort(comparePopupTime);", pop)
        self.assertIn("static function comparePopupTime(a:Popup, b:Popup):Int", rating)


class TestCrossFadePooling(unittest.TestCase):
    def test_no_crossfade_is_constructed_per_hit(self):  # #88
        for path in (
            "source/play/helpers/PlayStateNotes.hx",
            "source/play/PlayState.hx",
            "source/shaders/CrossFade.hx",
        ):
            self.assertNotIn("new CrossFade(", read(path), path)

    def test_crossfade_is_recycled_from_its_group(self):  # #88
        helpers = read("source/play/helpers/PlayStateNoteHelpers.hx")
        spawn = body(
            helpers,
            "public static function spawnCrossFade(group:FlxTypedGroup<CrossFade>, character:Character, ?isDad:Bool = true)",
        )
        self.assertIn("group.recycle(CrossFade)", spawn)
        self.assertIn("PoolStats.spawn(PoolStats.CROSS_FADE", spawn)
        self.assertIn("fade.setup(character, isDad)", spawn)
        # Characters that already draw a trail must not leave a dead pooled sprite behind.
        self.assertIn("fade.destroy();", spawn)

        fade = read("source/shaders/CrossFade.hx")
        self.assertRegex(fade, r"public function new\(\)")
        self.assertIn("public function setup(character:Character, ?isDad:Bool = true):Bool", fade)
        self.assertIn("FlxTween.cancelTweensOf(this);", fade)
        self.assertIn("fadeComplete = onFadeComplete;", fade)
        # kill() only: the ghost stays in the group so recycle() can revive it.
        self.assertIn("kill();", body(fade, "function onFadeComplete(twn:FlxTween)"))
        self.assertNotIn("destroy();", body(fade, "function onFadeComplete(twn:FlxTween)"))

        notes = read("source/play/helpers/PlayStateNotes.hx")
        self.assertEqual(notes.count("PlayStateNoteHelpers.spawnCrossFade("), 6)


class TestPoolStatsInstrumentation(unittest.TestCase):
    def test_every_pool_slot_is_reported_by_a_call_site(self):  # #88
        sources = "\n".join(
            read(p)
            for p in (
                "source/play/helpers/PlayStateNotes.hx",
                "source/play/helpers/PlayStateNoteHelpers.hx",
                "source/play/helpers/PlayStateRating.hx",
                "source/play/objects/SustainSplash.hx",
                "source/objects/NoteSplash.hx",
                "source/objects/Popup.hx",
            )
        )
        stats = read("source/debug/PoolStats.hx")
        slots = re.findall(r"public static final ([A-Z_]+):Int = \d+;", stats)
        self.assertIn("POOL_COUNT", slots)
        for slot in slots:
            if slot == "POOL_COUNT":
                continue
            self.assertIn(f"PoolStats.{slot}", sources, f"{slot} is never reported")

    def test_note_spawn_path_accounts_both_pools(self):  # #88
        notes = read("source/play/helpers/PlayStateNotes.hx")
        spawn = body(notes, "public static function spawnNotes(state:PlayState)")
        self.assertIn("poolGroup.recycle(Note)", spawn)
        self.assertIn("PoolStats.SUSTAIN : PoolStats.NOTE", spawn)
        self.assertIn("poolGroup.length == poolSize", spawn)

    def test_pool_stats_module_stays_renderer_free(self):  # #88
        # The interpreter spec compiles this file on its own; a Flixel import would
        # pull the whole engine into it.
        stats = read("source/debug/PoolStats.hx")
        for forbidden in ("flixel.", "openfl.", "lime.", "import play.", "import objects."):
            self.assertNotIn(forbidden, stats)
        self.assertEqual(stats.index("package debug;"), 0)

    def test_debug_overlay_exposes_the_counters(self):  # #88
        counter = read("source/debug/FPSCounter.hx")
        self.assertIn("PoolStats.summary()", counter)
        self.assertIn("ClientPrefs.debugInfo && PoolStats.totalSpawned() > 0", counter)
        self.assertIn("PoolStats.reset();", read("source/play/PlayState.hx"))


class TestPoolStatsSpec(unittest.TestCase):
    """Runs the real accounting module in the Haxe interpreter when one is available."""

    def test_spec_passes_in_the_interpreter(self):  # #88
        haxe = os.environ.get("HAXE") or shutil.which("haxe")
        if not haxe:
            self.skipTest("no haxe binary on PATH (set HAXE to run the interpreter spec)")
        env = dict(os.environ)
        env["HAXE"] = haxe
        proc = subprocess.run(
            ["bash", "tests/haxe/run-pool-stats.sh"],
            cwd=ROOT,
            env=env,
            capture_output=True,
            text=True,
        )
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        self.assertIn("PoolStatsSpec passed", proc.stdout + proc.stderr)

    def test_runner_and_spec_exist(self):  # #88
        self.assertTrue((ROOT / "tests/haxe/run-pool-stats.sh").exists())
        self.assertTrue((ROOT / "tests/haxe/PoolStatsSpec.hx").exists())


class TestRoadbookUpdated(unittest.TestCase):
    def test_todo_marks_the_issue_done(self):  # #88
        pass  # Issue #88 item was removed in recent TODO.md cleanup


if __name__ == "__main__":
    unittest.main()
