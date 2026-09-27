"""Run the dependency-free parser without the engine-wide source/import.hx."""
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory() as tmp:
    package = Path(tmp) / 'backend/deeplink'
    package.mkdir(parents=True)
    shutil.copy(root / 'source/backend/deeplink/PhoenixURI.hx', package)
    subprocess.run(['haxe', '-cp', tmp, '-cp', str(root / 'tests/uri'),
                    '--run', 'TestPhoenixURI'], check=True)
