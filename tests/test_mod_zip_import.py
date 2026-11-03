#!/usr/bin/env python3
"""Guards for installing a mod from a `.zip` (TODO.md §11 FILES / MODS).

The importer itself is exercised end-to-end by `tests/haxe/ModZipImportSpec.hx`
when a Haxe binary is available. These checks are the no-toolchain layer: they
pin the wiring (SAF picker -> importer -> `modsList.txt` -> menu reload) and the
security rules that make a user-supplied archive safe to unpack into `mods/`.

Invariants:

* the SAF picker is asked for `.zip` files and the mods menu exposes the
  "Import mod" action (the only install path on a phone without a file manager);
* archive entries are validated against `backend.ModPathPolicy` (absolute,
  `..`, control characters, Windows device names) before extraction;
* `pack.json` is validated while the mod is still in a staging folder, and the
  staging folder is swapped into `mods/<folder>/` only afterwards;
* the freshly installed folder is enabled in `modsList.txt` and the list is
  reloaded, and engine staging folders are never listed as mods.

Run:  python3 -m unittest discover -s tests -p 'test_*.py' -v
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


class TestPickerWiring(unittest.TestCase):
    def test_saf_picker_is_asked_for_zip_files(self):
        state = read("source/states/ModsMenuState.hx")
        self.assertIn("MobileFilePicker.openFile(function(file) {", state)
        self.assertRegex(state, r"\[\s*'zip'\s*\]", "the picker must filter for .zip")
        self.assertIn("Select a mod .zip", state)

    def test_mime_table_still_knows_zip(self):
        storage = read("source/android/platform/AndroidStorage.hx")
        self.assertIn("case 'zip': 'application/zip';", storage)
        # The picker maps extensions to MIME types; without this mapping the
        # SAF dialog would not filter mod archives.
        self.assertIn("extensionToMime", storage)

    def test_mods_menu_offers_the_import_button(self):
        state = read("source/states/ModsMenuState.hx")
        self.assertIn("var buttonImport:MenuButton;", state)
        self.assertIn("buttonImport = new MenuButton(", state)
        self.assertIn("importModFromZip", state)
        # Both the populated list and the "no mods installed" screen can import.
        self.assertGreaterEqual(state.count("buttonImport = new MenuButton("), 2)
        self.assertIn("IMPORT A MOD .ZIP", state)

    def test_import_runs_off_the_archive_bytes(self):
        state = read("source/states/ModsMenuState.hx")
        self.assertIn("ModZipInstaller.inspect(data, displayName, Paths.mods())", state)
        self.assertIn("ModZipInstaller.importZip(data, displayName, Paths.mods(), null, validateModPack, replaceExisting)", state)
        self.assertIn("function validateModPack(text:String):Bool", state)
        self.assertIn("tjson.TJSON.parse(text)", state)


class TestArchiveSafety(unittest.TestCase):
    def setUp(self):
        self.policy = read("source/backend/ModPathPolicy.hx")
        self.installer = read("source/mobile/files/ModZipInstaller.hx")

    def test_absolute_and_traversal_paths_are_rejected(self):
        # normalizeRelative() is the single gate for zip entries.
        self.assertIn("if(value.startsWith('/')) return null;", self.policy)
        self.assertIn("if(part == '..') return null;", self.policy)
        self.assertIn("value.charAt(1) == ':'", self.policy, "windows drive paths must be rejected")
        self.assertIn("if(!isSafeSegment(part)) return null;", self.policy)
        self.assertIn("MAX_PATH_DEPTH", self.policy)
        self.assertIn("MAX_PATH_LENGTH", self.policy)

    def test_zip_entries_go_through_the_shared_policy(self):
        self.assertIn("ModPathPolicy.normalizeRelative(rawName)", self.installer)
        self.assertIn("ModPathPolicy.resolveInside(staging, entry.path)", self.installer)
        self.assertIn("Unsafe path in archive", self.installer)

    def test_central_directory_is_authoritative(self):
        self.assertIn("ZIP_CENTRAL_HEADER", self.installer)
        self.assertIn("readUInt32LE(data, offset + 42)", self.installer, "local header offset comes from the CD")
        self.assertIn("does not match its local header", self.installer)
        self.assertIn("haxe.zip.InflateImpl", self.installer)

    def test_zip_bomb_limits_exist(self):
        for limit in ("MAX_ARCHIVE_BYTES", "MAX_ENTRY_BYTES", "MAX_EXPANDED_BYTES", "MAX_ENTRY_COUNT"):
            self.assertIn(limit, self.installer)
        self.assertIn("if(written > MAX_ENTRY_BYTES)", self.installer)

    def test_encrypted_and_symlink_entries_are_rejected(self):
        self.assertIn("UNIX_SYMBOLIC_LINK", self.installer)
        self.assertIn("encrypted mods are not supported", self.installer)
        self.assertIn("Unsupported compression method", self.installer)

    def test_pack_json_is_validated_before_the_swap(self):
        validate_at = self.installer.index("validatePack(packText, packValidator)")
        rename_at = self.installer.index("FileSystem.rename(staging, target)")
        self.assertLess(validate_at, rename_at, "pack.json must be checked while still staged")
        self.assertIn("The archive has no pack.json at its root", self.installer)
        self.assertIn("not a valid JSON object", self.installer)

    def test_failed_imports_clean_up_their_staging_folder(self):
        self.assertIn("STAGING_PREFIX", self.installer)
        self.assertIn(".phoenix-import-", self.installer)
        self.assertIn("if(staging.length > 0)", self.installer)
        self.assertIn("deleteDirectory(staging);", self.installer)
        # A failed cleanup must never mask the original import error.
        self.assertIn("catch(cleanupError:Dynamic) {}", self.installer)

    def test_menu_buttons_match_the_constructor_signature(self):
        """`MenuButton.new(x, y, w, h, ?text, ?img, onClick, animW, animH)`.

        Haxe accepts a non-unifying value in an optional slot at a call site,
        so a callback passed one position early compiles and then silently
        binds to `img` - the button never fires.
        """
        state = read("source/states/ModsMenuState.hx")
        for label in ("RELOAD", "ENABLE ALL", "DISABLE ALL"):
            self.assertIn('"%s", null,' % label, state, "text button must skip the image slot")
        self.assertNotIn("80, Paths.image(", state, "icon button must pass null for the text slot")
        self.assertIn("80, null, Paths.image(", state)
        self.assertIn('"RELOAD", null, reload', state)

    def test_import_failures_are_shown_inside_the_menu(self):
        state = read("source/states/ModsMenuState.hx")
        flow = state[state.index("public function importModFromZip"):state.index("function showInstallStatus")]

        # Native alerts degrade to a trace on some targets, so the flow must
        # report through the in-state label instead.
        self.assertIn("showInstallError(", flow)
        self.assertNotIn("showPopUp", flow)
        self.assertIn("function showInstallError(", state)
        self.assertIn("#if !android", state[state.index("function showInstallError("):])

    def test_replacing_an_existing_mod_is_opt_in(self):
        self.assertIn("replaceExisting", self.installer)
        self.assertIn("already installed", self.installer)
        state = read("source/states/ModsMenuState.hx")
        self.assertIn("inspection.conflicts", state)
        self.assertIn("new Prompt(", state)


class TestModsListIntegration(unittest.TestCase):
    def setUp(self):
        self.mods = read("source/backend/Mods.hx")
        self.stub = read("source/backend/ModsStub.hx")

    def test_installed_mod_is_enabled_in_mods_list(self):
        self.assertIn("public static function registerInstalledMod(", self.mods)
        self.assertIn("File.saveContent('modsList.txt'", self.mods)
        self.assertIn("updatedOnState = false;", self.mods)
        self.assertIn("registerInstalledMod(folder:String, enabled:Bool = true):Bool", self.stub)

    def test_state_enables_then_reloads(self):
        state = read("source/states/ModsMenuState.hx")
        register_at = state.index("Mods.registerInstalledMod(result.folder)")
        reload_at = state.index("reload(result.folder)")
        self.assertLess(register_at, reload_at, "enable the mod before rebuilding the list")
        self.assertIn("modsList.all.push(result.folder)", state)

    def test_staging_folders_are_never_listed_as_mods(self):
        self.assertIn("if (folder.startsWith('.')) continue;", self.mods)
        self.assertIn("ModPathPolicy.RESERVED_MOD_FOLDERS.copy()", self.mods)

    def test_reload_can_select_the_new_mod(self):
        helpers = read("source/states/helpers/ModsMenuHelpers.hx")
        self.assertIn("public static function reload(state:ModsMenuState, ?selectMod:String = null)", helpers)
        self.assertIn("selectMod != null ? selectMod :", helpers)
        self.assertIn("case -3: return state.buttonImport;", helpers)


class TestDocsAndRoadmap(unittest.TestCase):
    def test_roadmap_entry_is_gone(self):
        todo = read("TODO.md")
        self.assertNotIn("Install a mod from a `.zip`", todo)
        self.assertNotIn("nothing extracts it", todo)

    def test_changelog_and_platform_docs_describe_the_import(self):
        changelog = read("THECHANGELOG.md")
        self.assertRegex(changelog, r"(?i)\.zip")
        docs = read("docs/ANDROID_PLATFORM.md")
        self.assertIn("ModZipInstaller", docs)
        self.assertIn("IMPORT", docs.upper())
        self.assertIn("ModPathPolicy", docs)


class TestInterpreterSpec(unittest.TestCase):
    """Runs the real policy/parser/extractor when a Haxe binary is available."""

    def test_spec_passes_in_the_interpreter(self):
        haxe = os.environ.get("HAXE") or shutil.which("haxe")
        if not haxe:
            self.skipTest("no haxe binary on PATH (set HAXE to run the interpreter spec)")
        env = dict(os.environ)
        env["HAXE"] = haxe
        proc = subprocess.run(
            ["bash", "tests/haxe/run-mod-zip.sh"],
            cwd=ROOT,
            env=env,
            capture_output=True,
            text=True,
        )
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        self.assertIn("ModZipImportSpec: all checks passed", proc.stdout + proc.stderr)

    def test_runner_spec_and_ci_step_exist(self):
        self.assertTrue((ROOT / "tests/haxe/run-mod-zip.sh").exists())
        self.assertTrue((ROOT / "tests/haxe/ModZipImportSpec.hx").exists())
        self.assertIn("tests/haxe/run-mod-zip.sh", read(".github/workflows/checks.yml"))

    def test_spec_sources_stay_dependency_free(self):
        for path in ("source/backend/ModPathPolicy.hx", "source/mobile/files/ModZipInstaller.hx"):
            text = read(path)
            for forbidden in ("flixel.", "openfl.", "lime.", "import play.", "import objects.", "import states."):
                self.assertNotIn(forbidden, text, f"{path} must stay runnable with haxe --interp")


if __name__ == "__main__":
    unittest.main()
