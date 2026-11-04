"""Guard the safety boundaries of the native build cache and CI policy."""
from pathlib import Path
import re
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = (ROOT / ".github/workflows/main.yml").read_text(encoding="utf-8")


def step(name: str) -> str:
    match = re.search(
        rf"^      - name: {re.escape(name)}\n(.*?)(?=^      - (?:name:|uses:)|\Z)",
        WORKFLOW,
        re.MULTILINE | re.DOTALL,
    )
    if match is None:
        raise AssertionError(f"missing workflow step: {name}")
    return match.group(1)


class NativeCachePolicyTests(unittest.TestCase):
    def test_all_engine_native_headers_are_declared_as_dependencies(self):
        headers = set((ROOT / "source").rglob("*.h")) | set((ROOT / "source").rglob("*.hpp"))
        declared = set()
        for xml in (ROOT / "source").rglob("*build.xml"):
            tree = ET.parse(xml)
            for group in tree.findall(".//files[@id='haxe']"):
                for dependency in group.findall("depend"):
                    name = dependency.attrib.get("name", "")
                    if "/include/" not in name:
                        continue
                    # Each build.xml resolves its ${..._DIR} to its own directory.
                    header = xml.parent / "include" / name.rsplit("/", 1)[-1]
                    self.assertTrue(header.is_file(), f"{xml}: missing {header}")
                    self.assertNotEqual(dependency.attrib.get("dateOnly"), "true")
                    declared.add(header)
        self.assertTrue(headers, "expected native engine headers")
        self.assertEqual(headers, declared)

    def test_only_hxcpp_objects_are_restored_and_saved(self):
        restore = step("Restore hxcpp object cache")
        save = step("Save hxcpp object cache")
        self.assertIn("uses: actions/cache/restore@v4", restore)
        self.assertIn("uses: actions/cache/save@v4", save)
        self.assertEqual(["${{ env.HXCPP_COMPILE_CACHE }}"], re.findall(r"^\s+path: (.+)$", restore, re.MULTILINE))
        self.assertEqual(["${{ env.HXCPP_COMPILE_CACHE }}"], re.findall(r"^\s+path: (.+)$", save, re.MULTILINE))
        self.assertIn("github.event_name != 'pull_request'", save)
        self.assertIn("steps.build-cache.outputs.cache-hit != 'true'", save)
        self.assertIn("steps.build-cache.outputs.cache-primary-key", save)
        for name in ("Compile (Windows)", "Compile (Android)"):
            compile_step = step(name)
            self.assertNotRegex(compile_step, r"(?:rm\s+-rf|Remove-Item)[^\n]*HXCPP_COMPILE_CACHE")

    def test_restore_prefix_keeps_toolchain_target_config_and_flags_isolated(self):
        restore = step("Restore hxcpp object cache")
        key = re.search(r"^\s+key: (.+)$", restore, re.MULTILINE).group(1)
        prefix = re.search(r"^\s+restore-keys: \|\n\s+(.+)$", restore, re.MULTILINE).group(1)
        self.assertEqual(key, prefix + "${{ steps.runner-image.outputs.day }}")
        for token in (
            "runner.os", "runner.arch", "matrix.cache_name", "steps.runner-image.outputs.id",
            "env.HAXE_VERSION", "hmm.json", "project.hxp", "setup/windows-msvc-fix.ps1",
            ".github/workflows/main.yml", "inputs.buildFlags",
        ):
            self.assertIn(token, prefix)
        # An unset input must not alias an explicit flag of the same name.
        self.assertIn("format('explicit-{0}', inputs.buildFlags) || 'unset'", prefix)
        image = step("Identify runner image")
        self.assertIn("${ImageVersion:-run-${GITHUB_RUN_ID}}", image)
        self.assertIn("date -u +%F", image)
        self.assertIn(".hxcpp_cache/", (ROOT / ".gitignore").read_text(encoding="utf-8"))

    def test_gradle_dependencies_are_cached_and_official_windows_keeps_ltcg(self):
        java = step("Setup Java 17")
        self.assertIn("cache: gradle", java)
        self.assertIn("source/android/media3/build.gradle", java)
        self.assertIn("hmm.json", java)
        windows = step("Compile (Windows)")
        self.assertRegex(windows, r"if \(\$buildFlag -eq 'officialBuild'\)\s*\{\s*\$buildArgs \+= '-DHXCPP_OPTIMIZE_LINK'")
        self.assertIn("$LASTEXITCODE", windows)
        self.assertNotIn("HXCPP_OPTIMIZE_LINK", step("Compile (Android)"))
        # Packaging checks and release artifact destinations must not disappear.
        self.assertIn("build/release/windows/bin", WORKFLOW)
        self.assertIn("build/release/android/bin/app/build/outputs/apk/debug", WORKFLOW)
        step("Verify Android Media3/SAF manifest and SDK levels")
        step("Verify Android APK native libs")


if __name__ == "__main__":
    unittest.main(verbosity=2)
