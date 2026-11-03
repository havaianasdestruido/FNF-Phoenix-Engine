#!/usr/bin/env python3
"""Static regression tests for the opt-in `AndroidNotification` wiring.

`AndroidNotification` used to be dead code: it exposed a channel,
`requestPermission()` and `notify()/cancel()`, but no Haxe caller ever posted
anything (only the Media3 notification was live). It is now wired to opt-in
events — "chart backup saved" and "crash log saved" — behind the
`androidNotifications` pref. These tests pin that boundary (no Haxe toolchain
needed, same style as test_deeplink_opt_in.py): the raw `notify()` has no
direct callers, every event goes through `notifyEvent()`, the pref defaults to
off, and the POST_NOTIFICATIONS permission is only requested from the options
toggle, never unattended at startup.

Run:  python3 -m unittest discover -s tests -p 'test_*.py' -v
  or: python3 tests/test_android_notifications.py
"""
from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

NOTIFICATION = "source/android/platform/AndroidNotification.hx"
PREFS = "source/backend/ClientPrefs.hx"
MOBILE_OPTIONS = "source/mobile/options/MobileOptionsSubState.hx"
CHARTING_SAVE = "source/editors/charting/ChartingSaveLoad.hx"
CRASH_HANDLER = "source/backend/CrashHandler.hx"
MAIN = "source/Main.hx"
PLATFORM = "source/android/platform/AndroidPlatform.hx"
PHOENIX_MEDIA = "source/android/src/quack/fnf/phoenix/android/PhoenixMedia.java"
PHOENIX_CORE = "source/android/src/quack/fnf/phoenix/android/PhoenixCore.java"
DOCS = "docs/ANDROID_PLATFORM.md"

ANDROID_ONLY = re.compile(r"#if android\b(.*?)#end", re.S)


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8", errors="ignore")


def body(source: str, signature: str) -> str:
    """The brace-delimited body of the first definition matching `signature`."""
    start = source.index(signature)
    brace = source.index("{", start)
    depth = 0
    for i in range(brace, len(source)):
        if source[i] == "{":
            depth += 1
        elif source[i] == "}":
            depth -= 1
            if depth == 0:
                return source[brace:i + 1]
    raise AssertionError(f"unterminated body for {signature}")


def haxe_sources() -> list[Path]:
    return sorted((ROOT / "source").rglob("*.hx"))


class NotificationOptInTests(unittest.TestCase):
    def test_pref_exists_and_defaults_to_opt_in_off(self):
        prefs = read(PREFS)
        self.assertRegex(prefs, r"public static var androidNotifications:Bool = false;",
                         "androidNotifications must exist and default to false (opt-in)")

    def test_notify_event_checks_the_pref_before_posting(self):
        module = read(NOTIFICATION)
        event = body(module, "public static function notifyEvent(")
        self.assertIn("#if android", event, "notifyEvent must be an Android-only body")
        guard = event.index("backend.ClientPrefs.androidNotifications")
        post = event.index("notify(id, title, text)")
        self.assertLess(guard, post, "the pref check must gate the actual notify() call")

    def test_raw_notify_has_no_callers_outside_the_module(self):
        module_path = ROOT / NOTIFICATION
        offenders = []
        for path in haxe_sources():
            if path == module_path:
                continue
            text = path.read_text(encoding="utf-8", errors="ignore")
            if re.search(r"AndroidNotification\.notify\(", text):
                offenders.append(str(path.relative_to(ROOT)))
        self.assertEqual(offenders, [],
                         f"raw notify() callers bypass the opt-in pref: {offenders}")

    def test_event_ids_are_declared(self):
        module = read(NOTIFICATION)
        self.assertRegex(module, r"ID_CHART_BACKUP:Int = 100\d+")
        self.assertRegex(module, r"ID_CRASH_LOG:Int = 100\d+")

    def test_chart_backup_event_is_wired_in_autosave(self):
        save = body(read(CHARTING_SAVE), "public static function saveLevel(")
        self.assertIn("AndroidNotification.notifyEvent(AndroidNotification.ID_CHART_BACKUP", save,
                      "the chart autosave/backup path must post the backup event")
        self.assertIn("File.saveContent('backups/", save,
                      "the event must live in the branch that actually writes backups/")

    def test_crash_log_event_is_wired_and_cannot_break_crash_handling(self):
        handler = body(read(CRASH_HANDLER), "private static function onUncaughtError(")
        self.assertIn("AndroidNotification.notifyEvent(AndroidNotification.ID_CRASH_LOG", handler,
                      "the crash handler must post the crash-log event")
        self.assertIn("catch (e:Dynamic)", handler,
                      "the notification call must be guarded so it can never mask the crash")

    def test_mobile_option_is_android_only_and_asks_permission_on_enable(self):
        misc = read(MOBILE_OPTIONS)
        blocks = [b for b in ANDROID_ONLY.findall(misc) if "Event Notifications" in b]
        self.assertEqual(len(blocks), 1, "exactly one Android-only 'Event Notifications' block is expected")
        block = blocks[0]
        self.assertRegex(block, r"new Option\(\s*'Event Notifications'")
        self.assertIn("'androidNotifications'", block)
        self.assertIn("'bool'", block)
        self.assertIn("false);", block)
        change = block[block.index("option.onChange"):] if "option.onChange" in block else ""
        self.assertIn("AndroidNotification.requestPermission();", change,
                      "requestPermission must run from onChange")
        self.assertIn("curOption.getValue()", change,
                      "permission is only requested when the toggle is switched ON")
        self.assertIn("addOption(option);", block)

    def test_permission_is_never_requested_at_startup(self):
        for rel in (MAIN, PLATFORM):
            self.assertNotIn("requestPermission", read(rel),
                             f"{rel} must not request POST_NOTIFICATIONS unattended")

    def test_java_side_posts_on_general_channel_without_realering(self):
        media = read(PHOENIX_MEDIA)
        simple = body(media, "public static void notifySimple(")
        self.assertIn("GENERAL_CHANNEL_ID", simple)
        self.assertIn("setOnlyAlertOnce(true)", simple,
                      "repeated fixed-id events must update silently instead of re-alerting")
        channels = body(media, "public static void ensureChannels(")
        self.assertIn("createNotificationChannel", channels)
        cancel = body(media, "public static void cancelNotification(")
        self.assertIn("manager.cancel(id)", cancel)
        core = read(PHOENIX_CORE)
        perm = body(core, "public static void requestNotificationPermission(")
        self.assertIn("POST_NOTIFICATIONS", perm)
        self.assertIn("SDK_INT < 33", perm, "runtime permission only exists on Android 13+")

    def test_docs_describe_the_opt_in_events(self):
        docs = read(DOCS)
        self.assertIn("notifyEvent", docs)
        self.assertIn("androidNotifications", docs)
        self.assertIn("ID_CHART_BACKUP", docs)
        self.assertIn("ID_CRASH_LOG", docs)


if __name__ == "__main__":
    unittest.main()
