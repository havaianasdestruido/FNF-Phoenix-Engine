#!/usr/bin/env python3
"""Static regression tests for the "Export/Import Settings (.json)" options.

Every settings list (Gameplay, Graphics, Visuals & UI, Optimization, Game
Rendering, Misc and Mobile Options) ends with the same two backup actions.
These guards pin the boundaries that make the feature safe:

* every `BaseOptionsMenu` settings list really appends them,
* the menus never touch Lime/Android file dialogs directly (that is the
  cross-platform `MobileFilePicker`'s job),
* import only writes names that already exist in `ClientPrefs` and always
  saves afterwards,
* the codec stays Flixel-free so `tests/haxe/run-settings-backup.sh` can run
  it in the Haxe interpreter.

No Haxe toolchain needed (same style as test_widescreen.py / test_vlog.py).

Run:  python3 -m unittest discover -s tests -p 'test_*.py' -v
  or: python3 tests/test_settings_backup.py
"""
from __future__ import annotations

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

BASE_MENU = "source/options/BaseOptionsMenu.hx"
GLUE = "source/backend/SettingsBackup.hx"
CODEC = "source/backend/SettingsBackupCodec.hx"
SPEC_RUNNER = "tests/haxe/run-settings-backup.sh"

# Settings lists built on BaseOptionsMenu (the option-list menus of the
# Options screen). Custom editors (Controls, Note Colors, ...) keep their own UI.
SETTINGS_LISTS = [
    "source/options/GameplaySettingsSubState.hx",
    "source/options/GraphicsSettingsSubState.hx",
    "source/options/OptimizationSubState.hx",
    "source/options/GameRendererSettingsSubState.hx",
    "source/options/VisualsUISubState.hx",
    "source/options/MiscSettingsSubState.hx",
    "source/mobile/options/MobileOptionsSubState.hx",
]


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


class SettingsBackupListViewTests(unittest.TestCase):
    def test_every_settings_list_ends_with_the_backup_options(self):
        for path in SETTINGS_LISTS:
            source = read(path)
            self.assertIn("addBackupOptions();", source, f"{path} does not offer the backup options")
            # They belong at the end of the list: added right before super(),
            # which is what builds the rows.
            self.assertLess(
                source.index("addBackupOptions();"),
                source.rindex("super();"),
                f"{path} adds the backup options after the list was built",
            )

    def test_base_menu_offers_one_export_and_one_import_action(self):
        base = read(BASE_MENU)
        self.assertIn("public function addBackupOptions():Void", base)
        self.assertIn("'Export Settings (.json)'", base)
        self.assertIn("'Import Settings (.json)'", base)
        # `link` options run an action instead of editing a ClientPrefs value.
        self.assertEqual(base.count("'link',"), 2, "both backup entries must be action-only options")
        for handler in ("option.onChange = exportBackup;", "option.onChange = askImportBackup;"):
            self.assertIn(handler, base)

    def test_import_asks_before_overwriting_everything(self):
        ask = body(read(BASE_MENU), "function askImportBackup():Void")
        self.assertIn("new Prompt(", ask)
        self.assertIn("Continue?", ask)
        self.assertLess(ask.index("new Prompt("), ask.index("SettingsBackup.importFromFile("))
        self.assertIn("regenList();", ask, "the menu must show the imported values")

    def test_only_one_dialog_can_be_open_at_a_time(self):
        glue = read(GLUE)
        self.assertIn("public static var busy(default, null):Bool = false;", glue)
        for entry in ("exportToFile", "importFromFile"):
            fn = body(glue, f"public static function {entry}(")
            self.assertIn("if (busy) return;", fn, f"{entry} must not stack dialogs")
            self.assertIn("busy = true;", fn)
            self.assertIn("busy = false;", fn)


class SettingsBackupPlumbingTests(unittest.TestCase):
    def test_dialogs_go_through_the_cross_platform_picker(self):
        glue = read(GLUE)
        self.assertIn("import mobile.files.MobileFilePicker;", glue)
        self.assertIn("MobileFilePicker.saveText(", glue)
        self.assertIn("MobileFilePicker.openFile(", glue)
        self.assertIn("SettingsBackupCodec.encode(", glue)
        self.assertIn("importFromJson(", glue)
        # Pickers belong to MobileFilePicker, which owns the Lime/SAF details.
        self.assertNotIn("lime.ui.FileDialog", glue)
        self.assertNotIn("AndroidStorage.", glue)

    def test_import_is_whitelisted_and_saved(self):
        glue = read(GLUE)
        for name in ("'keyBinds'", "'defaultKeys'", "'gameplaySettings'"):
            self.assertIn(name, glue, f"{name} must not be written as a raw preference")
        self.assertIn("public static function isPreference(", glue)
        self.assertIn("Type.getClassFields(ClientPrefs)", glue)

        apply_settings = body(glue, "static function applySettings(")
        self.assertIn("if (!isPreference(field)) continue;", apply_settings)
        self.assertIn("SettingsBackupCodec.coerce(", apply_settings)
        self.assertIn("Reflect.setField(ClientPrefs, field, value);", apply_settings)

        import_json = body(glue, "public static function importFromJson(")
        self.assertIn("ClientPrefs.saveSettings();", import_json)
        self.assertIn("applyImmediately();", import_json)
        # Keybinds are applied through the map and re-bound live.
        self.assertIn("ClientPrefs.keyBinds.set(control, rebuilt);", glue)
        self.assertIn("ClientPrefs.reloadControls();", glue)

    def test_export_covers_every_preference(self):
        collect = body(read(GLUE), "public static function collect(")
        self.assertIn("preferenceFields()", collect)
        self.assertIn("ClientPrefs.gameplaySettings.keys()", collect)
        self.assertIn("ClientPrefs.keyBinds", collect)
        self.assertIn("FlxG.sound.volume", collect)
        self.assertIn("FlxG.sound.muted", collect)

    def test_import_reports_errors_instead_of_throwing(self):
        glue = read(GLUE)
        self.assertIn("if (decoded.error != null) return 'Could not import settings.\\n\\n' + decoded.error;", glue)
        # A canceled picker must stay silent: null means "nothing to say".
        self.assertIn("if (message == null || message.length == 0) return;", read(BASE_MENU))


class SettingsBackupFormatTests(unittest.TestCase):
    def test_codec_has_no_engine_dependencies(self):
        # Doc comments may name the engine types; the code must not use them.
        code = "\n".join(
            line for line in read(CODEC).splitlines()
            if not line.strip().startswith(("*", "/*", "//"))
        )
        for forbidden in ("flixel", "FlxG", "ClientPrefs", "openfl", "lime", "MobileFilePicker"):
            self.assertNotIn(forbidden, code, f"the codec must stay dependency-free ({forbidden})")

    def test_format_is_marked_and_versioned(self):
        codec = read(CODEC)
        self.assertIn("public static inline var FORMAT_ID:String = 'phoenix-settings-backup';", codec)
        self.assertIn("public static inline var FORMAT_VERSION:Int = 1;", codec)
        decode = body(codec, "public static function decode(")
        self.assertIn("if (!Std.isOfType(format, String) || format != FORMAT_ID)", decode,
                      "foreign JSON (chart.json, ...) must be refused")
        self.assertIn("if (result.formatVersion > FORMAT_VERSION)", decode)

    def test_imported_values_are_type_checked(self):
        codec = read(CODEC)
        coerce = body(codec, "public static function coerce(")
        for kind in ("Bool", "Int", "Float", "String", "Array"):
            self.assertIn(f"Std.isOfType(reference, {kind})", coerce)
        self.assertIn("public static function coerceArray(", codec)
        self.assertIn("return null;", coerce, "unknown types must be rejected, not copied")

    def test_haxe_spec_runner_is_available(self):
        self.assertTrue((ROOT / SPEC_RUNNER).is_file(), "missing the Haxe interpreter spec runner")
        self.assertTrue((ROOT / "tests/haxe/SettingsBackupCodecSpec.hx").is_file(), "missing the codec spec")


if __name__ == "__main__":
    unittest.main()
