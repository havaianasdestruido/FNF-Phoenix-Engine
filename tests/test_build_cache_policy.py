"""Guard the safety boundaries of the native build cache and CI policy.

The caches must actually be reused: one rolling entry per target, saved with
the same key that was looked up, and never keyed on the source tree (which
would make every commit a new 140-370 MB snapshot and fill the 10 GB quota).
"""
from pathlib import Path
import re
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = (ROOT / ".github/workflows/main.yml").read_text(encoding="utf-8")


def step(name: str) -> str:
    match = re.search(
        rf"^      - name: {re.escape(name)}\n(.*?)(?=^      - (?:name:|uses:)|^      # =|\Z)",
        WORKFLOW,
        re.MULTILINE | re.DOTALL,
    )
    if match is None:
        raise AssertionError(f"missing workflow step: {name}")
    return match.group(1)


def field(block: str, name: str) -> str:
    match = re.search(rf"^          {re.escape(name)}: (.+)$", block, re.MULTILINE)
    if match is None:
        raise AssertionError(f"missing `{name}` in step:\n{block}")
    return match.group(1).strip()


def restore_prefix(block: str) -> str:
    """First restore-key, allowing the `|` block form used in the workflow."""
    match = re.search(r"^          restore-keys: \|\n            (.+)$", block, re.MULTILINE)
    if match is not None:
        return match.group(1).strip()
    return field(block, "restore-keys")


def condition(block: str) -> str:
    match = re.search(r"^        if: (.+)$", block, re.MULTILINE)
    if match is None:
        raise AssertionError(f"missing `if:` in step:\n{block}")
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
        self.assertEqual([], re.findall(r"^\s+path: (.+)$", restore, re.MULTILINE)[1:])
        self.assertEqual([], re.findall(r"^\s+path: (.+)$", save, re.MULTILINE)[1:])
        self.assertNotIn("build/release/", restore)
        self.assertNotIn("build/release/", save)
        self.assertEqual(field(restore, "path"), field(save, "path"))
        self.assertIn("env.HXCPP_COMPILE_CACHE", field(restore, "path"))
        self.assertIn("github.event_name != 'pull_request'", save)
        self.assertIn("steps.build-cache.outputs.cache-hit != 'true'", save)
        for name in ("Compile (Windows)", "Compile (Android)"):
            compile_step = step(name)
            self.assertNotRegex(compile_step, r"(?:rm\s+-rf|Remove-Item)[^\n]*HXCPP_COMPILE_CACHE")

    def test_save_reuses_the_exact_key_that_was_looked_up(self):
        # `cache-hit` is only true on an exact match, and a cache found through
        # a restore-key is a miss. Saving `cache-primary-key` blindly only
        # works if the actions/cache runtime reports the *lookup* key on a
        # miss; deriving the key from the same expressions makes it explicit.
        restore = step("Restore hxcpp object cache")
        save = step("Save hxcpp object cache")
        key = field(restore, "key")
        self.assertEqual(key, field(save, "key"))
        self.assertNotIn("cache-primary-key", save)
        self.assertNotIn("cache-primary-key", step("Save haxelib and hxcpp tools"))

    def test_keys_are_not_derived_from_the_source_tree(self):
        # One snapshot per commit is what piled the caches up. hxcpp already
        # hashes each translation unit's own inputs, so the batch key must not
        # follow the source. A day/run stamp has the same effect (a new key on
        # every run) and previously paired with "save only on a miss", so a
        # warm run could never refresh the entry it had restored.
        for name in ("Restore hxcpp object cache", "Save hxcpp object cache"):
            key = field(step(name), "key")
            self.assertNotIn("source/", key)
            self.assertNotIn("project.hxp", key)
            self.assertNotIn(".github/workflows", key)
            self.assertNotIn("hashFiles('source", key)
            self.assertNotIn("github.run_id", key)
            self.assertNotIn("GITHUB_RUN_ID", key)
        self.assertNotIn("outputs.day", WORKFLOW)
        self.assertNotIn("runner-image", WORKFLOW)
        self.assertIn(".hxcpp_cache/", (ROOT / ".gitignore").read_text(encoding="utf-8"))

    def test_no_restore_key_is_broader_than_the_object_cache_key(self):
        # A fallback that drops the pinned-dependency hash or the build flags
        # would reuse objects compiled by another hxcpp/toolchain or with other
        # -D defines. Cold beats wrong.
        restore = step("Restore hxcpp object cache")
        prefix = restore_prefix(restore)
        for token in ("hashFiles('hmm.json'", "inputs.buildFlags", "matrix.cache_name", "runner.os", "runner.arch"):
            self.assertIn(token, prefix)

    def test_haxelib_install_runs_whenever_the_exact_key_misses(self):
        # The haxelib fallback may restore an older snapshot with a different
        # dependency set, so every install step must still run unless the
        # exact content key hit (`cache-hit` is exact-match only).
        for name in ("Install haxelib dependencies (Android)", "Install haxelib dependencies (Windows)"):
            self.assertIn("steps.haxelib-cache.outputs.cache-hit != 'true'", condition(step(name)))

    def test_cache_key_isolates_toolchain_target_config_and_flags(self):
        restore = step("Restore hxcpp object cache")
        key = field(restore, "key")
        self.assertIn("env.CACHE_SCHEMA", key)
        for token in (
            "matrix.cache_name",
            "runner.os",
            "runner.arch",
            "env.HAXE_VERSION",
            "hmm.json",
            "setup/windows-msvc-fix.ps1",
            "inputs.buildFlags",
        ):
            self.assertIn(token, key)
        # An unset input must not alias an explicit flag of the same name.
        self.assertIn("format('explicit-{0}', inputs.buildFlags) || 'unset'", key)
        # The cache disk budget must be raised, or hxcpp evicts objects
        # mid-build and the entry that gets saved is already gutted.
        self.assertIn('HXCPP_CACHE_MB: "2048"', WORKFLOW)

    def test_haxelib_cache_hits_on_an_exact_key(self):
        # The key must be fully content-derived: a key that also changes with
        # every commit (or that is never an exact match) makes `cache-hit`
        # false forever, and its save step then uploads a fresh 1.6 GB copy
        # on every single run.
        restore = step("Restore haxelib and hxcpp tools")
        save = step("Save haxelib and hxcpp tools")
        key = field(restore, "key")
        self.assertEqual(key, field(save, "key"))
        self.assertTrue(key.startswith("${{ env.CACHE_SCHEMA }}-haxelib-"))
        self.assertIn("hashFiles(", key)
        self.assertIn("env.CACHE_SCHEMA", key)
        self.assertIn("matrix.setup", key)
        self.assertIn("env.HAXE_VERSION", key)
        self.assertIn("hashFiles('hmm.json'", key)
        self.assertIn("github.event_name != 'pull_request'", save)

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

    def test_every_reusable_build_writes_the_shared_caches(self):
        # workflow_call runs (manual/mobile releases, release assets) report
        # event_name == 'workflow_call', so they must be able to write too;
        # only pull_request is read-only.
        for name in ("Save haxelib and hxcpp tools", "Save hxcpp object cache"):
            guard = condition(step(name))
            self.assertIn("github.event_name != 'pull_request'", guard)
            self.assertNotIn("event_name == 'push'", guard)
            self.assertNotIn("event_name == 'workflow_dispatch'", guard)


if __name__ == "__main__":
    unittest.main(verbosity=2)
