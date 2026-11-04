"""Regression tests for Phoenix release validation and workflows."""
import importlib.util
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('release_notes', ROOT / 'tools/release_version.py')
notes = importlib.util.module_from_spec(spec)
spec.loader.exec_module(notes)


class ReleaseNotesTests(unittest.TestCase):
    def test_normalization_and_invalid_tags(self):
        self.assertEqual(notes.normalize_version('v0.0.1-pre1'), '0.0.1-pre.1')
        self.assertEqual(notes.normalize_version('V0.0.1-RC-2'), '0.0.1-rc.2')
        for tag in ('fix-ci', 'v01.0.1', '0.0.1+build', '1.2'):
            with self.subTest(tag=tag), self.assertRaises(ValueError):
                notes.normalize_version(tag)

    def test_version_validation_does_not_require_changelog(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / 'project.hxp').write_text('static final VERSION:String = "0.0.2-pre1";')
            self.assertEqual(notes.validate(root, 'v0.0.2-pre1'), '0.0.2-pre.1')
            with self.assertRaises(ValueError):
                notes.validate(root, 'v0.0.1')

    def test_preference_and_cache_are_wired(self):
        prefs = (ROOT / 'source/backend/ClientPrefs.hx').read_text()
        menu = (ROOT / 'source/options/MiscSettingsSubState.hx').read_text(encoding='utf-8-sig')
        checker = (ROOT / 'source/backend/UpdateChecker.hx').read_text()
        self.assertIn('enablePreReleaseUpdates:Bool = false', prefs)
        self.assertIn('Enable pre-release updates', menu)
        self.assertIn("'enablePreReleaseUpdates'", menu)
        self.assertIn('lastIncludePrereleases == ClientPrefs.enablePreReleaseUpdates', checker)
        self.assertIn('PhoenixVersion.current, lastIncludePrereleases', checker)

    def test_workflows_select_and_validate_explicit_tag(self):
        mobile = (ROOT / '.github/workflows/mobile-release.yml').read_text()
        release = (ROOT / '.github/workflows/release.yml').read_text()
        self.assertNotIn('/releases/latest', mobile)
        self.assertIn('tools/release_version.py', mobile)
        self.assertIn('tools/release_version.py', release)
        self.assertIn('--draft', release)
        self.assertIn('--generate-notes', release)
        self.assertNotIn('THECHANGELOG.md', release + mobile)
        self.assertNotIn('generate_release_notes:', release)

    def test_release_assets_attach_on_published_release(self):
        assets = (ROOT / '.github/workflows/release-assets.yml').read_text()
        self.assertIn('types: [published]', assets)
        self.assertIn('uses: ./.github/workflows/main.yml', assets)
        self.assertIn('buildFlags: officialBuild', assets)
        self.assertIn('tools/release_version.py', assets)
        self.assertIn('FNF-Phoenix-Engine-windows.zip', assets)
        self.assertIn('FNF-Phoenix-Engine-android.apk', assets)
        self.assertIn('gh release upload', assets)
        self.assertIn('contents: write', assets)
        self.assertNotIn('/releases/latest', assets)
        self.assertNotIn('THECHANGELOG.md', assets)

if __name__ == '__main__':
    unittest.main()
