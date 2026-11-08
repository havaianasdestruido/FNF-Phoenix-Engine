"""Regression checks for the distant-note opt-in and the compact overlay."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


class DistantNotesTest(unittest.TestCase):
    def test_shader_projection_and_downscroll(self):
        shader = read('source/shaders/DistantNoteShader.hx')
        self.assertIn('uDownscroll ? 1.0 - uv.y : uv.y', shader)
        self.assertIn('actualY -= 0.42;', shader)
        self.assertIn('(actualY / 0.8) * (openfl_TextureCoordv.x - 0.5)', shader)
        self.assertIn('uDownscroll.value = [downscroll]', shader)
        self.assertIn('gl_FragColor = vec4(0.0)', shader)

    def test_effect_is_optional_and_does_not_modify_preference(self):
        prefs = read('source/backend/ClientPrefs.hx')
        state = read('source/play/PlayState.hx')
        options = read('source/options/VisualsUISubState.hx')
        self.assertIn('distantNotes:Bool = false', prefs)
        self.assertIn('ClientPrefs.distantNotes && ClientPrefs.shaders', state)
        self.assertIn('ClientPrefs.middleScroll || bothSides || useDistantNotes', state)
        self.assertNotIn('ClientPrefs.middleScroll =', state)
        self.assertIn("'distantNotes', 'bool', false", options)
        self.assertIn('#if (SHADERS_ALLOWED && !flash && !neko)', options)
        self.assertIn('new shaders.DistantNoteShader(ClientPrefs.downScroll)', state)
        self.assertIn('shaders.ShaderWarmup.track(distantShader)', state)

    def test_only_note_groups_use_the_effect_camera(self):
        state = read('source/play/PlayState.hx')
        for group in ('strumLineNotes', 'grpNoteSplashes', 'grpHoldSplashes', 'sustainNotes', 'notes'):
            self.assertIn(f'{group}.cameras = [noteCamera];', state)
        self.assertIn('healthBar.cameras = [camHUD];', state)
        self.assertIn('camNotes.visible = camHUD.visible;', state)
        self.assertIn('camNotes.alpha = camHUD.alpha;', state)
        self.assertIn('PlayState.middleScroll ? ClientPrefs.oppNoteAlpha', read('source/objects/Note.hx'))

    def test_overlay_defaults_and_optional_diagnostics(self):
        prefs = read('source/backend/ClientPrefs.hx')
        counter = read('source/debug/FPSCounter.hx')
        self.assertIn('showFPS:Bool = true', prefs)
        self.assertIn('showRamUsage:Bool = true', prefs)
        self.assertIn('legacyFPSUI:Bool = false', prefs)
        self.assertIn('showMaxRamUsage:Bool = true', prefs)
        self.assertIn('text = "FPS: "', counter)
        self.assertIn('\"\\nRAM: \"', counter)
        self.assertIn('if (!ClientPrefs.legacyFPSUI) return;', counter)
        self.assertIn('if (ClientPrefs.frameProfiler || ClientPrefs.debugInfo)', counter)
        self.assertIn('if (ClientPrefs.legacyFPSUI && ClientPrefs.ffmpegMode)', counter)
        self.assertIn("'legacyFPSUI', 'bool', false", read('source/options/VisualsUISubState.hx'))


if __name__ == '__main__':
    unittest.main()
