"""Run the dependency-free parser without the engine-wide source/import.hx.

`backend/deeplink/PhoenixURI.hx` is the validator, and `ParsedURI.hx` +
`URIKind.hx` are its (also dependency-free) result types, so all three are
copied next to each other: the v2 `parseEx` API cannot compile without them.
"""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[2]
MODULES = ["PhoenixURI.hx", "ParsedURI.hx", "URIKind.hx"]

haxe = shutil.which("haxe")
if haxe is None:
    sys.exit("haxe not found on PATH - install the toolchain (see docs/HAXE_LINUX.md)")

with tempfile.TemporaryDirectory() as tmp:
    package = Path(tmp) / "backend/deeplink"
    package.mkdir(parents=True)
    for name in MODULES:
        shutil.copy(root / "source/backend/deeplink" / name, package)
    subprocess.run([haxe, "-cp", tmp, "-cp", str(root / "tests/uri"),
                    "--run", "TestPhoenixURI"], check=True)
