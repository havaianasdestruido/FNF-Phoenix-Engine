#!/usr/bin/env python3
"""Regression tests for the mods/ asset walk that broke every native build.

`project.hxp` adds `mods/` as an asset path, and `Project.addAssetPath()` walks
it with `sys.FileSystem.isDirectory()`. On HashLink/Neko that call throws
`std@sys_file_type` when the entry cannot be stat()ed -- exactly what a dangling
symlink does.

`mods/fnf_030_ui` used to be a *tracked* symlink to
`mods/psych-scripts/fnf_030_ui`, and `mods/psych-scripts` is a git submodule
that `actions/checkout` does not populate. Every Windows and Android build
therefore died in the project-evaluation step with:

    Uncaught exception - std@sys_file_type

before any Haxe or C++ compilation started (#129).

The invariants pinned here:

* no tracked symlink may point into a submodule (or anywhere else that a plain
  checkout does not have), because it dangles on CI and on fresh clones;
* `mods/fnf_030_ui` is generated locally/CI-side, never committed;
* `addAssetPath()` resolves an entry before asking what type it is, so a broken
  link is a warning instead of a dead build;
* the sparse-submodule workflow still creates the link it documents.

Run:  python3 -m unittest discover -s tests -p 'test_*.py' -v
"""
from __future__ import annotations

import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

SYMLINK_MODE = "120000"
GITLINK_MODE = "160000"


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8", errors="ignore")


def git(*args: str) -> str:
    return subprocess.run(
        ["git", "-C", str(ROOT), *args],
        check=True,
        capture_output=True,
        text=True,
    ).stdout


def index_entries() -> list[tuple[str, str]]:
    """(mode, path) for every entry in the index."""
    entries = []
    for line in git("ls-files", "-s").splitlines():
        meta, path = line.split("\t", 1)
        mode = meta.split()[0]
        entries.append((mode, path))
    return entries


class TrackedSymlinkTests(unittest.TestCase):
    def setUp(self):
        try:
            self.entries = index_entries()
        except (OSError, subprocess.CalledProcessError) as error:  # pragma: no cover
            self.skipTest(f"git index unavailable: {error}")

    def test_no_tracked_symlink_points_into_a_submodule(self):
        gitlinks = [p for mode, p in self.entries if mode == GITLINK_MODE]
        offenders = []

        for mode, path in self.entries:
            if mode != SYMLINK_MODE:
                continue

            link = ROOT / path
            target = link.readlink()
            resolved = (link.parent / target).resolve()

            try:
                relative = resolved.relative_to(ROOT.resolve()).as_posix()
            except ValueError:
                offenders.append(f"{path} -> {target} (escapes the repository)")
                continue

            for submodule in gitlinks:
                if relative == submodule or relative.startswith(submodule + "/"):
                    offenders.append(
                        f"{path} -> {target} (inside uninitialised submodule {submodule})"
                    )
                    break
            else:
                if not resolved.exists():
                    offenders.append(f"{path} -> {target} (dangling)")

        self.assertEqual(
            offenders,
            [],
            "Tracked symlinks must resolve in a plain `git clone` without "
            "submodules; a dangling one aborts every build (#129):\n  "
            + "\n  ".join(offenders),
        )

    def test_fnf_030_ui_link_is_generated_not_committed(self):
        tracked = {p for _, p in self.entries}
        self.assertNotIn(
            "mods/fnf_030_ui",
            tracked,
            "mods/fnf_030_ui points into the psych-scripts submodule; committing "
            "it makes the link dangle on CI and aborts the build (#129).",
        )

        ignore_rules = [
            line.strip()
            for line in read(".gitignore").splitlines()
            if line.strip() and not line.strip().startswith("#")
        ]
        self.assertIn("mods/fnf_030_ui", ignore_rules)

    def test_sparse_submodule_workflow_creates_the_link(self):
        workflow = read(".github/workflows/sparse-submodule.yml")
        self.assertIn("ln -s psych-scripts/fnf_030_ui mods/fnf_030_ui", workflow)
        self.assertIn("test -f mods/fnf_030_ui/pack.json", workflow)


class AssetWalkTests(unittest.TestCase):
    def test_add_asset_path_resolves_entries_before_typing_them(self):
        project = read("project.hxp")

        start = project.index("public function addAssetPath(")
        body = project[start:]
        body = body[: body.index("\n\t/**\n\t * Add an asset library")]

        loop = body[body.index("for (file in sys.FileSystem.readDirectory(path))") :]

        # The entry is captured once and probed with the non-throwing helper...
        exists_at = loop.index("if (!sys.FileSystem.exists(fullPath))")
        is_dir_at = loop.index("sys.FileSystem.isDirectory(fullPath)")

        self.assertLess(
            exists_at,
            is_dir_at,
            "Project.addAssetPath() must check FileSystem.exists() before "
            "FileSystem.isDirectory(); the latter throws std@sys_file_type for "
            "an unstat-able entry such as a dangling symlink (#129).",
        )

        # ...and a missing target is skipped, not fatal.
        missing_branch = loop[exists_at:is_dir_at]
        self.assertIn("Log.warn(", missing_branch)
        self.assertNotIn("error(", missing_branch)

        # The recursive/leaf calls use the resolved path, not a re-joined one.
        self.assertIn("addAssetPath(fullPath,", loop)
        self.assertIn("addAsset(fullPath,", loop)


if __name__ == "__main__":
    unittest.main(verbosity=2)
