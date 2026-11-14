#!/usr/bin/env python3
"""Static regression tests for the read-only `phoenix://diagnostics` route.

TODO.md §19 asked for one link support can send, so that a player taps it and
screenshots what opens. The promise has three parts, and each is pinned here
(no Haxe toolchain needed), in the style of `test_asset_caching.py`:
`checks.yml` runs the compiled specs, this file is the fast local guard.

  * the parser accepts the route in both of its spellings and rejects anything
    it cannot use, while the version 1 menu contract stays exactly as it was;
  * the router opens the diagnostics page instead of the placeholder stub it
    used to be, and the dispatch set never grows into gameplay or the editors;
  * the page and the report builder only read, stay bounded, and stay
    documented in both `URI.MD` and the site;
  * `bash tests/haxe/run-diagnostics-report.sh` compiles and runs both halves
    against small stubs, so the layout, the bounds and the read-only promise are
    checked by execution and not only by the patterns below.

Run:  python3 -m unittest discover -s tests -p 'test_*.py' -v
  or: python3 tests/test_deeplink_diagnostics.py
"""
from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

PARSER = "source/backend/deeplink/PhoenixURI.hx"
KINDS = "source/backend/deeplink/URIKind.hx"
ROUTER = "source/backend/deeplink/DeepLinks.hx"
STATE = "source/states/DiagnosticsState.hx"
REPORT = "source/backend/DiagnosticsReport.hx"
TESTS = "tests/uri/TestPhoenixURI.hx"
RUNNER = "tests/uri/run.sh"

# `audio` joined the v1 menu set with Options -> Audio (the master volume row);
# it is a menu destination like `misc`, so it belongs to the same allowlist.
MENU_NAMES = ["main", "mods", "options", "misc", "audio", "story", "freeplay", "credits"]

# Anything that would mean "this page changed the player's game or disk".
WRITE_PATTERNS = (
    r"ClientPrefs\.\w+\s*=[^=]",
    r"FlxG\.save",
    r"File\.(write|saveContent|append|getBytes\s*\(\s*[\"']crash)",
    r"FileSystem\.(createDirectory|deleteFile|rename)",
    r"Sys\.(command|exit|putEnv|setCwd)",
    r"new sys\.io\.Process",
)


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8", errors="ignore")


def code(rel: str) -> str:
    """The file with its comments stripped, so prose cannot satisfy a check.

    Only used for files that keep `//` out of their string literals.
    """
    source = read(rel)
    source = re.sub(r"/\*.*?\*/", "", source, flags=re.S)
    return re.sub(r"//[^\n]*", "", source)


def block(source: str, signature: str) -> str:
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


def case_body(source: str, case: str, following: str) -> str:
    """One `case …:` arm of a switch, up to the arm named `following`."""
    start = source.index(case)
    end = source.index(following, start)
    return source[start:end]


class DiagnosticsParserTests(unittest.TestCase):
    def test_kind_exists_and_carries_nothing(self):
        kinds = read(KINDS)
        self.assertTrue(re.search(r"^\s*Diagnostics\s*;", kinds, re.M),
                        "URIKind must keep a parameterless Diagnostics route")

    def test_host_and_screen_alias_both_reach_the_route(self):
        source = read(PARSER)
        diagnostics = case_body(source, 'case "diagnostics":', 'case "replay":')
        self.assertIn("if (pathParts.length != 0) return null;", diagnostics,
                      "the page has no sub-views, so any extra segment is malformed")
        self.assertIn("mk(Diagnostics, query);", diagnostics)
        screen = case_body(source, 'case "screen":', 'case "song":')
        self.assertIn('if (pathParts[0] == "diagnostics") mk(Diagnostics, query);', screen,
                      "phoenix://screen/diagnostics must land on the same route as the host")

    def test_route_takes_no_parameters(self):
        source = read(PARSER)
        mk = block(source, "static function mk(")
        arm = case_body(mk, "case Diagnostics:", "default:")
        self.assertIn("if (hasParams(query))", arm,
                      "a link carrying a query is malformed, not silently narrowed")
        self.assertRegex(source, r"hasParams\([^)]*\)[^;]*query\s*!=\s*null\s*&&\s*query\.keys\(\)\.hasNext\(\)",
                         "hasParams must look at the parsed map, not at the raw string")

    def test_v1_menu_contract_is_untouched(self):
        source = read(PARSER)
        parse = block(source, "public static function parse(")
        self.assertIn('"main", "mods", "options", "misc", "audio", "story", "freeplay", "credits"', parse)
        self.assertNotIn("diagnostics", parse,
                         "the legacy parser stays menu-only; diagnostics is a v2 route")
        allowlist = re.search(r'\[([^\]]*)\]\.indexOf\(route\)', source).group(1)
        self.assertEqual([n.strip(" '\"") for n in allowlist.split(",")], MENU_NAMES,
                         "the Menu/Screen allowlist must stay exactly the v1 menu names, "
                         "so phoenix://menu/diagnostics cannot reach the router")

    def test_parser_tests_cover_the_route(self):
        tests = read(TESTS)
        self.assertIn("checkEx(uri, 'Diagnostics')", tests)
        self.assertIn("phoenix://screen/diagnostics", tests)
        self.assertIn("phoenix://diagnostics?copy=1", tests,
                      "rejecting unusable parameters is a contract, so it needs a case")
        self.assertIn("['phoenix://diagnostics', 'phoenix://screen/diagnostics', 'phoenix://menu/diagnostics']", tests,
                      "the v1 parser keeping its menu-only answer for the new route is a contract too")
        self.assertRegex(tests, r"'phoenix://menu/diagnostics'\]\)\s*\n\s*check\(uri, null\);",
                         "and it has to be asserted against the legacy parse(), not parseEx")
        # The isolated runner has to copy the parser's result types as well, or
        # the v2 API cannot compile at all.
        runner = read(RUNNER)
        for module in ("PhoenixURI", "ParsedURI", "URIKind"):
            self.assertIn(module, runner)


class DiagnosticsRouterTests(unittest.TestCase):
    def test_route_opens_the_page_instead_of_the_placeholder(self):
        source = read(ROUTER)
        arm = case_body(source, "case Diagnostics:", "case Replay")
        self.assertIn("states.DiagnosticsState", arm,
                      "the stub that fell through to the main menu is not a destination")
        self.assertNotIn("MainMenuState.new", arm)
        self.assertNotIn("coolError", arm, "a valid link must not nag the player")

    def test_the_dispatch_path_writes_nothing(self):
        source = read(ROUTER)
        dispatch = block(source, "static function dispatchEx(")
        arm = case_body(dispatch, "case Diagnostics:", "case Replay")
        for pattern in (r"ClientPrefs\.\w+\s*=[^=]", r"File\.", r"Sys\.command", r"FlxG\.save"):
            self.assertIsNone(re.search(pattern, arm),
                              "opening a link must never write: " + pattern)

    def test_only_idle_menu_states_dispatch(self):
        dispatchers = sorted(p.relative_to(ROOT / "source").as_posix()
                             for p in (ROOT / "source").rglob("*.hx")
                             if "DeepLinks.dispatch()" in p.read_text(encoding="utf-8", errors="ignore"))
        self.assertEqual(dispatchers, ["states/MainMenuState.hx", "states/TitleState.hx"],
                         "the diagnostics page must stay deferred while the player is "
                         "in gameplay, an editor or a settings list")


class DiagnosticsPageTests(unittest.TestCase):
    def test_page_is_read_only(self):
        source = code(STATE)
        for pattern in WRITE_PATTERNS:
            self.assertIsNone(re.search(pattern, source),
                              "the diagnostics page exists to be tapped blindly, so it may never "
                              + pattern)

    def test_page_does_not_free_the_memory_it_is_meant_to_report(self):
        source = code(STATE)
        self.assertIsNone(re.search(r"Paths\.clear(Stored|Unused)Memory\s*\(", source),
                          "menus drop cached assets on entry; here that would fake the numbers")

    def test_page_shows_the_snapshot_and_copies_the_same_text(self):
        source = read(STATE)
        self.assertIn("DiagnosticsReport.build()", source)
        self.assertIn("Clipboard.text = report", source,
                      "copy has to hand over exactly what the screenshot shows")
        self.assertIn("report = DiagnosticsReport.build()", source,
                      "one snapshot feeds both the page and the clipboard")
        self.assertEqual(len(re.findall(r"Clipboard\.text\s*=", source)), 1,
                         "the clipboard is written exactly once, with the report and nothing else")

    def test_page_is_scrollable_and_leaves_through_the_main_menu(self):
        source = read(STATE)
        self.assertIn("controls.UI_UP", source)
        self.assertIn("controls.UI_DOWN", source)
        self.assertIn("FlxG.mouse.wheel", source, "keyboard, touch and mouse all have to reach the footer")
        self.assertIn("addVirtualPad(UP_DOWN, A_B)", source, "a phone needs the same page")
        switches = re.findall(r"FlxG\.switchState\(([^)]*)\)", source)
        self.assertEqual(switches, ["MainMenuState.new"],
                         "the only navigation the page performs is going back to the menu")

    def test_extra_camera_is_cleaned_up(self):
        destroy = block(read(STATE), "override function destroy()")
        self.assertIn("FlxG.cameras.remove(reportCamera)", destroy,
                      "a leaked camera outlives the page that added it")


class DiagnosticsReportTests(unittest.TestCase):
    def test_report_only_reads(self):
        source = read(REPORT)
        for pattern in (r"ClientPrefs\.\w+\s*=[^=]", r"File\.(write|saveContent|append)",
                        r"FileSystem\.(createDirectory|deleteFile|rename)", r"Sys\.command",
                        r"FlxG\.save", r"switchState", r"Clipboard"):
            self.assertIsNone(re.search(pattern, source),
                              "the builder must stay reusable and inert: " + pattern)
        self.assertIn("File.getBytes(VLog.FILE)", source, "the log is read, never rewritten")
        self.assertIn("tail + '\\n' + VLog.exportText()", source,
                      "the unflushed tail is appended once, not re-read per row")

    def test_report_covers_what_a_bug_report_asks(self):
        source = read(REPORT)
        for field in ("Phoenix", "Commit", "Target", "Features", "CPU", "Total RAM", "GPU driver",
                      "Graphics", "Game size", "Framerate", "Heap", "Save data", "Session log",
                      "Enabled", "Resolution", "RECENT LOG"):
            self.assertIn(f"'{field}'", source, f"the report must name {field!r}")
        self.assertIn("Date.now().toString()", source, "a screenshot needs to say when it was taken")
        self.assertRegex(source, r"section\(out, '\[?[A-Z ]+\]?', \w+Section\)",
                         "each section goes through the guard, not straight into the text")

    def test_the_log_policy_is_reused_not_forked(self):
        source = read(REPORT)
        self.assertIn("LogUtils.MAX_LOG_FILE_BYTES", source,
                      "the size bound for opening a log is backend.LogUtils' policy, so it is read "
                      "from there instead of being a second number that can drift")
        self.assertNotIn("LOG_MAX_BYTES", source, "no private copy of the cap")
        self.assertNotIn("redact(", source,
                         "the tail is printed as VLog stored it; redacting again here would fork the policy")

    def test_log_tail_is_bounded(self):
        source = read(REPORT)
        self.assertRegex(source, r"LOG_TAIL_BYTES\s*:\s*Int\s*=\s*\d+ \* 1024")
        self.assertRegex(source, r"LOG_LINES\s*:\s*Int\s*=\s*\d+")
        self.assertIn("FileSystem.stat(VLog.FILE).size <= LogUtils.MAX_LOG_FILE_BYTES", source,
                      "a log capped at 10 MiB by rotation must not be slurped for a screenshot")
        self.assertRegex(source, r"slice\(\w+\.length - LOG_LINES\)",
                         "the tail has to be cut from the end, not re-read")

    def test_failures_degrade_into_rows(self):
        gather = block(read(REPORT), "static function section(")
        self.assertIn("try gather()", gather)
        self.assertIn("unavailable: ", gather,
                      "a broken data source must cost one row, not the whole page")

    def test_report_is_not_a_second_implementation_of_the_prefs_dump(self):
        report = read(REPORT)
        self.assertIn("backend.SettingsBackup", report,
                      "the full preference dump belongs to the settings export, not this page")


class DiagnosticsDocsTests(unittest.TestCase):
    def test_root_specification_documents_the_route(self):
        uri = read("URI.MD")
        self.assertIn("`phoenix://diagnostics`", uri)
        self.assertIn("read-only", uri.lower())
        self.assertIn("phoenix://diagnostics?copy=1", uri,
                      "the rejection rule is part of the contract support reads")
        self.assertIn("phoenix://screen/diagnostics", uri)
        self.assertNotRegex(uri, r"diagnostics\s*(route)?\s*is (not|deliberately)",
                            "the docs must not still describe the route as a stub")

    def test_site_docs_match_the_shipped_route(self):
        site = read("website/docs/subsystems/deep-links.md")
        self.assertIn("`phoenix://diagnostics`", site)
        self.assertIn("DiagnosticsState", site)
        self.assertIn("DiagnosticsReport", site)
        self.assertIn("read-only", site.lower())

    def test_roadmap_no_longer_lists_the_finished_work(self):
        todo = read("TODO.md")
        self.assertNotIn("Deep-linkable diagnostics", todo,
                         "TODO.md is the open backlog; finished entries get deleted")


class DiagnosticsSpecHarnessTests(unittest.TestCase):
    """The Haxe side of the coverage, so the report and the page are compiled and
    run instead of only pattern-matched. `tests/haxe/` is the repo's convention for
    specs that need no game haxelibs, and the diagnostics pair follows it."""

    SCRIPT = "tests/haxe/run-diagnostics-report.sh"
    WORKFLOW = ".github/workflows/checks.yml"

    def test_both_specs_exist_and_target_the_shipped_files(self):
        for spec, target in (("tests/haxe/DiagnosticsReportSpec.hx", "DiagnosticsReport"),
                             ("tests/haxe/DiagnosticsStateSpec.hx", "DiagnosticsState")):
            body = read(spec)
            self.assertIn(target, body, f"{spec} has to name what it tests")
            self.assertIn("passed", body, f"{spec} should print a verdict, not stay silent")

    def test_runner_isolates_the_specs_from_the_real_install(self):
        script = read(self.SCRIPT)
        for prod in ("source/backend/DiagnosticsReport.hx", "source/states/DiagnosticsState.hx"):
            self.assertIn(prod, script, "the specs have to compile the shipped file, not a copy of it")
        self.assertIn("mktemp -d", script)
        self.assertIn('cd "$test_source"', script,
                      "the report tails vlog/log.txt relative to the cwd, so it must not run in the repo")
        self.assertIn("--interp", script)
        self.assertIn("tests/haxe/stubs/diagnostics", script)

    def test_stubs_cover_everything_the_page_touches(self):
        stubs = sorted(p.relative_to(ROOT).as_posix() for p in (ROOT / "tests/haxe/stubs/diagnostics").rglob("*.hx"))
        for needed in ("tests/haxe/stubs/diagnostics/import.hx",
                       "tests/haxe/stubs/diagnostics/flixel/FlxG.hx",
                       "tests/haxe/stubs/diagnostics/flixel/text/FlxText.hx",
                       "tests/haxe/stubs/diagnostics/backend/MusicBeatState.hx",
                       "tests/haxe/stubs/diagnostics/lime/system/Clipboard.hx"):
            self.assertIn(needed, stubs)

    def test_ci_runs_the_haxe_specs_and_the_parser_spec(self):
        workflow = read(self.WORKFLOW)
        self.assertIn("tests/haxe/run-diagnostics-report.sh", workflow)
        self.assertIn("tests/uri/run.sh", workflow,
                      "the parser is the compatibility contract; it should not rely on a local run")


if __name__ == "__main__":
    unittest.main(verbosity=2)
