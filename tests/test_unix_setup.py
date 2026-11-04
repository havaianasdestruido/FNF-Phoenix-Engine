#!/usr/bin/env python3
"""Dynamic regression tests for the Unix dependency setup script."""
from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class UnixSetupTests(unittest.TestCase):
    def test_source_hxcpp_tools_are_compiled_from_resolved_checkout(self):
        """`haxelib path hxcpp` already includes the checkout's /git suffix."""
        with tempfile.TemporaryDirectory() as temp_dir:
            temp = Path(temp_dir)
            bin_dir = temp / "bin"
            hxcpp = temp / "hxcpp" / "git"
            log = temp / "haxe.log"
            bin_dir.mkdir()
            (hxcpp / "tools" / "run").mkdir(parents=True)
            (hxcpp / "tools" / "hxcpp").mkdir()

            haxelib = bin_dir / "haxelib"
            haxelib.write_text(
                "#!/bin/sh\n"
                "if [ \"$1\" = path ] && [ \"$2\" = hxcpp ]; then\n"
                "  printf '%s\\n' \"$FAKE_HXCPP_PATH\"\n"
                "fi\n",
                encoding="utf-8",
            )
            haxe = bin_dir / "haxe"
            haxe.write_text(
                "#!/bin/sh\n"
                "printf '%s %s\\n' \"$PWD\" \"$*\" >> \"$FAKE_HAXE_LOG\"\n",
                encoding="utf-8",
            )
            haxelib.chmod(0o755)
            haxe.chmod(0o755)

            env = os.environ.copy()
            env.update(
                PATH=f"{bin_dir}:{env['PATH']}",
                SKIP_SYSTEM_DEPENDENCIES="1",
                FAKE_HXCPP_PATH=str(hxcpp),
                FAKE_HAXE_LOG=str(log),
            )
            subprocess.run(
                ["sh", str(ROOT / "setup" / "unix.sh")],
                cwd=ROOT,
                env=env,
                check=True,
                capture_output=True,
                text=True,
                timeout=30,
            )

            invocations = log.read_text(encoding="utf-8").splitlines()
            self.assertEqual(
                invocations,
                [
                    f"{hxcpp / 'tools' / 'run'} compile.hxml",
                    f"{hxcpp / 'tools' / 'hxcpp'} compile.hxml",
                ],
            )


if __name__ == "__main__":
    unittest.main()
