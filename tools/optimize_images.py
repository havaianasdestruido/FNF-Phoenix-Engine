#!/usr/bin/env python3
"""Otimizador reproduzível de imagens grandes (> 200 KiB) do FNF-Phoenix-Engine.

Dois caminhos, escolhidos por arquivo:

1. ``reduzir_2x`` (imagens avulsas sem atlas, listadas em ``REDUZIR_2X``):
   - preenche com borda replicada até largura e altura pares (1 px no máximo);
   - reduz exatamente pela metade com Lanczos (tamanho par -> metade exata);
   - grava PNG indexado de 256 cores quando a fidelidade medida (PSNR de cor
     pré-multiplicada pelo alfa) atinge ``PSNR_MINIMO``; caso contrário grava
     RGBA sem perdas;
   - o consumidor (stage) precisa ter o marcador ``OTIMIZACAO_2X`` e a escala
     compensatória; o otimizador recusa o arquivo se o marcador faltar.

2. ``recodificar_sem_perda`` (atlas Sparrow/JSON com coordenadas ímpares):
   a geometria do atlas não pode ser reduzida sem arredondar coordenadas,
   então só a codificação PNG muda. A nova versão só é gravada se os pixels
   decodificados forem idênticos byte a byte e o arquivo for menor.

Requisitos de execução: Python 3 (biblioteca padrão) e ImageMagick (``convert``
e ``identify``). Nada disso é necessário para rodar o jogo.

Uso:
    python3 tools/optimize_images.py              # aplica as mudanças no repositório
    python3 tools/optimize_images.py --dry-run    # processa em diretório temporário
    python3 tools/optimize_images.py --check      # só valida o estado atual
"""

import argparse
import array
import hashlib
import json
import math
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
REPORT_PATH = REPO_ROOT / "tools" / "reports" / "image-optimization-report.json"
THRESHOLD_BYTES = 204800  # 200 KiB
RASTER_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp", ".bmp", ".gif", ".tga"}
PSNR_MINIMO = 35.0  # dB, cor pré-multiplicada pelo alfa, para aceitar a paleta de 256 cores
MARCADOR = "OTIMIZACAO_2X"
# Commit anterior à otimização. Elegibilidade e bytes "antes" vêm dele, para que a
# reexecução não deixe de enxergar imagens que já foram reduzidas abaixo do limiar.
BASE_REF = "5ca9689e3ece9d5ef00621c34a746740f2d98163"

# Imagens avulsas reduzidas 2x. ``orig`` são as dimensões do arquivo original (commit 5ca9689).
# ``consumidores`` são os arquivos de código que precisam da escala compensatória.
REDUZIR_2X = {
    "assets/week5/images/christmas/evilBG.png": {
        "orig": (2625, 1613),
        "consumidores": ["source/stages/MallEvil.hx"],
        "uso": "fundo do stage MallEvil (BGSprite escalado com setGraphicSize)",
    },
    "assets/week5/images/christmas/bgWalls.png": {
        "orig": (3767, 1775),
        "consumidores": ["source/stages/Mall.hx"],
        "uso": "fundo do stage Mall (BGSprite escalado com setGraphicSize)",
    },
    "assets/week4/images/limo/limoSunset.png": {
        "orig": (1968, 1313),
        "consumidores": ["source/stages/Limo.hx"],
        "uso": "céu do stage Limo (BGSprite sem escala explícita)",
    },
}

# Arquivos fora do escopo de jogo, com o motivo registrado no relatório.
FORA_DO_ESCOPO = {
    ".github/res/deeplink.gif": "fora do escopo: GIF de documentação do GitHub (.github/res), não é asset do jogo",
    "assets/shared/images/caseys.jpg": "fora do escopo: fotografia não referenciada por código, JSON ou XML do jogo",
}


# --------------------------------------------------------------------------- utilitários

def _run(args, data=None):
    res = subprocess.run(args, input=data, capture_output=True, check=False)
    if res.returncode != 0:
        raise RuntimeError(f"comando falhou ({' '.join(args[:2])}): {res.stderr.decode('utf-8', 'replace').strip()}")
    return res.stdout


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def identificar(path):
    """Retorna dict com largura, altura, tipo de cor, número de cores e presença de alfa."""
    saida = _run(["identify", "-format", "%w %h %[type] %k %A\n", f"{path}[0]"]).decode().split()
    return {"w": int(saida[0]), "h": int(saida[1]), "tipo": saida[2], "cores": int(saida[3]), "alfa": saida[4].lower() == "true"}


def decodificar_rgba(path):
    """Bytes RGBA 8 bits, linha a linha, sem alteração de pixels."""
    return _run(["convert", f"{path}[0]", "-depth", "8", "RGBA:-"])


def decodificar_png_bytes(dados_png):
    """Decodifica PNG em memória (via stdin do ImageMagick) para RGBA bruto."""
    return _run(["convert", "PNG:-", "-depth", "8", "RGBA:-"], dados_png)


def gravar_png(dados_rgba, w, h, destino, modo="PNG32"):
    """Grava RGBA bruto como PNG (``PNG8`` para paleta de 256 cores, ``PNG32`` sem perdas)."""
    if modo == "PNG8":
        args = ["convert", "-size", f"{w}x{h}", "-depth", "8", "RGBA:-", "-dither", "None", "-colors", "256",
                "-define", "png:compression-level=9", "-define", "png:compression-filter=5", "PNG8:-"]
    else:
        args = ["convert", "-size", f"{w}x{h}", "-depth", "8", "RGBA:-",
                "-define", "png:compression-level=9", "-define", "png:compression-filter=5", "PNG32:-"]
    png = _run(args, dados_rgba)
    return png


def preencher_borda(dados, w, h, w2, h2):
    """Replica a última coluna/linha até (w2, h2). Não altera nenhum pixel original."""
    linhas = []
    for y in range(h):
        linha = dados[y * w * 4:(y + 1) * w * 4]
        if w2 > w:
            linha = linha + linha[-4:] * (w2 - w)
        linhas.append(linha)
    if h2 > h:
        linhas.extend([linhas[-1]] * (h2 - h))
    return b"".join(linhas)


def psnr_premultiplicado(ref, cand):
    """PSNR (dB) da cor pré-multiplicada pelo alfa, mais erro máximo de alfa."""
    a = array.array("B", ref)
    b = array.array("B", cand)
    if len(a) != len(b):
        raise ValueError("tamanhos RGBA diferentes")
    soma_q = 0
    n = 0
    max_alfa = 0
    for i in range(0, len(a), 4):
        ra, ca = a[i + 3], b[i + 3]
        max_alfa = max(max_alfa, abs(ra - ca))
        for c in range(3):
            e = a[i + c] * ra / 255.0 - b[i + c] * ca / 255.0
            soma_q += e * e
            n += 1
    mse = soma_q / n if n else 0.0
    psnr = 99.0 if mse == 0 else 10 * math.log10(255.0 * 255.0 / mse)
    return psnr, max_alfa


# --------------------------------------------------------------------------- descoberta

def arquivos_rastreados():
    saida = _run(["git", "ls-files", "-z"], None)
    return [p for p in saida.decode("utf-8", "replace").split("\0") if p]


def metadados_do_atlas(rel, rastreados):
    """XML/JSON com o mesmo nome base na mesma pasta (Sparrow ou JSON de spritemap)."""
    pasta = Path(rel).parent
    base = Path(rel).stem
    achados = []
    for t in rastreados:
        p = Path(t)
        if p.parent == pasta and p.stem == base and p.suffix.lower() in {".xml", ".json"}:
            achados.append(t)
    return achados


def tamanho_base(rel):
    """Bytes do arquivo no commit base; None se o arquivo não existia lá."""
    try:
        return int(_run(["git", "cat-file", "-s", f"{BASE_REF}:{rel}"]).strip())
    except RuntimeError:
        return None


def sha256_base(rel):
    return hashlib.sha256(_run(["git", "cat-file", "-p", f"{BASE_REF}:{rel}"])).hexdigest()


def descobrir(rastreados):
    candidatos = []
    for rel in rastreados:
        if Path(rel).suffix.lower() not in RASTER_EXTENSIONS:
            continue
        if not (REPO_ROOT / rel).is_file():
            continue
        base = tamanho_base(rel)
        tamanho = base if base is not None else (REPO_ROOT / rel).stat().st_size
        if tamanho > THRESHOLD_BYTES:
            candidatos.append(rel)
    return candidatos


# --------------------------------------------------------------------------- processamento

def processar_reducao_2x(rel, origem, destino, marcadores_ok):
    """Reduz exatamente 2x (com borda par). Retorna dict com resultados e validações."""
    cfg = REDUZIR_2X[rel]
    info = identificar(origem)
    w, h = info["w"], info["h"]
    ow, oh = cfg["orig"]
    # destino calculado a partir do ORIGINAL registrado, nunca das dimensões atuais
    esperado = ((ow + ow % 2) // 2, (oh + oh % 2) // 2)
    if (w, h) == esperado:
        return {"acao": "ja_processado", "motivo": "dimensões já são a metade do original"}
    if (w, h) != (ow, oh):
        raise RuntimeError(f"dimensões inesperadas {w}x{h}; esperado {ow}x{oh} (original) ou {esperado[0]}x{esperado[1]} (reduzido)")
    w2, h2 = ow + ow % 2, oh + oh % 2
    if not marcadores_ok:
        raise RuntimeError("consumidor sem o marcador de compensação 2x; o asset não será reduzido")

    raw = decodificar_rgba(origem)
    padded = preencher_borda(raw, w, h, w2, h2)
    meio = _run(["convert", "-size", f"{w2}x{h2}", "-depth", "8", "RGBA:-", "-filter", "Lanczos",
                 "-resize", f"{esperado[0]}x{esperado[1]}!", "-depth", "8", "RGBA:-"], padded)
    if len(meio) != esperado[0] * esperado[1] * 4:
        raise RuntimeError("redimensionamento produziu tamanho inesperado")

    paleta = gravar_png(meio, esperado[0], esperado[1], None, "PNG8")
    fid = decodificar_png_bytes(paleta)
    psnr, max_alfa = psnr_premultiplicado(meio, fid)

    if psnr >= PSNR_MINIMO:
        modo = "PNG8 (256 cores)"
        dados = paleta
    else:
        modo = "PNG32 (sem perdas)"
        dados = gravar_png(meio, esperado[0], esperado[1], None, "PNG32")

    destino.write_bytes(dados)
    info2 = identificar(destino)
    if (info2["w"], info2["h"]) != esperado:
        raise RuntimeError("dimensões gravadas divergem do esperado")
    if info["alfa"] and not info2["alfa"]:
        raise RuntimeError("alfa perdido no arquivo gravado")
    return {
        "acao": "reduzido_2x",
        "modo_png": modo,
        "dimensoes_depois": [info2["w"], info2["h"]],
        "validacao": {
            "psnr_premultiplicado_db": round(psnr, 2),
            "erro_max_alfa": max_alfa,
            "limiar_psnr_db": PSNR_MINIMO,
            "alfa_preservado": bool(info2["alfa"] or not info["alfa"]),
            "borda_replicada_px": [w2 - w, h2 - h],
        },
    }


def processar_recodificacao(rel, origem, destino):
    """Recodificação PNG sem perdas. Só grava se pixels idênticos e o arquivo ficar menor."""
    tamanho_atual = origem.stat().st_size
    raw = decodificar_rgba(origem)
    info = identificar(origem)
    w, h = info["w"], info["h"]
    # PNG8 do ImageMagick não é usado: medido, ele troca alfa 19 por 0 em pixels visíveis.
    candidatos = [("PNG32", gravar_png(raw, w, h, None, "PNG32"))]

    escolhido = None
    for modo, dados in sorted(candidatos, key=lambda c: len(c[1])):
        if decodificar_png_bytes(dados) != raw:
            continue  # não lossless: rejeitada
        if len(dados) < tamanho_atual:
            escolhido = (modo, dados)
        break  # o menor já foi avaliado; não tentar os maiores

    if escolhido is None:
        return {"acao": "mantido", "motivo": "nenhuma recodificação sem perdas foi menor que o original"}
    destino.write_bytes(escolhido[1])
    info2 = identificar(destino)
    if decodificar_rgba(destino) != raw:
        raise RuntimeError("verificação de pixels falhou após recodificação")
    return {"acao": "recodificado_sem_perda", "modo_png": escolhido[0], "validacao": {"pixels_identicos": True}}


def executar(recodificar_atlas=False, dry_run=False, somente=None):
    rastreados = arquivos_rastreados()
    anterior = {}
    if REPORT_PATH.exists():
        anterior = {a["path"]: a for a in json.loads(REPORT_PATH.read_text(encoding="utf-8")).get("assets", [])}

    candidatos = descobrir(rastreados)
    if somente:
        candidatos = [c for c in candidatos if c in somente]
    entradas = []
    falhas = []
    tmpdir = Path(tempfile.mkdtemp(prefix="img-opt-")) if dry_run else None

    for rel in candidatos:
        origem = REPO_ROOT / rel
        base = tamanho_base(rel)
        entrada = {
            "path": rel,
            "bytes_antes": base if base is not None else origem.stat().st_size,
            "sha256_antes": sha256_base(rel) if base is not None else sha256(origem),
            "dimensoes_antes": None,
            "dimensoes_depois": None,
            "bytes_depois": None,
            "sha256_depois": None,
            "categoria": None,
            "metadados_atlas": [],
            "consumidores": [],
            "acao": None,
            "motivo": None,
            "modo_png": None,
            "xml_atualizados": [],
            "validacao": None,
        }
        info = identificar(origem)
        entrada["dimensoes_antes"] = [info["w"], info["h"]]

        # Reexecução: se o arquivo atual já é o resultado registrado, reaproveita a entrada inteira
        # (com seus detalhes de validação) e não toca no arquivo. Evita degradação em cadeia.
        previa = anterior.get(rel)
        if previa and previa.get("sha256_depois") and previa["sha256_depois"] == sha256(origem):
            reaproveitada = dict(previa)
            reaproveitada["reaproveitado_do_relatorio_anterior"] = True
            entradas.append(reaproveitada)
            continue

        if rel in FORA_DO_ESCOPO:
            entrada.update(categoria="fora_do_escopo", acao="excluido", motivo=FORA_DO_ESCOPO[rel])
            entradas.append(entrada)
            continue

        metadados = metadados_do_atlas(rel, rastreados)
        entrada["metadados_atlas"] = metadados
        if rel in REDUZIR_2X:
            entrada["categoria"] = "imagem_avulsa"
            entrada["consumidores"] = REDUZIR_2X[rel]["consumidores"]
            try:
                marcadores_ok = all(
                    MARCADOR in (REPO_ROOT / c).read_text(encoding="utf-8") for c in REDUZIR_2X[rel]["consumidores"]
                )
                destino = (tmpdir / Path(rel).name) if dry_run else origem
                if dry_run:
                    shutil.copy2(origem, destino)
                resultado = processar_reducao_2x(rel, origem if not dry_run else origem, destino, marcadores_ok)
                entrada.update(resultado)
                entrada["acao"] = resultado["acao"]
            except Exception as exc:  # falha explícita, sem mascarar
                entrada.update(acao="falhou", motivo=str(exc))
                falhas.append(rel)
        elif metadados:
            entrada["categoria"] = "atlas_spritesheet"
            entrada["motivo_geometria"] = (
                "atlas com coordenadas ímpares: a redução 2x exige arredondar frames e "
                "não é feita; apenas a codificação PNG é otimizada"
            )
            if not recodificar_atlas:
                entrada.update(acao="mantido", motivo="recodificação de atlas desativada (use --recodificar-atlas)")
            else:
                try:
                    destino = (tmpdir / Path(rel).name) if dry_run else origem
                    if dry_run:
                        shutil.copy2(origem, destino)
                    resultado = processar_recodificacao(rel, origem, destino)
                    entrada.update(resultado)
                except Exception as exc:
                    entrada.update(acao="falhou", motivo=str(exc))
                    falhas.append(rel)
        else:
            entrada.update(categoria="imagem_avulsa", acao="mantido", motivo="sem plano de otimização aprovado")

        if entrada["acao"] in ("reduzido_2x", "recodificado_sem_perda", "mantido", "ja_processado"):
            destino_final = (tmpdir / Path(rel).name) if dry_run else origem
            entrada["bytes_depois"] = destino_final.stat().st_size
            entrada["sha256_depois"] = sha256(destino_final)
            info2 = identificar(destino_final)
            entrada["dimensoes_depois"] = [info2["w"], info2["h"]]
        entradas.append(entrada)

    resumo = resumo_de(entradas, rastreados)
    relatorio = {
        "descricao": "Relatório do otimizador de imagens grandes (tools/optimize_images.py). Bytes medidos nos arquivos finais.",
        "limiar_bytes": THRESHOLD_BYTES,
        "resumo": resumo,
        "falhas": falhas,
        "assets": sorted(entradas, key=lambda e: e["path"]),
    }
    if dry_run:
        print("[dry-run] nenhum arquivo do repositório foi alterado; relatório temporário em", tmpdir)
        print(json.dumps(resumo, indent=2, ensure_ascii=False))
        shutil.rmtree(tmpdir, ignore_errors=True)
        return 1 if falhas else 0
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(json.dumps(relatorio, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps(resumo, indent=2, ensure_ascii=False))
    return 1 if falhas else 0


def resumo_de(entradas, rastreados):
    proc = [e for e in entradas if e["acao"] in ("reduzido_2x", "recodificado_sem_perda", "ja_processado")]
    antes = sum(e["bytes_antes"] for e in entradas)
    depois = sum(e["bytes_depois"] if e["bytes_depois"] is not None else e["bytes_antes"] for e in entradas)
    economia = antes - depois
    quebradas = []
    for x in rastreados:
        if not x.lower().endswith(".xml"):
            continue
        texto = (REPO_ROOT / x).read_text(encoding="utf-8", errors="replace")
        for ip in re.findall(r'imagePath="([^"]+)"', texto):
            if not (REPO_ROOT / Path(x).parent / ip).exists():
                quebradas.append({"xml": x, "imagePath": ip})
    return {
        "candidatos_acima_de_200kib": len(entradas),
        "reduzidos_2x": sum(1 for e in entradas if e["acao"] == "reduzido_2x"),
        "recodificados_sem_perda": sum(1 for e in entradas if e["acao"] == "recodificado_sem_perda"),
        "avulsos_otimizados": sum(1 for e in entradas if e["acao"] == "reduzido_2x"),
        "otimizados_apenas_por_codificacao": sum(1 for e in entradas if e["acao"] == "recodificado_sem_perda"),
        "xml_atualizados": sum(len(e["xml_atualizados"]) for e in entradas),
        "excluidos_ou_mantidos": sum(1 for e in entradas if e["acao"] in ("excluido", "mantido")),
        "falhas": sum(1 for e in entradas if e["acao"] == "falhou"),
        "bytes_antes": antes,
        "bytes_depois": depois,
        "bytes_economizados": economia,
        "reducao_percentual": round(100.0 * economia / antes, 2) if antes else 0.0,
        "referencias_xml_quebradas": len(quebradas),
    }


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dry-run", action="store_true", help="processa em diretório temporário, sem alterar o repositório")
    ap.add_argument("--check", action="store_true", help="apenas valida o relatório contra os arquivos atuais")
    ap.add_argument("--recodificar-atlas", action="store_true",
                    help="tenta recodificação PNG sem perdas nos atlas (lento; medido sem ganho até agora)")
    args = ap.parse_args(argv)
    if args.check:
        return _verificar()
    return executar(recodificar_atlas=args.recodificar_atlas, dry_run=args.dry_run)


def _verificar():
    if not REPORT_PATH.exists():
        print("relatório ausente:", REPORT_PATH, file=sys.stderr)
        return 1
    rel = json.loads(REPORT_PATH.read_text(encoding="utf-8"))
    erros = 0
    for e in rel["assets"]:
        p = REPO_ROOT / e["path"]
        if not p.exists():
            print("ausente:", e["path"], file=sys.stderr)
            erros += 1
            continue
        if e["acao"] in ("falhou", "excluido"):
            continue  # sem arquivo gravado para comparar
        if sha256(p) != e["sha256_depois"]:
            print("sha256 divergente:", e["path"], file=sys.stderr)
            erros += 1
    print("verificação concluída, erros =", erros)
    return 1 if erros else 0


if __name__ == "__main__":
    sys.exit(main())
