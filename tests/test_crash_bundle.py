#!/usr/bin/env python3
"""Static regression tests for the crash-bundle export (TODO.md §19).

Alongside the plain crash log, every crash writes a `.zip` (crash text,
`modsList.txt`, each mod's `pack.json`, prefs, screenshot) next to it, and the
crash screen can save that bundle anywhere through the cross-platform picker —
critical on Android, where `crash/` lives in buried app storage.

The archive format, caps and retention are exercised end-to-end by
`tests/haxe/CrashBundleSpec.hx` when a Haxe binary is available. These checks
are the no-toolchain layer: they pin the wiring (crash handler -> collector ->
writer -> picker), the best-effort guards that keep a bundle from ever breaking
the crash path, and the safety rules (entry-name policy, size caps, atomic
write, retention).

Run:  python3 -m unittest discover -s tests -p 'test_*.py' -v
  or: python3 tests/test_crash_bundle.py
"""
from __future__ import annotations

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

HANDLER = "source/backend/CrashHandler.hx"
GLUE = "source/backend/CrashBundle.hx"
WRITER = "source/backend/CrashBundleWriter.hx"
SPEC_RUNNER = "tests/haxe/run-crash-bundle.sh"
CI = ".github/workflows/checks.yml"


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8-sig", errors="ignore")


def code_only(source: str) -> str:
    """Source with whole-line doc/comments removed (they may name engine types)."""
    return "\n".join(
        line for line in source.splitlines()
        if not line.strip().startswith(("*", "/*", "//"))
    )


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


class CrashHandlerWiringTests(unittest.TestCase):
    def test_bundle_is_built_after_the_log_and_never_throws(self):
        handler = read(HANDLER)
        # The raw crash text is redacted once and the safe text is shared by
        # the bounded crash log and the bundle.
        self.assertIn("var crashText:String =", handler)
        self.assertIn("LogUtils.limitText(LogUtils.redact(crashText)", handler)
        self.assertIn("LogUtils.saveLog(path, safeCrashText)", handler)
        self.assertLess(
            handler.index("LogUtils.saveLog(path, safeCrashText)"),
            handler.index("CrashBundle.onCrash(safeCrashText, path);"),
            "the bundle must be built after the sanitized crash log is written",
        )
        # The call is individually guarded so a bundle failure cannot break the
        # crash handler (which is already handling a crash).
        self.assertRegex(
            handler,
            r"try\s*\{\s*CrashBundle\.onCrash\(safeCrashText, path\);\s*\}\s*catch",
            "CrashBundle.onCrash must be wrapped in its own try/catch",
        )

    def test_bundle_call_lives_under_the_sys_target_guard(self):
        handler = read(HANDLER)
        # §6 #70: the crash log (and therefore the bundle) is sys-only. The
        # onCrash call sits in the same #if sys region as the log write: the
        # nearest preceding #if sys is not closed before the call.
        call = handler.index("CrashBundle.onCrash(safeCrashText, path);")
        last_sys = handler.rindex("#if sys", 0, call)
        between = handler[last_sys:call]
        self.assertNotIn("#end", between, "the bundle call must be inside the #if sys block")
        # The callee enforces the guard too, so non-sys targets never write.
        self.assertIn("#if sys", body(read(GLUE), "public static function onCrash("))

    def test_crash_screen_offers_an_export_action(self):
        handler = read(HANDLER)
        self.assertIn("function exportBundle():Void", handler)
        self.assertIn("CrashBundle.exportLastBundle(", handler)
        self.assertIn("FlxG.keys.justPressed.E", handler)
        self.assertIn("exportButton = makeButton(", handler)
        self.assertIn("bundleStatus", handler)

    def test_mobile_gets_touch_buttons(self):
        handler = read(HANDLER)
        self.assertIn("#if mobile", handler)
        self.assertIn("restartButton = makeButton(", handler)
        self.assertIn("FlxG.mouse.overlaps(exportButton)", handler)
        self.assertIn("FlxG.mouse.overlaps(restartButton)", handler)
        self.assertIn("function restartToMenu():Void", handler)

    def test_og_crash_popup_and_notification_mention_the_bundle(self):
        handler = read(HANDLER)
        self.assertIn("A crash bundle (", handler)
        self.assertIn("(bundle: ${CrashBundle.lastBundleName})", handler)


class CrashBundleCollectionTests(unittest.TestCase):
    def test_collects_every_required_piece(self):
        glue = read(GLUE)
        collect = body(glue, "public static function collect(")
        for entry in ("'crash.txt'", "'modsList.txt'", "pack.json", "'prefs.json'"):
            self.assertIn(entry, collect, f"the bundle must include {entry}")
        self.assertIn("captureScreenshot()", collect)
        self.assertIn("screenshot.png", glue)

    def test_prefs_reuse_the_settings_backup_format(self):
        glue = read(GLUE)
        self.assertIn("SettingsBackupCodec.encode(SettingsBackup.collect())", glue)

    def test_mod_list_is_read_without_side_effects(self):
        glue = read(GLUE)
        # Mods.parseList() can rewrite modsList.txt; a crash handler must not
        # mutate the player's setup, so the raw file is read directly. Doc
        # comments may name the helper; the code must not call it.
        self.assertNotIn("Mods.parseList()", code_only(glue))
        self.assertIn("File.getContent('modsList.txt')", glue)
        self.assertIn("Mods.getModDirectories()", glue)

    def test_every_piece_is_individually_guarded(self):
        glue = read(GLUE)
        collect = body(glue, "public static function collect(")
        # Each collection step records a note instead of aborting the bundle.
        self.assertGreaterEqual(collect.count("catch (e:Dynamic)"), 5)
        self.assertIn("notes.push(", collect)

    def test_screenshot_is_best_effort_with_jpeg_fallback(self):
        glue = read(GLUE)
        shot = body(glue, "static function captureScreenshot(")
        self.assertIn("readPixels()", shot)
        self.assertIn("image.encode(PNG)", shot)
        self.assertIn("image.encode(JPEG", shot)
        self.assertIn("#if sys", shot)

    def test_vlog_tail_only_when_enabled(self):
        glue = read(GLUE)
        self.assertIn("if (VLog.enabled)", glue)
        self.assertIn("VLog.exportText()", glue)
        self.assertIn("MAX_VLOG_BYTES", glue)

    def test_export_goes_through_the_cross_platform_picker(self):
        glue = read(GLUE)
        self.assertIn("import mobile.files.MobileFilePicker;", glue)
        self.assertIn("MobileFilePicker.saveFile(", glue)
        # Pickers belong to MobileFilePicker, which owns the Lime/SAF details.
        self.assertNotIn("lime.ui.FileDialog", glue)
        self.assertNotIn("AndroidStorage.", glue)

    def test_export_cannot_stack_dialogs(self):
        glue = read(GLUE)
        self.assertIn("public static var busy(default, null):Bool = false;", glue)
        export = body(glue, "public static function exportLastBundle(")
        self.assertIn("if (busy)", export)
        self.assertIn("busy = true;", export)
        self.assertIn("busy = false;", export)

    def test_on_crash_never_throws_and_keeps_bytes_for_export(self):
        glue = read(GLUE)
        on_crash = body(glue, "public static function onCrash(")
        self.assertIn("#if sys", on_crash)
        self.assertIn("try", on_crash)
        self.assertIn("catch (e:Dynamic)", on_crash)
        self.assertIn("lastBundleBytes = built.bytes;", on_crash)


class CrashBundleWriterSafetyTests(unittest.TestCase):
    def test_writer_is_flixel_free(self):
        # Doc comments may name the engine types; the code must not use them.
        code = code_only(read(WRITER)).lower()
        for forbidden in ("flixel", "flxg", "openfl", "lime", "clientprefs"):
            self.assertNotIn(forbidden, code, f"the writer must stay dependency-free ({forbidden})")

    def test_entry_names_reuse_the_mod_path_policy(self):
        writer = read(WRITER)
        self.assertIn("ModPathPolicy.normalizeRelative(file.name)", writer)

    def test_size_and_count_caps_exist(self):
        writer = read(WRITER)
        for cap in ("MAX_ENTRY_BYTES", "MAX_BUNDLE_BYTES", "MAX_ENTRY_COUNT", "MAX_BUNDLES_KEPT"):
            self.assertIn(f"public static inline var {cap}", writer)
        build = body(writer, "public static function build(")
        self.assertIn("MAX_ENTRY_BYTES", build)
        self.assertIn("MAX_BUNDLE_BYTES", build)
        self.assertIn("MAX_ENTRY_COUNT", build)
        self.assertIn("skipped.push(", build)

    def test_crc32_is_computed_before_compression(self):
        writer = read(WRITER)
        make_entry = body(writer, "static function makeEntry(")
        self.assertIn("haxe.crypto.Crc32.make(data)", make_entry)
        self.assertLess(
            make_entry.index("haxe.crypto.Crc32.make(data)"),
            make_entry.index("haxe.zip.Tools.compress("),
            "the zip CRC32 must be set before deflating, or Writer rejects it",
        )

    def test_write_is_atomic_and_prunes_old_bundles(self):
        writer = read(WRITER)
        write_bytes = body(writer, "public static function writeBytes(")
        self.assertIn("#if sys", write_bytes)
        self.assertIn(".tmp", write_bytes)
        self.assertIn("FileSystem.rename(", write_bytes)
        self.assertIn("prune(dir);", write_bytes)
        prune = body(writer, "public static function prune(")
        self.assertIn("MAX_BUNDLES_KEPT", prune)
        self.assertIn("FileSystem.deleteFile(", prune)

    def test_failures_are_reported_not_thrown(self):
        writer = read(WRITER)
        write_bytes = body(writer, "public static function writeBytes(")
        self.assertIn("catch (e:Dynamic)", write_bytes)
        self.assertIn("result.error", write_bytes)


class WiringAndDocsTests(unittest.TestCase):
    def test_ci_runs_the_haxe_spec(self):
        ci = read(CI)
        self.assertIn("tests/haxe/run-crash-bundle.sh", ci)
        self.assertTrue((ROOT / SPEC_RUNNER).exists())

    def test_spec_covers_the_safety_rules(self):
        spec = read("tests/haxe/CrashBundleSpec.hx")
        for test in (
            "testRoundTrip",
            "testUnsafeNamesSkipped",
            "testOversizedEntrySkipped",
            "testEntryCountCap",
            "testWriteAndPrune",
            "testCollidingNames",
        ):
            self.assertIn(test, spec)

    def test_docs_exist(self):
        self.assertTrue((ROOT / "docs/CRASH_BUNDLE.md").exists())


if __name__ == "__main__":
    unittest.main()
