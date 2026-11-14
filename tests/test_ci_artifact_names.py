"""Guard CI artifact naming and the release workflows that consume it.

Artifact names end with the script backends the binary really contains, so a
build that can run Lua/Python mods is tellable apart from one that cannot
before anything is downloaded:

    <commit>_<target>_<HH>_<MM>_LUA_PYTHON_HSCRIPT   MODDING_LEVEL=2, desktop
    <commit>_<target>_<HH>_<MM>_LUA_HSCRIPT          MODDING_LEVEL=1
    <commit>_<target>_<HH>_<MM>_HSCRIPT              MODDING_LEVEL=0 or mobile
    <commit>_<target>_<HH>_<MM>_NONE                 no script support at all

The tokens come from `.github/workflows/main.yml`'s "Resolve script modding
level" step, which is also where the level is clamped for targets that cannot
compile the Lua bindings (mobile). These tests run that step and the "Name
artifact" step for real, with the `${{ ... }}` expressions substituted, so the
naming cannot drift away from the flags the build passes.

    python3 tests/test_ci_artifact_names.py
"""

import os
import pathlib
import re
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
WORKFLOWS = ROOT / ".github" / "workflows"
MAIN = (WORKFLOWS / "main.yml").read_text()

EXPRESSION = re.compile(r"\$\{\{[^}]*\}\}")

# Tokens the "Resolve script modding level" step must produce, per target and
# requested level. Mobile is clamped to 0: project.hxp only adds the hxluajit
# haxelib for desktop targets, so LUA_ALLOWED there fails at `import hxluajit`.
EXPECTED = {
    # (target, requested level): (effective level, tokens)
    ("windows", "0"): ("0", "HSCRIPT"),
    ("windows", "1"): ("1", "LUA_HSCRIPT"),
    ("windows", "2"): ("2", "LUA_PYTHON_HSCRIPT"),
    ("windows", ""): ("2", "LUA_PYTHON_HSCRIPT"),  # push / pull_request: no inputs
    ("android", "0"): ("0", "HSCRIPT"),
    ("android", "1"): ("0", "HSCRIPT"),
    ("android", "2"): ("0", "HSCRIPT"),
    ("android", ""): ("0", "HSCRIPT"),
}

PLATFORM_OF_TARGET = {"windows": "Windows", "android": "Android"}


def expand(text, values):
    """Substitute `${{ ... }}` expressions, like Actions does before bash."""
    return EXPRESSION.sub(lambda match: values.get(match.group(0), ""), text)


def step_body(workflow, name):
    """Return one step's YAML block, up to the next step or comment banner."""
    marker = "      - name: {}\n".format(name)
    if marker not in workflow:
        raise AssertionError("missing workflow step: {}".format(name))
    lines = []
    for line in workflow.split(marker, 1)[1].splitlines():
        if line.startswith(("      - name:", "      - uses:", "      # =")):
            break
        lines.append(line)
    return "\n".join(lines)


def step_env(body):
    """Return the step's `env:` mapping (values still unexpanded)."""
    env = {}
    inside = False
    for line in body.splitlines():
        if line == "        env:":
            inside = True
            continue
        if not inside:
            continue
        if not line.startswith("          ") or not line.strip():
            inside = False
            continue
        key, _, value = line.strip().partition(": ")
        env[key] = value
    return env


def step_script(body):
    """Return the step's `run: |` script, dedented."""
    script = body.split("        run: |\n", 1)[1]
    return "\n".join(line[10:] for line in script.splitlines() if line.strip())


def run_step(name, values, extra_env=None):
    """Run a workflow step's bash script and return (process, GITHUB_OUTPUT)."""
    body = step_body(MAIN, name)
    env = {key: expand(value, values) for key, value in step_env(body).items()}
    env.update(extra_env or {})
    with tempfile.TemporaryDirectory() as tmp:
        output = pathlib.Path(tmp) / "output"
        summary = pathlib.Path(tmp) / "summary.md"
        completed = subprocess.run(
            ["bash", "-e", "-c", expand(step_script(body), values)],
            cwd=ROOT,
            env={
                **os.environ,
                "GITHUB_OUTPUT": str(output),
                "GITHUB_STEP_SUMMARY": str(summary),
                **env,
            },
            capture_output=True,
            text=True,
        )
        text = output.read_text() if output.exists() else ""
    return completed, text


def read_output(text, key):
    match = re.search(r"^{}=(.+)$".format(re.escape(key)), text, re.MULTILINE)
    return match.group(1) if match else None


def resolve_level(target, requested):
    """Run the resolve step and return (level, tokens, completed process)."""
    values = {
        "${{ matrix.target }}": target,
        "${{ matrix.name }}": PLATFORM_OF_TARGET[target],
        "${{ matrix.desktop }}": "true" if target == "windows" else "false",
        "${{ inputs.moddingLevel }}": requested,
    }
    completed, text = run_step("Resolve script modding level", values)
    return read_output(text, "level"), read_output(text, "tokens"), completed


class ModdingLevelTests(unittest.TestCase):
    def test_level_resolves_per_target(self):
        for (target, requested), (level, tokens) in sorted(EXPECTED.items()):
            with self.subTest(target=target, requested=requested or "<unset>"):
                got_level, got_tokens, completed = resolve_level(target, requested)
                self.assertEqual(completed.returncode, 0, completed.stderr)
                self.assertEqual(got_level, level)
                self.assertEqual(got_tokens, tokens)

    def test_mobile_clamp_is_reported(self):
        for requested in ("1", "2"):
            with self.subTest(requested=requested):
                values = {
                    "${{ matrix.target }}": "android",
                    "${{ matrix.name }}": "Android",
                    "${{ matrix.desktop }}": "false",
                    "${{ inputs.moddingLevel }}": requested,
                }
                completed = run_step("Resolve script modding level", values)[0]
                self.assertIn("::notice::", completed.stdout)
                self.assertIn("MODDING_LEVEL=0", completed.stdout)

    def test_invalid_level_fails_the_run(self):
        values = {
            "${{ matrix.target }}": "windows",
            "${{ matrix.name }}": "Windows",
            "${{ matrix.desktop }}": "true",
            "${{ inputs.moddingLevel }}": "3",
        }
        completed = run_step("Resolve script modding level", values)[0]
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("::error::", completed.stdout)

    def test_compile_flags_carry_the_resolved_level(self):
        for name, expected in (
            ("Compile (Windows)", '"-DMODDING_LEVEL=$env:MODDING_LEVEL"'),
            ("Compile (Android)", '"-DMODDING_LEVEL=$MODDING_LEVEL"'),
        ):
            with self.subTest(step=name):
                body = step_body(MAIN, name)
                self.assertIn(expected, body)
                self.assertIn("MODDING_LEVEL: ${{ steps.modding-level.outputs.level }}", body)


class CIArtifactNameTests(unittest.TestCase):
    def test_build_names_carry_the_script_backends(self):
        expected_commit = subprocess.check_output(
            ["git", "rev-parse", "--short=7", "HEAD"], cwd=ROOT, text=True
        ).strip()
        for (target, requested), (_, tokens) in sorted(EXPECTED.items()):
            with self.subTest(target=target, requested=requested or "<unset>"):
                _, resolved_tokens, completed = resolve_level(target, requested)
                self.assertEqual(completed.returncode, 0, completed.stderr)
                self.assertEqual(resolved_tokens, tokens)
                values = {
                    "${{ matrix.target }}": target,
                    "${{ matrix.name }}": PLATFORM_OF_TARGET[target],
                    "${{ steps.modding-level.outputs.tokens }}": resolved_tokens,
                    "${{ steps.modding-level.outputs.level }}": "2",
                }
                completed, text = run_step("Name artifact", values)
                self.assertEqual(completed.returncode, 0, completed.stderr)
                self.assertRegex(
                    text.strip(),
                    r"^name={}_{}_\d{{2}}_\d{{2}}_{}$".format(
                        re.escape(expected_commit), re.escape(target), re.escape(tokens)
                    ),
                )
        self.assertIn("name: ${{ steps.artifact-name.outputs.name }}", MAIN)

    def test_tokens_only_use_artifact_safe_characters(self):
        for target, requested in EXPECTED:
            with self.subTest(target=target, requested=requested or "<unset>"):
                _, tokens, completed = resolve_level(target, requested)
                self.assertEqual(completed.returncode, 0, completed.stderr)
                self.assertRegex(tokens, r"^[A-Z]+(_[A-Z]+)*$")

    def test_run_titles_name_the_modding_level(self):
        for filename in ("main.yml", "release.yml", "release-assets.yml", "mobile-release.yml"):
            with self.subTest(workflow=filename):
                workflow = (WORKFLOWS / filename).read_text()
                self.assertIn("run-name:", workflow)
                self.assertIn("MODDING_LEVEL", workflow.split("run-name:", 1)[1].split("\non:", 1)[0])

    def test_release_workflows_select_the_modding_level(self):
        for filename, expected in (
            ("release.yml", "moddingLevel: ${{ github.event.inputs.moddingLevel }}"),
            ("release-assets.yml", "moddingLevel: ${{ github.event.inputs.moddingLevel }}"),
            ("mobile-release.yml", 'moddingLevel: "0"'),
        ):
            with self.subTest(workflow=filename):
                workflow = (WORKFLOWS / filename).read_text()
                self.assertIn("uses: ./.github/workflows/main.yml", workflow)
                self.assertIn(expected, workflow)
        # The dispatch input is a choice, so a typo cannot reach the build.
        for filename in ("release.yml", "release-assets.yml"):
            workflow = (WORKFLOWS / filename).read_text()
            body = workflow.split("      moddingLevel:\n", 1)[1]
            self.assertIn("type: choice", body)
            for option in ('"0"', '"1"', '"2"'):
                self.assertIn(option, body)

    def test_release_downloads_use_platform_patterns(self):
        for filename, platforms in (
            ("release.yml", ("windows",)),
            ("mobile-release.yml", ("android",)),
            ("release-assets.yml", ("windows", "android")),
        ):
            workflow = (WORKFLOWS / filename).read_text()
            for platform in platforms:
                with self.subTest(workflow=filename, platform=platform):
                    self.assertIn('pattern: "*_{}_*"'.format(platform), workflow)
            self.assertEqual(workflow.count("merge-multiple: true"), len(platforms))


if __name__ == "__main__":
    unittest.main()
