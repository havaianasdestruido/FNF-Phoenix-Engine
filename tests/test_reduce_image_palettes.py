"""Tests for tools/reduce_image_palettes.py (maintenance-only dependencies).

The module needs Pillow/numpy/imagequant; tests are skipped when those are not
installed, just like tests/test_optimize_images.py skips without ImageMagick.
"""

import hashlib
import importlib.util
import io
import json
import os
import subprocess
import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
TOOL = REPO_ROOT / "tools" / "reduce_image_palettes.py"
REPORT = REPO_ROOT / "tools" / "reports" / "palette-reduction-report.json"

_spec = importlib.util.spec_from_file_location("reduce_image_palettes", TOOL)
tool = importlib.util.module_from_spec(_spec)
# dataclasses resolve annotations through sys.modules; register before loading.
sys.modules[_spec.name] = tool
_spec.loader.exec_module(tool)

DEPS_OK = not tool.IMPORT_ERROR


@unittest.skipUnless(DEPS_OK, "Pillow/numpy/imagequant not installed")
class PaletteEncodingTest(unittest.TestCase):
    def _palette(self):
        import numpy as np
        idx = np.array([[0, 1, 2, 3],
                        [3, 2, 1, 0],
                        [1, 1, 2, 2],
                        [0, 0, 3, 3]], dtype=np.uint8)
        rgb = bytes([255, 0, 0, 0, 255, 0, 0, 0, 255, 255, 255, 0])
        alpha = bytes([255, 128, 0, 64])
        return tool.Palette(4, 4, idx, rgb, alpha)

    def test_bits_and_both_encoders_keep_alpha(self):
        pal = self._palette()
        self.assertEqual(pal.ncolors, 4)
        self.assertEqual(pal.bits, 2)
        expected = pal.rgba_array()
        for name, data in (("built-in", tool.encode_paletted(pal)),
                           ("pillow", pal.to_png())):
            with self.subTest(encoder=name):
                info = tool.png_ihdr(data)
                self.assertEqual(info["color_type"], 3)
                self.assertEqual(info["bit_depth"], 2)
                self.assertEqual(info["width"], 4)
                self.assertEqual(info["height"], 4)
                self.assertTrue(tool.decoded_matches(data, pal))
                from PIL import Image
                import numpy as np
                dec = np.asarray(Image.open(io.BytesIO(data)).convert("RGBA"))
                self.assertTrue(np.array_equal(dec, expected))
                self.assertEqual(sorted(set(dec[:, :, 3].ravel().tolist())), [0, 64, 128, 255])

    def test_no_trns_when_all_opaque(self):
        import numpy as np
        pal = tool.Palette(2, 1, np.array([[0, 1]], dtype=np.uint8),
                           bytes([255, 0, 0, 0, 0, 255]), None)
        data = tool.encode_paletted(pal)
        self.assertNotIn(b"tRNS", data)
        self.assertEqual(tool.png_ihdr(data)["bit_depth"], 1)
        self.assertTrue(tool.decoded_matches(data, pal))


@unittest.skipUnless(DEPS_OK, "Pillow/numpy/imagequant not installed")
class QuantizerAndQualityTest(unittest.TestCase):
    def test_quantize_fast_is_lossless_for_a_small_palette(self):
        from PIL import Image
        import numpy as np
        src = np.array([[[255, 0, 0, 255], [0, 255, 0, 19]],
                        [[0, 0, 255, 0], [255, 255, 0, 128]]], dtype=np.uint8)
        im = Image.fromarray(src, "RGBA")
        q = tool.quantize_fast(im, np.ascontiguousarray(src), 256, 0.0)
        pal = tool.Palette.from_quantized(q)
        out = pal.rgba_array()
        self.assertLessEqual(pal.ncolors, 4)
        self.assertIsNotNone(pal.alpha)
        # libimagequant is free to repaint fully transparent pixels (their RGB
        # is invisible); the alpha levels and visible premultiplied colours
        # must be exact.
        self.assertTrue(np.array_equal(out[:, :, 3], src[:, :, 3]))
        prem_src = src[:, :, :3].astype(np.float32) * (src[:, :, 3:4] / 255.0)
        prem_out = out[:, :, :3].astype(np.float32) * (out[:, :, 3:4] / 255.0)
        self.assertTrue(np.allclose(prem_src, prem_out))

    def test_identical_images_have_perfect_metrics(self):
        import numpy as np
        a = np.zeros((3, 3, 4), dtype=np.uint8)
        a[:, :, 3] = 255
        m = tool.quality_metrics(a, a.copy())
        self.assertEqual(m["psnr"], 99.0)
        self.assertEqual(m["alpha_mae"], 0.0)
        self.assertEqual(m["lost"], 0)
        self.assertTrue(tool.quality_gate(m, tool.PROFILES["aggressive"])[0])

    def test_gate_rejects_lost_pixels_and_alpha_damage(self):
        perfect = dict(psnr=99.0, alpha_mae=0.0, alpha_max=0, halo=0,
                       lost=0, opaque_bad=0.0, changed_gt8=0.0, visible=100, total=100)
        self.assertFalse(tool.quality_gate(dict(perfect, lost=1), tool.PROFILES["safe"])[0])
        self.assertFalse(tool.quality_gate(dict(perfect, alpha_mae=9.0), tool.PROFILES["safe"])[0])
        self.assertFalse(tool.quality_gate(dict(perfect, psnr=20.0), tool.PROFILES["safe"])[0])
        self.assertFalse(tool.quality_gate(dict(perfect, opaque_bad=0.5), tool.PROFILES["safe"])[0])
        self.assertFalse(tool.quality_gate(dict(perfect, changed_gt8=0.5), tool.PROFILES["safe"])[0])


@unittest.skipUnless(DEPS_OK, "Pillow/numpy/imagequant not installed")
class CommandLineTest(unittest.TestCase):
    def _run(self, *args):
        env = dict(os.environ)
        env.setdefault("PYTHONPATH", "")
        return subprocess.run([sys.executable, str(TOOL), *args],
                              cwd=REPO_ROOT, env=env, capture_output=True, text=True, timeout=120)

    def test_dry_run_leaves_the_file_untouched(self):
        asset = REPO_ROOT / "assets/preload/images/achievements/lol.png"
        before = hashlib.sha256(asset.read_bytes()).hexdigest()
        res = self._run("--dry-run", "--jobs", "1", "--paths", str(asset))
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertIn("Dry run", res.stdout)
        self.assertEqual(hashlib.sha256(asset.read_bytes()).hexdigest(), before)

    @unittest.skipUnless(REPORT.is_file(), "report not generated yet")
    def test_check_report(self):
        res = self._run("--check")
        self.assertEqual(res.returncode, 0, res.stdout + res.stderr)
        self.assertIn("OK:", res.stdout)
        report = json.loads(REPORT.read_text())
        self.assertGreater(report["summary"]["files_changed"], 0)


if __name__ == "__main__":
    unittest.main()
