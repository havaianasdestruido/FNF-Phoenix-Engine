"""Guards for data/states HScript loading (CNE-style scripted states/substates)."""
from __future__ import annotations

from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8-sig")


class ScriptedStates(unittest.TestCase):
    def test_loader_and_hosts_exist(self):
        for rel in (
            "source/psychlua/StateScripts.hx",
            "source/psychlua/HaxeScript.hx",
            "source/states/ModState.hx",
            "source/states/substates/ModSubState.hx",
            "docs/TemplateState.hx",
            "website/docs/modding/scripted-states.md",
        ):
            with self.subTest(rel=rel):
                self.assertTrue((ROOT / rel).is_file(), rel)

    def test_state_scripts_resolves_data_states_and_sanitizes_names(self):
        source = read("source/psychlua/StateScripts.hx")
        self.assertIn("data/states/", source)
        self.assertIn("SCRIPT_EXTENSIONS", source)
        self.assertIn("'hx'", source)
        self.assertIn("'hscript'", source)
        self.assertIn("'hxs'", source)
        self.assertIn("public static function sanitizeName", source)
        self.assertIn("if (piece == '..') return ''", source)
        self.assertIn("if (cleaned.indexOf(':') >= 0) return ''", source)
        self.assertIn("ModSecurity.checkScript", read("source/psychlua/HaxeScript.hx"))

    def test_music_beat_state_and_substate_load_scripts(self):
        state = read("source/backend/MusicBeatState.hx")
        sub = read("source/backend/MusicBeatSubstate.hx")
        for source in (state, sub):
            self.assertIn("loadStateScripts()", source)
            self.assertIn("callStateScript('onCreate'", source)
            self.assertIn("callStateScript('onUpdate'", source)
            self.assertIn("callStateScript('onDestroy'", source)
            self.assertIn("callStateScript('onBeatHit'", source)
            self.assertIn("StateScripts.loadFor(this, scriptName)", source)
        self.assertIn("callStateScript('onSectionHit'", state)
        self.assertIn("Function_Stop", sub)
        self.assertIn("override function close()", sub)

    def test_custom_substate_is_no_longer_playstate_only(self):
        custom = read("source/psychlua/CustomSubstate.hx")
        self.assertIn("this.scriptName = name", custom)
        self.assertIn("FlxG.state.openSubState(new CustomSubstate(name))", custom)
        self.assertNotIn("PlayState.instance.openSubState(new CustomSubstate(name))", custom)
        self.assertIn("instance.close()", custom)
        self.assertIn("switchCustomState", custom)
        self.assertIn("openModSubState", custom)
        self.assertIn("customStateExists", custom)
        self.assertIn("if (PlayState.instance != null)", custom)

    def test_mod_state_hosts_use_script_name(self):
        mod_state = read("source/states/ModState.hx")
        mod_sub = read("source/states/substates/ModSubState.hx")
        self.assertIn("class ModState extends MusicBeatState", mod_state)
        self.assertIn("this.scriptName = lastName", mod_state)
        self.assertIn("class ModSubState extends MusicBeatSubstate", mod_sub)
        self.assertIn("this.scriptName = lastName", mod_sub)

    def test_standalone_hscript_does_not_require_lua_parent(self):
        haxe = read("source/psychlua/HaxeScript.hx")
        self.assertIn("class HaxeScript", haxe)
        self.assertNotIn("parentLua", haxe)
        self.assertIn("public function new(scriptName:String, ?parent:Dynamic, ?scriptCode:String)", haxe)
        self.assertIn("interp.scriptObject = parent", haxe)

    def test_docs_and_todo_record_the_loader(self):
        todo = read("TODO.md")
        self.assertNotIn(
            "No `data/states/StateName.hx` loader exists",
            todo,
        )
        self.assertIn("data/states/<Name>.hx", todo)
        docs = read("website/docs/modding/scripted-states.md")
        self.assertIn("switchCustomState", docs)
        self.assertIn("ModState", docs)
        folder = read("website/docs/modding/mod-folder-structure.md")
        self.assertIn("data/states/", folder)


if __name__ == "__main__":
    unittest.main()
