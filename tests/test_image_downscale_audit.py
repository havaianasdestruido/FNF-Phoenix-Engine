"""Testes da auditoria de redução 2x de imagens grandes (tools/image_downscale_audit.py).

Verificam que o manifesto corresponde aos arquivos reais do repositório, que cada
candidato excluído tem um motivo, que os totais batem com os itens e que nenhum
asset do jogo foi alterado em relação ao main.
"""

import json
import os
import subprocess
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
MANIFEST = REPO_ROOT / "tools" / "reports" / "image-downscale-manifest.json"
THRESHOLD = 204800


def _load():
    return json.loads(MANIFEST.read_text(encoding="utf-8"))


def _tracked():
    out = subprocess.run(["git", "ls-files", "-z"], cwd=REPO_ROOT, capture_output=True, check=True).stdout
    return [p for p in out.decode("utf-8", "replace").split("\0") if p]


class ImageDownscaleManifestTest(unittest.TestCase):
    def setUp(self):
        self.manifest = _load()
        self.assets = self.manifest["assets"]
        self.summary = self.manifest["summary"]

    def test_candidates_match_repository(self):
        """Todos os rasters rastreados > 200 KB aparecem no manifesto, com o tamanho real."""
        exts = {".png", ".jpg", ".jpeg", ".webp", ".bmp", ".gif", ".tga"}
        expected = {}
        for rel in _tracked():
            if Path(rel).suffix.lower() in exts and (REPO_ROOT / rel).is_file():
                size = (REPO_ROOT / rel).stat().st_size
                if size > THRESHOLD:
                    expected[rel] = size
        found = {a["path"]: a["original_bytes"] for a in self.assets}
        self.assertEqual(set(expected), set(found), "conjunto de candidatos divergente")
        for path, size in expected.items():
            self.assertEqual(found[path], size, f"tamanho divergente: {path}")

    def test_no_asset_modified_relative_to_main(self):
        """Nenhum asset do jogo foi alterado: a auditoria não deve tocar em arquivos."""
        res = subprocess.run(["git", "diff", "--name-only", "origin/main", "--", "assets", "art", "mods", "source"],
                             cwd=REPO_ROOT, capture_output=True, text=True)
        if res.returncode != 0:
            self.skipTest("origin/main indisponível para comparação")
        self.assertEqual(res.stdout.strip(), "", "há alterações em assets/código que não deveriam existir")

    def test_every_excluded_entry_has_reason(self):
        for a in self.assets:
            if a["processing_status"] == "excluded":
                self.assertTrue(a["exclusion_reason"], f"sem motivo de exclusão: {a['path']}")

    def test_summary_is_consistent_with_entries(self):
        s = self.summary
        self.assertEqual(s["eligible_images_discovered"], len(self.assets))
        self.assertEqual(s["images_resized"] + s["images_excluded"], len(self.assets))
        self.assertEqual(s["total_bytes_before"], sum(a["original_bytes"] for a in self.assets))
        self.assertEqual(s["total_bytes_after"], sum((a["resulting_bytes"] or a["original_bytes"]) for a in self.assets))

    def test_odd_dimensions_flag_matches_size(self):
        for a in self.assets:
            self.assertEqual(a["odd_dimensions"], a["original_width"] % 2 != 0 or a["original_height"] % 2 != 0, a["path"])

    def test_no_broken_xml_image_references(self):
        self.assertEqual(self.manifest["broken_references"], [])
        self.assertEqual(self.summary["broken_xml_image_references"], 0)
        for x in _tracked():
            if not x.endswith(".xml"):
                continue
            text = (REPO_ROOT / x).read_text(encoding="utf-8", errors="replace")
            import re
            for ip in re.findall(r'imagePath="([^"]+)"', text):
                self.assertTrue((REPO_ROOT / Path(x).parent / ip).exists(), f"{x} -> {ip} ausente")

    def test_resized_entries_have_exact_half_geometry(self):
        """Regra de validação para entradas futuras já processadas (vazio nesta auditoria)."""
        for a in self.assets:
            if a["processing_status"] != "resized":
                continue
            self.assertEqual(a["resulting_width"] * 2, a["original_width"], a["path"])
            self.assertEqual(a["resulting_height"] * 2, a["original_height"], a["path"])


class SparrowHalvingRuleTest(unittest.TestCase):
    """Regra de elegibilidade: um atlas só é elegível se todos os campos forem pares."""

    def test_odd_field_makes_atlas_ineligible(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location("audit", REPO_ROOT / "tools" / "image_downscale_audit.py")
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        xml = '<TextureAtlas><SubTexture name="a" x="10" y="20" width="31" height="40"/></TextureAtlas>'
        subs = mod.sparrow_subtextures(xml)
        self.assertEqual(len(subs), 1)
        self.assertEqual(mod.odd_fields(subs[0][1]), ["width"])

    def test_even_atlas_is_eligible(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location("audit", REPO_ROOT / "tools" / "image_downscale_audit.py")
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        xml = ('<TextureAtlas><SubTexture name="a" x="10" y="20" width="30" height="40" frameX="-2" frameY="0" '
               'frameWidth="34" frameHeight="40"/></TextureAtlas>')
        subs = mod.sparrow_subtextures(xml)
        self.assertEqual(mod.odd_fields(subs[0][1]), [])


if __name__ == "__main__":
    unittest.main()
