"""Testes do otimizador de imagens (tools/optimize_images.py).

Validam a transformação real: dimensões exatas, alfa preservado, idempotência,
falhas explícitas quando a compensação do consumidor falta e o estado do
repositório frente ao commit base (5ca9689). Os testes que dependem do
ImageMagick são pulados quando ``convert``/``identify`` não estão instalados.
"""

import importlib.util
import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
BASE_COMMIT = "5ca9689e3ece9d5ef00621c34a746740f2d98163"
REPORT = REPO_ROOT / "tools" / "reports" / "image-optimization-report.json"

_spec = importlib.util.spec_from_file_location("optimize_images", REPO_ROOT / "tools" / "optimize_images.py")
otimizador = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(otimizador)

HAS_IM = shutil.which("convert") is not None and shutil.which("identify") is not None


def _git(*args):
    return subprocess.run(["git", *args], cwd=REPO_ROOT, capture_output=True, text=True, check=True).stdout


def _garantir_commit_base():
    """Garante o commit base (5ca9689), buscando-o se o clone for raso (ex.: CI com depth 1)."""
    def existe():
        return subprocess.run(["git", "cat-file", "-e", f"{BASE_COMMIT}^{{commit}}"],
                              cwd=REPO_ROOT, capture_output=True).returncode == 0
    if existe():
        return
    subprocess.run(["git", "fetch", "--no-tags", "--depth=1", "origin", BASE_COMMIT],
                   cwd=REPO_ROOT, capture_output=True)
    if not existe():
        raise unittest.SkipTest("commit base 5ca9689 indisponível neste clone")


def _criar_png_sintetico(caminho, w, h):
    """PNG RGBA: bloco vermelho opaco à esquerda, bloco verde semitransparente, borda totalmente transparente."""
    subprocess.run(
        ["convert", "-size", f"{w}x{h}", "xc:none",
         "-fill", "rgba(255,0,0,255)", "-draw", f"rectangle 0,0 {w // 2 - 1},{h - 1}",
         "-fill", "rgba(0,255,0,128)", "-draw", f"rectangle {w // 2},0 {w - 3},{h - 3}",
         "PNG32:" + str(caminho)],
        check=True, capture_output=True,
    )


class BordaEPsnrTest(unittest.TestCase):
    """Funções puras: não dependem do ImageMagick."""

    def test_preencher_borda_replica_ultima_coluna_e_linha(self):
        # 2x2 RGBA: pixels distintos para ver a replicação
        dados = bytes([1, 0, 0, 255, 2, 0, 0, 255,
                       3, 0, 0, 255, 4, 0, 0, 255])
        out = otimizador.preencher_borda(dados, 2, 2, 3, 3)
        self.assertEqual(len(out), 3 * 3 * 4)
        linhas = [out[i * 12:(i + 1) * 12] for i in range(3)]
        self.assertEqual(linhas[0][8:12], bytes([2, 0, 0, 255]))  # coluna extra = última coluna
        self.assertEqual(linhas[2], linhas[1])                     # linha extra = última linha

    def test_preencher_borda_sem_padding_mantem_pixels(self):
        dados = bytes(range(16))
        self.assertEqual(otimizador.preencher_borda(dados, 2, 2, 2, 2), dados)

    def test_psnr_identico_e_infinito(self):
        dados = bytes([10, 20, 30, 255] * 4)
        psnr, alfa = otimizador.psnr_premultiplicado(dados, dados)
        self.assertEqual(psnr, 99.0)
        self.assertEqual(alfa, 0)

    def test_psnr_detecta_erro_de_cor(self):
        ref = bytes([200, 0, 0, 255] * 4)
        cand = bytes([100, 0, 0, 255] * 4)
        psnr, _ = otimizador.psnr_premultiplicado(ref, cand)
        self.assertLess(psnr, 40)

    def test_psnr_detecta_erro_de_alfa(self):
        ref = bytes([200, 0, 0, 255] * 4)
        cand = bytes([200, 0, 0, 0] * 4)
        _, alfa = otimizador.psnr_premultiplicado(ref, cand)
        self.assertEqual(alfa, 255)

    def test_tamanho_diferente_falha(self):
        with self.assertRaises(ValueError):
            otimizador.psnr_premultiplicado(bytes(8), bytes(4))


@unittest.skipUnless(HAS_IM, "ImageMagick ausente")
class ReducaoSinteticaTest(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="test-opt-"))
        self.addCleanup(shutil.rmtree, self.tmp, True)

    def _reduzir(self, w, h, consumidor_ok=True, orig=None):
        origem = self.tmp / "sintetico.png"
        _criar_png_sintetico(origem, w, h)
        rel = "tests/sintetico.png"
        otimizador.REDUZIR_2X[rel] = {"orig": orig or (w, h), "consumidores": [], "uso": "teste"}
        try:
            return origem, otimizador.processar_reducao_2x(rel, origem, origem, consumidor_ok)
        finally:
            del otimizador.REDUZIR_2X[rel]

    def test_dimensoes_pares_sao_metade_exata(self):
        origem, res = self._reduzir(500, 500)
        self.assertEqual(res["acao"], "reduzido_2x")
        info = otimizador.identificar(origem)
        self.assertEqual((info["w"], info["h"]), (250, 250))

    def test_dimensoes_1024x768_viram_512x384(self):
        origem, res = self._reduzir(1024, 768)
        info = otimizador.identificar(origem)
        self.assertEqual((info["w"], info["h"]), (512, 384))

    def test_dimensoes_impares_sao_preenchidas_e_reduzidas(self):
        origem, res = self._reduzir(7, 5)
        info = otimizador.identificar(origem)
        self.assertEqual((info["w"], info["h"]), (4, 3))  # 8x6 com borda replicada -> 4x3
        self.assertEqual(res["validacao"]["borda_replicada_px"], [1, 1])

    def test_alfa_e_preservado_na_borda_transparente(self):
        origem, res = self._reduzir(64, 64)
        info = otimizador.identificar(origem)
        self.assertTrue(info["alfa"])
        rgba = otimizador.decodificar_rgba(origem)
        # canto superior esquerdo do bloco vermelho deve continuar opaco
        self.assertEqual(rgba[3], 255)
        # a faixa verde é semitransparente; o alfa médio fica entre 0 e 255
        self.assertGreater(res["validacao"]["psnr_premultiplicado_db"], 20)

    def test_reexecucao_nao_reduz_de_novo(self):
        origem, _ = self._reduzir(64, 64)
        info_antes = otimizador.identificar(origem)
        # segunda chamada com as dimensões já reduzidas: dimensões == metade -> já processado
        rel = "tests/sintetico.png"
        otimizador.REDUZIR_2X[rel] = {"orig": (64, 64), "consumidores": [], "uso": "teste"}
        try:
            res2 = otimizador.processar_reducao_2x(rel, origem, origem, True)
        finally:
            del otimizador.REDUZIR_2X[rel]
        self.assertEqual(res2["acao"], "ja_processado")
        self.assertEqual(otimizador.identificar(origem)["w"], info_antes["w"])

    def test_consumidor_sem_marcador_falha_explicitamente(self):
        origem = self.tmp / "sem_marcador.png"
        _criar_png_sintetico(origem, 32, 32)
        rel = "tests/sem_marcador.png"
        otimizador.REDUZIR_2X[rel] = {"orig": (32, 32), "consumidores": [], "uso": "teste"}
        try:
            with self.assertRaises(RuntimeError):
                otimizador.processar_reducao_2x(rel, origem, origem, False)
        finally:
            del otimizador.REDUZIR_2X[rel]
        self.assertEqual(otimizador.identificar(origem)["w"], 32)  # arquivo intocado

    def test_dimensoes_inesperadas_falham(self):
        origem = self.tmp / "dim.png"
        _criar_png_sintetico(origem, 40, 40)
        rel = "tests/dim.png"
        otimizador.REDUZIR_2X[rel] = {"orig": (99, 99), "consumidores": [], "uso": "teste"}
        try:
            with self.assertRaises(RuntimeError):
                otimizador.processar_reducao_2x(rel, origem, origem, True)
        finally:
            del otimizador.REDUZIR_2X[rel]
        self.assertEqual(otimizador.identificar(origem)["w"], 40)

    def test_paleta_aceita_so_com_psnr_minimo(self):
        self.assertEqual(otimizador.PSNR_MINIMO, 35.0)


@unittest.skipUnless(HAS_IM, "ImageMagick ausente")
class ValidacaoDoRepositorioTest(unittest.TestCase):
    """Estado real: relatório, arquivos gravados e compensação nos stages."""

    @classmethod
    def setUpClass(cls):
        cls.rel = json.loads(REPORT.read_text(encoding="utf-8"))
        cls.assets = {a["path"]: a for a in cls.rel["assets"]}

    def test_relatorio_existe_e_tem_resumo(self):
        self.assertIn("resumo", self.rel)
        self.assertEqual(self.rel["resumo"]["falhas"], 0)

    def test_reduzidos_tem_dimensao_metade_exata_ou_teto(self):
        for path, a in self.assets.items():
            if a["acao"] != "reduzido_2x":
                continue
            w, h = a["dimensoes_antes"]
            self.assertEqual(a["dimensoes_depois"], [(w + w % 2) // 2, (h + h % 2) // 2], path)
            self.assertEqual(a["dimensoes_depois"][0] * 2 - w in (0, 1), True, path)
            self.assertEqual(a["dimensoes_depois"][1] * 2 - h in (0, 1), True, path)

    def test_arquivo_gravado_corresponde_ao_relatorio(self):
        for path, a in self.assets.items():
            if a["acao"] not in ("reduzido_2x", "recodificado_sem_perda", "mantido", "ja_processado"):
                continue
            f = REPO_ROOT / path
            self.assertEqual(f.stat().st_size, a["bytes_depois"], path)
            self.assertEqual(otimizador.sha256(f), a["sha256_depois"], path)
            info = otimizador.identificar(f)
            self.assertEqual([info["w"], info["h"]], a["dimensoes_depois"], path)

    def test_somente_os_avulsos_foram_alterados_em_relacao_ao_base(self):
        _garantir_commit_base()
        alterados = set(_git("diff", "--name-only", BASE_COMMIT, "--", "assets", "source", "tools", "tests").split())
        esperados = {
            "assets/week4/images/limo/limoSunset.png",
            "assets/week5/images/christmas/bgWalls.png",
            "assets/week5/images/christmas/evilBG.png",
            "source/stages/Limo.hx",
            "source/stages/Mall.hx",
            "source/stages/MallEvil.hx",
        }
        self.assertTrue(alterados & esperados == esperados, f"faltando: {esperados - alterados}")
        assets_alterados = {p for p in alterados if p.startswith("assets/") and p.endswith(".png")}
        self.assertEqual(assets_alterados, {p for p in esperados if p.endswith(".png")})

    def test_nenhum_xml_foi_alterado(self):
        _garantir_commit_base()
        xml = _git("diff", "--name-only", BASE_COMMIT, "--", "*.xml").strip()
        self.assertEqual(xml, "")

    def test_atlas_permanecem_identicos_ao_base(self):
        for path, a in self.assets.items():
            if a["categoria"] == "atlas_spritesheet":
                self.assertEqual(a["sha256_antes"], a["sha256_depois"], path)

    def test_compensacao_nos_stages(self):
        mall = (REPO_ROOT / "source/stages/Mall.hx").read_text(encoding="utf-8")
        evil = (REPO_ROOT / "source/stages/MallEvil.hx").read_text(encoding="utf-8")
        limo = (REPO_ROOT / "source/stages/Limo.hx").read_text(encoding="utf-8")
        self.assertIn("OTIMIZACAO_2X (christmas/bgWalls)", mall)
        self.assertIn("bg.offset.set(377, 177.64);", mall)
        self.assertIn("OTIMIZACAO_2X (christmas/evilBG)", evil)
        self.assertIn("bg.offset.set(262.5, 161.3);", evil)
        self.assertIn("OTIMIZACAO_2X (limo/limoSunset)", limo)
        self.assertIn("skyBG.scale.set(2, 2);", limo)

    def test_referencias_xml_quebradas_zero(self):
        self.assertEqual(self.rel["resumo"]["referencias_xml_quebradas"], 0)

    def test_totais_batem_com_os_arquivos(self):
        antes = sum(a["bytes_antes"] for a in self.assets.values())
        depois = sum(a["bytes_depois"] if a["bytes_depois"] is not None else a["bytes_antes"] for a in self.assets.values())
        self.assertEqual(self.rel["resumo"]["bytes_antes"], antes)
        self.assertEqual(self.rel["resumo"]["bytes_depois"], depois)


if __name__ == "__main__":
    unittest.main()
