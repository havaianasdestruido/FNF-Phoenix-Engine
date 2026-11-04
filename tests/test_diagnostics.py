#!/usr/bin/env python3
"""Regression guards for the "Copy diagnostics" action (TODO §19).

One button in `Options -> Misc` must produce a paste-ready, **redacted**
support block and never send it anywhere:

* the entry exists and is an action-only (`link`) option next to the settings
  backup, calling `backend.Diagnostics`,
* the block carries every field the roadmap asks for — engine `VERSION`
  (through the `ENGINE_VERSION` haxedef `project.hxp` bakes in), `HaxeCommit`,
  target, `SystemInfo` CPU/RAM, GPU/driver (#96), save path, mod list and
  order, non-default prefs and the last N log lines,
* it is offline: nothing in the feature imports an HTTP client or opens a
  socket, and the copy goes to the clipboard plus a local `crash/` file,
* the defaults table that decides "non-default" matches the field
  initialisers in `ClientPrefs`, so a new preference cannot silently be
  reported as changed (or missed),
* the Flixel-free formatter is covered by the Haxe interpreter spec, which is
  wired into CI.

No Haxe toolchain needed (same style as test_settings_backup.py).

Run:  python3 -m unittest discover -s tests -p 'test_*.py' -v
  or: python3 tests/test_diagnostics.py
"""
from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

GLUE = "source/backend/Diagnostics.hx"
REPORT = "source/backend/DiagnosticsReport.hx"
VIEWER = "source/states/substates/DiagnosticsSubstate.hx"
MISC = "source/options/MiscSettingsSubState.hx"
VLOG = "source/backend/VLog.hx"
NATIVE = "source/backend/Native.hx"
SPEC = "tests/haxe/DiagnosticsReportSpec.hx"
SPEC_RUNNER = "tests/haxe/run-diagnostics-report.sh"
CI = ".github/workflows/checks.yml"


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8-sig", errors="ignore")


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


def code_only(source: str) -> str:
    """Drops comments so doc-comment mentions do not satisfy the checks."""
    source = re.sub(r"/\*.*?\*/", "", source, flags=re.S)
    return re.sub(r"//[^\n]*", "", source)


class DiagnosticsEntryTests(unittest.TestCase):
    def test_misc_menu_offers_one_action(self):
        misc = read(MISC)
        self.assertIn("'Copy Diagnostics'", misc)
        self.assertIn("'copyDiagnostics'", misc)
        # `link` = action-only option, same convention as the backup entries.
        self.assertRegex(misc, r"'copyDiagnostics',\s*'link',")
        self.assertIn("option.onChange = copyDiagnostics;", misc)
        handler = body(misc, "function copyDiagnostics():Void")
        self.assertIn("Diagnostics.copyToClipboard()", handler)
        # The viewer shows the exact string that was copied, and never a stale
        # report left over from an earlier, successful copy.
        self.assertIn("Diagnostics.lastError == null ? Diagnostics.lastReport : null", handler,
                      "a failed build must not show the previous report")
        self.assertIn("DiagnosticsSubstate(report, message)", handler,
                      "the viewer must show the exact string that was copied")
        self.assertIn("lastClipboardOk = copied;", read(GLUE),
                      "the viewer must learn the clipboard result from a flag, not the message")

    def test_viewer_shows_the_report_and_retries_the_clipboard(self):
        viewer = read(VIEWER)
        self.assertIn("extends MusicBeatSubstate", viewer)
        self.assertIn("body = new FlxText(", viewer)
        self.assertIn("Diagnostics.writeClipboard(report);", viewer)
        # Long reports must scroll instead of overflowing the panel.
        self.assertIn("maxScroll()", viewer)
        self.assertIn("addVirtualPad(UP_DOWN, A_B);", viewer)

    def test_action_sits_next_to_the_settings_backup(self):
        misc = read(MISC)
        self.assertLess(misc.index("'Copy Diagnostics'"), misc.index("addBackupOptions();"),
                        "support actions belong together, before the list is built")
        self.assertLess(misc.index("addBackupOptions();"), misc.rindex("super();"))


class DiagnosticsContentTests(unittest.TestCase):
    def test_report_has_every_field_the_roadmap_lists(self):
        report = code_only(read(REPORT))
        facts = code_only(read(GLUE))
        # TODO §19: VERSION, HaxeCommit, target, CPU/RAM, GPU/driver, save
        # path, mods + order, non-default prefs, last N log lines.
        # Keys are passed to `pushLine`, which renders them as `  key: value`.
        missing = [key for key in ("engine", "commit", "target", "cpu", "ram_total", "gpu",
                                   "gpu_driver", "save", "mods", "prefs", "log")
                   if key not in report]
        self.assertEqual(missing, [], "the report is missing these fields")
        self.assertIn("out.push('  ' + key + ': '", report, "key/value lines keep one shape")
        # Section headers, so a pasted block can be skimmed.
        headers = ("build", "hardware", "runtime", "paths", "mods", "prefs", "log")
        absent_headers = [name for name in headers if f"[{name}]" not in report]
        self.assertEqual(absent_headers, [], "missing report sections")
        absent = [field for field in ("engineVersion", "commit", "target", "cpuModel", "ramTotal",
                                      "gpuDriver", "savePath", "mods", "nonDefaultPrefs", "logLines")
                  if field + ":" not in facts]
        self.assertEqual(absent, [], "the collector does not gather these fields")

    def test_engine_version_is_the_project_hxp_value(self):
        project = read("project.hxp")
        version = re.search(r'static final VERSION:String = "([^"]+)"', project).group(1)
        self.assertIn('setHaxedef("ENGINE_VERSION", VERSION)', project)
        glue = code_only(read(GLUE))
        self.assertIn("definedVersion('ENGINE_VERSION')", glue,
                      "the report must read VERSION from the build file, not a hard-coded copy")
        # And the fallback chain resolves to the same value (#54).
        phoenix = read("source/backend/PhoenixVersion.hx")
        self.assertIn(f'FALLBACK:String = "{version}"', phoenix)

    def test_commit_comes_from_haxecommit(self):
        main_menu = read("source/states/MainMenuState.hx")
        self.assertIn("HaxeCommit.getGitCommitHash()", main_menu)
        glue = code_only(read(GLUE))
        self.assertRegex(glue, r"commit:\s*safe\(\(\) -> states\.MainMenuState\.gitCommit")

    def test_hardware_comes_from_systeminfo_and_native(self):
        glue = code_only(read(GLUE))
        self.assertIn("Native.getSystemInfo()", glue)
        self.assertIn("debug.system.SystemInfo.logicalCPUCount", glue)
        self.assertIn("debug.system.SystemInfo.totalPhysicalMemory", glue)
        self.assertIn("Native.getOpenGLRenderer", glue)
        self.assertIn("Native.getOpenGLVersion", glue)
        self.assertIn("function getOpenGLRenderer():String", read(NATIVE),
                      "#96: the raw driver strings need a Native accessor")

    def test_save_path_and_mod_order_come_from_the_real_sources(self):
        glue = code_only(read(GLUE))
        self.assertIn("CoolUtil.getSavePath", glue)
        self.assertIn("Mods.parseList()", glue)
        self.assertIn("(enabled)", glue)
        self.assertIn("(disabled)", glue)

    def test_log_tail_works_with_the_vlog_off(self):
        vlog = code_only(read(VLOG))
        # The opt-in vlog must stay opt-in; a diagnostics copy cannot require it.
        self.assertIn("public static var enabled:Bool = false;", vlog)
        self.assertIn("appendTail(line);", vlog)
        self.assertIn("public static function recentText():String", vlog)
        # With the vlog off the tail is the only source, and the tail is bound
        # so a long session cannot grow it without limit.
        self.assertIn('return tailBuffer.toString();', vlog)
        self.assertIn("TAIL_MAX_CHARS", vlog)
        self.assertIn("seedTail();", vlog)
        # Nothing is created on disk while the log is off.
        self.assertIn("if (initialized) return;\n    seedTail();\n    if (!enabled) return;", vlog)
        # With the vlog on only the end of the file is read: the file can be
        # 10 MiB and a copy on a weak device must not allocate all of it.
        self.assertIn("readFileTail(FILE, TAIL_MAX_CHARS)", vlog)
        self.assertIn("static function readFileTail(path:String, maxChars:Int):String", vlog)
        glue = code_only(read(GLUE))
        self.assertIn("VLog.recentText", glue)
        self.assertIn("DiagnosticsReport.tail", glue)


class DiagnosticsPrivacyTests(unittest.TestCase):
    def test_nothing_is_uploaded(self):
        for rel in (GLUE, REPORT):
            code = code_only(read(rel))
            for forbidden in ("HTTPRequest", "URLRequest", "urllib", "Socket", "sys.net",
                              "Http.", "haxe.Http", "Download", "postMessage", "fetch("):
                self.assertNotIn(forbidden, code, f"{rel} must stay offline ({forbidden})")

    def test_redaction_runs_on_every_line(self):
        report = code_only(read(REPORT))
        build = body(report, "public static function build(")
        # Every section goes through pushLine(), which redacts and clips.
        self.assertIn("static function pushLine(", report)
        self.assertIn("clip(redact(", report)
        # Lists are redacted as well, not just the key/value lines, and they
        # get the same known-home-folder pass.
        self.assertIn("out.push('  ' + redact(line, home));", build)
        self.assertIn("clip(redact(line, home), MAX_LOG_LINE_CHARS)", build)
        # The collector's own home directory reaches the formatter.
        self.assertIn("homeDirectory: homeDirectory()", read(GLUE))
        self.assertIn("@:optional var homeDirectory:String;", report)
        for call in ("pushLine(out, 'engine', facts.engineVersion, home);",
                     "pushLine(out, 'install', facts.installPath, home);"):
            self.assertIn(call, build)

    def test_known_home_folder_is_stripped_first(self):
        report = code_only(read(REPORT))
        redact = body(report, "public static function redact(")
        # The exact home folder must be replaced before the generic rules, and
        # the formatter must not shell out for it: the caller passes it in.
        self.assertLess(redact.index("out = replaceAll(out, homedir, '<home>')"),
                        redact.index("USER_FOLDER_WIN.replace"))
        self.assertNotIn("Sys.", report)

    def test_redaction_covers_users_homes_and_secrets(self):
        report = read(REPORT)
        for pattern in ("USER_FOLDER_WIN", "USER_FOLDER_UNIX", "ROOT_FOLDER", "EMAIL",
                        "PHOENIX_URI", "SECRET_ENV_TOKENS", "USER_PLACEHOLDER"):
            self.assertIn(pattern, report, f"missing redaction rule {pattern}")
        self.assertIn("public static inline var USER_PLACEHOLDER:String = '<user>';", report)

    def test_prefs_report_skips_keybinds_and_enumerates_arrays(self):
        report = read(REPORT)
        self.assertIn("if (Std.isOfType(item, Array)) parts.push('[' + lengthOf(item) + ' items]');", report)
        glue = read(GLUE)
        self.assertIn("SettingsBackup.preferenceFields", glue)
        self.assertIn("Std.isOfType(value, Array)", glue)

    def test_copy_writes_a_local_file_and_reports_where(self):
        glue = code_only(read(GLUE))
        self.assertIn("public static inline var FILE_PREFIX:String = 'crash/diagnostics-';", glue)
        self.assertIn("File.saveContent(path, text);", glue)
        self.assertIn("Also saved to ", glue)
        self.assertIn("if (!copied)", glue, "a target without a clipboard must still get the text")


class DiagnosticsDefaultsTests(unittest.TestCase):
    """`DEFAULTS` must stay in sync with the initialisers in `ClientPrefs`."""

    FIELD_RE = re.compile(r"^\s*public static var (\w+)\s*:\s*([^=\n]+?)\s*=\s*(.+);\s*$", re.M)

    def client_prefs_defaults(self) -> dict[str, str]:
        source = read("source/backend/ClientPrefs.hx")
        defaults: dict[str, str] = {}
        for match in self.FIELD_RE.finditer(source):
            name, kind, value = match.group(1), match.group(2), match.group(3).strip()
            if "Map<" in kind or "Array<" in kind or value.startswith("[") or value.startswith("new Map"):
                continue
            defaults[name] = value
        return defaults

    def report_defaults(self) -> dict[str, str]:
        source = read(GLUE)
        block = source[source.index("static final DEFAULTS:Dynamic"):]
        block = block[:block.index("};")]
        entries: dict[str, str] = {}
        for match in re.finditer(r"^\s*(\w+):\s*(.+?),?\s*$", block, re.M):
            entries[match.group(1)] = match.group(2).rstrip(",").strip()
        return entries

    def test_every_scalar_preference_has_a_default(self):
        expected = self.client_prefs_defaults()
        actual = self.report_defaults()
        missing = sorted(set(expected) - set(actual))
        self.assertEqual(missing, [], f"Diagnostics.DEFAULTS is missing preferences: {missing}")
        extra = sorted(set(actual) - set(expected))
        self.assertEqual(extra, [], f"Diagnostics.DEFAULTS has fields ClientPrefs no longer has: {extra}")

    def test_default_values_match_the_initialisers(self):
        def normalise(value: str) -> str:
            value = value.strip()
            # 60 vs 60.0 vs 60 are the same default for a Float/Int preference.
            if re.fullmatch(r"-?\d+\.0", value):
                value = value[:-2]
            return value.replace(" ", "")

        expected = self.client_prefs_defaults()
        actual = self.report_defaults()
        mismatches = [
            f"{name}: ClientPrefs={value!r} Diagnostics={actual.get(name)!r}"
            for name, value in expected.items()
            if name in actual and normalise(actual[name]) != normalise(value)
            # ClientPrefs' `#if mobile` conditional default is kept verbatim in
            # the table, so those entries only need to exist.
            and "#if" not in value
        ]
        self.assertEqual(mismatches, [], "defaults drifted from ClientPrefs")

    def test_gameplay_defaults_match_the_map(self):
        source = read("source/backend/ClientPrefs.hx")
        block = source.split("public static var gameplaySettings:Map<String, Dynamic> = [")[1].split("];")[0]
        expected = {m.group(1): m.group(2).strip() for m in re.finditer(r"'(\w+)'\s*=>\s*([^,\n]+)", block)}
        glue = read(GLUE)
        actual_block = glue[glue.index("static final GAMEPLAY_DEFAULTS:Dynamic"):]
        actual_block = actual_block[:actual_block.index("};")]
        actual = {m.group(1): m.group(2).rstrip(",").strip() for m in re.finditer(r"^\s*(\w+):\s*(.+?)\s*$", actual_block, re.M)}
        self.assertEqual(sorted(actual), sorted(expected),
                         "the gameplay modifier defaults must cover the same names")


class DiagnosticsSpecTests(unittest.TestCase):
    def test_formatter_is_flixel_free_and_has_a_spec(self):
        code = code_only(read(REPORT))
        for forbidden in ("flixel", "FlxG", "ClientPrefs", "openfl", "lime", "sys."):
            self.assertNotIn(forbidden, code, f"DiagnosticsReport must stay dependency-free ({forbidden})")
        self.assertTrue((ROOT / SPEC).is_file(), "missing the Haxe interpreter spec")
        self.assertTrue((ROOT / SPEC_RUNNER).is_file(), "missing the spec runner")

    def test_spec_covers_redaction_and_paste_safety(self):
        spec = read(SPEC)
        for case in ("neverLeaksIdentity", "redactionRules", "keepsLogTailShort",
                     "clipsLongLines", "diffsPrefs", "survivesNulls"):
            self.assertIn(f"static function {case}(", spec, f"the spec does not cover {case}")
        self.assertIn("GITHUB_TOKEN=<redacted>", spec)
        self.assertIn("C:\\\\Users\\\\<user>", spec)

    def test_spec_is_wired_into_ci(self):
        self.assertIn("bash tests/haxe/run-diagnostics-report.sh", read(CI))

    def test_structure_checker_covers_the_new_files(self):
        checker = read("tests/check_vlog_haxe_structure.py")
        for rel in (GLUE, REPORT, VIEWER):
            self.assertIn(rel, checker, f"{rel} must go through the Haxe structure checker")


if __name__ == "__main__":
    unittest.main()
