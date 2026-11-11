"""Guard CI artifact naming and the release workflows that consume it."""

import os
import pathlib
import re
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
WORKFLOWS = ROOT / ".github" / "workflows"


class CIArtifactNameTests(unittest.TestCase):
    def test_build_names_match_downloaded_zip_format(self):
        workflow = (WORKFLOWS / "main.yml").read_text()
        step = workflow.split("      - name: Name artifact\n", 1)[1].split(
            "      - name: Publish artifact\n", 1
        )[0]
        script = step.split("        run: |\n", 1)[1]
        script = "\n".join(line[10:] for line in script.splitlines() if line.strip())
        expected_commit = subprocess.check_output(
            ["git", "rev-parse", "--short=7", "HEAD"], cwd=ROOT, text=True
        ).strip()
        for platform in ("windows", "android"):
            with self.subTest(platform=platform), tempfile.TemporaryDirectory() as tmp:
                output = pathlib.Path(tmp) / "output"
                subprocess.run(
                    ["bash", "-e", "-c", script.replace("${{ matrix.target }}", platform)],
                    cwd=ROOT,
                    env={**os.environ, "GITHUB_OUTPUT": str(output)},
                    check=True,
                )
                self.assertRegex(
                    output.read_text().strip(),
                    rf"^name={re.escape(expected_commit)}_{platform}_\d{{2}}_\d{{2}}$",
                )
        self.assertIn("name: ${{ steps.artifact-name.outputs.name }}", workflow)

    def test_release_downloads_use_platform_patterns(self):
        for filename, platforms in (
            ("release.yml", ("windows",)),
            ("mobile-release.yml", ("android",)),
            ("release-assets.yml", ("windows", "android")),
        ):
            workflow = (WORKFLOWS / filename).read_text()
            for platform in platforms:
                with self.subTest(workflow=filename, platform=platform):
                    self.assertIn(f'pattern: "*_{platform}_*"', workflow)
            self.assertEqual(workflow.count("merge-multiple: true"), len(platforms))


if __name__ == "__main__":
    unittest.main()
