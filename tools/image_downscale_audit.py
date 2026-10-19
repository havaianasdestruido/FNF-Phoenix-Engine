#!/usr/bin/env python3
"""Auditoria de imagens grandes (> 200 KB) para a redução exata de 2x.

Este script NÃO altera nenhum asset. Ele varre os arquivos rastreados pelo Git,
mede tamanho em bytes e dimensões reais (ImageMagick `identify`), localiza os
metadados (XML Sparrow, JSON de spritemap/TexturePacker) que referenciam cada
imagem e decide se a redução exata de 2x é segura.

Política de elegibilidade (todas as condições precisam ser verdadeiras):
  1. Largura e altura da imagem são pares (metade exata, sem arredondamento).
  2. Todas as coordenadas do atlas (x, y, width, height, frameX, frameY,
     frameWidth, frameHeight, ou x/y/w/h do JSON) são pares, pois o engine lê
     esses valores como inteiros (Sparrow usa parseInt/parseFloat) e metade
     de um pixel não é representável sem reamostragem/arredondamento.
  3. O asset é um recurso do jogo (não documentação, fotografia ou GIF).

Uso:
    python3 tools/image_downscale_audit.py            # grava tools/reports/image-downscale-manifest.json
    python3 tools/image_downscale_audit.py --stdout   # apenas imprime o resumo
"""

import json
import os
import re
import subprocess
import sys
from pathlib import Path

THRESHOLD_BYTES = 204800  # 200 KB
RASTER_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp", ".bmp", ".gif", ".tga"}
SPARROW_FIELDS = ("x", "y", "width", "height", "frameX", "frameY", "frameWidth", "frameHeight")
REPO_ROOT = Path(__file__).resolve().parent.parent
MANIFEST_PATH = REPO_ROOT / "tools" / "reports" / "image-downscale-manifest.json"

# Arquivos fora do escopo de jogo, com o motivo registrado no manifesto.
OUT_OF_SCOPE = {
    ".github/res/deeplink.gif": "fora do escopo: GIF de documentação do GitHub (.github/res), não é asset do jogo",
    "assets/shared/images/caseys.jpg": "fora do escopo: fotografia real não referenciada por código, JSON ou XML do jogo",
}


def git_files():
    out = subprocess.run(["git", "ls-files", "-z"], cwd=REPO_ROOT, capture_output=True, check=True).stdout
    return [p for p in out.decode("utf-8", "replace").split("\0") if p]


def image_size(path: Path):
    """Retorna (largura, altura) do primeiro frame usando ImageMagick."""
    out = subprocess.run(
        ["identify", "-format", "%w %h\n", f"{path}[0]"], capture_output=True, text=True, check=True
    ).stdout.split()
    return int(out[0]), int(out[1])


def sparrow_subtextures(xml_text):
    """Extrai, para cada SubTexture, o dicionário de campos geométricos presentes."""
    rows = []
    for tag in re.findall(r"<SubTexture[^>]*>", xml_text):
        fields = {}
        for name in SPARROW_FIELDS:
            m = re.search(r'\s' + name + r'="(-?[\d.]+)"', tag)
            if m:
                fields[name] = float(m.group(1))
        rows.append((re.search(r'name="([^"]*)"', tag).group(1) if 'name="' in tag else "?", fields))
    return rows


def spritemap_rects(json_text):
    """Coordenadas de sprites do Animate spritemap (ATLAS.SPRITES[].SPRITE)."""
    data = json.loads(json_text)
    rects = []
    for item in data.get("ATLAS", {}).get("SPRITES", []):
        s = item.get("SPRITE", {})
        if all(k in s for k in ("x", "y", "w", "h")):
            rects.append((s.get("name", "?"), {"x": float(s["x"]), "y": float(s["y"]),
                                                "width": float(s["w"]), "height": float(s["h"])}))
    return rects


def odd_fields(fields):
    return [k for k, v in fields.items() if v % 2 != 0]


def main():
    tracked = git_files()
    candidates = []
    for rel in tracked:
        p = REPO_ROOT / rel
        if Path(rel).suffix.lower() not in RASTER_EXTENSIONS or not p.is_file():
            continue
        size = p.stat().st_size
        if size > THRESHOLD_BYTES:
            candidates.append((rel, size))

    text_files = [t for t in tracked if Path(t).suffix.lower() in {".xml", ".json", ".hx", ".lua", ".py", ".hxp", ".md", ".txt", ".ini"}]
    xml_files = [t for t in tracked if t.lower().endswith(".xml")]

    entries = []
    for rel, size in candidates:
        path = REPO_ROOT / rel
        w, h = image_size(path)
        entry = {
            "path": rel,
            "original_bytes": size,
            "original_width": w,
            "original_height": h,
            "category": None,
            "atlas_format": None,
            "metadata_files": [],
            "odd_dimensions": w % 2 != 0 or h % 2 != 0,
            "even_subtextures": None,
            "total_subtextures": None,
            "processing_status": "excluded",
            "exclusion_reason": None,
            "resulting_width": None,
            "resulting_height": None,
            "resulting_bytes": None,
            "xml_fields_modified": [],
            "validation": "nao_executada: nenhum asset foi processado",
        }

        if rel in OUT_OF_SCOPE:
            entry["category"] = "fora_do_escopo"
            entry["exclusion_reason"] = OUT_OF_SCOPE[rel]
            entries.append(entry)
            continue

        stem = Path(rel).stem
        xml_meta = [x for x in xml_files if Path(x).parent == Path(rel).parent and Path(x).stem == stem]
        json_meta = [x for x in tracked if x.endswith(".json") and Path(x).parent == Path(rel).parent and Path(x).stem == stem]
        # Referências por nome do arquivo em outros metadados (ex.: spritemap1.json usa spritemap1.png).
        referencing = []
        for t in text_files:
            if t in xml_meta or t in json_meta:
                continue
            if stem and (REPO_ROOT / t).read_text(encoding="utf-8", errors="replace").find(Path(rel).name) >= 0:
                referencing.append(t)
        entry["metadata_files"] = xml_meta + json_meta
        entry["referenced_by"] = referencing

        if xml_meta:
            entry["atlas_format"] = "sparrow_xml"
            txt = (REPO_ROOT / xml_meta[0]).read_text(encoding="utf-8", errors="replace")
            subs = sparrow_subtextures(txt)
            entry["total_subtextures"] = len(subs)
            entry["even_subtextures"] = sum(1 for _, f in subs if not odd_fields(f))
            entry["category"] = "atlas_spritesheet"
        elif json_meta:
            entry["atlas_format"] = "animate_spritemap_json"
            entry["category"] = "atlas_spritesheet"
            rects = spritemap_rects((REPO_ROOT / json_meta[0]).read_text(encoding="utf-8", errors="replace"))
            entry["total_subtextures"] = len(rects)
            entry["even_subtextures"] = sum(1 for _, f in rects if not odd_fields(f))
        else:
            entry["atlas_format"] = "imagem_avulsa"
            entry["category"] = "imagem_avulsa"

        reasons = []
        if entry["odd_dimensions"]:
            reasons.append(f"dimensão ímpar ({w}x{h}): metade exata impossível sem arredondamento")
        if entry["total_subtextures"] is not None and entry["even_subtextures"] != entry["total_subtextures"]:
            reasons.append(
                f"coordenadas ímpares do atlas: apenas {entry['even_subtextures']} de "
                f"{entry['total_subtextures']} subtexturas têm todos os valores pares"
            )
        if entry["atlas_format"] == "imagem_avulsa":
            reasons.append("imagem avulsa sem metadados: a redução mudaria o tamanho renderizado sem compensação de escala auditável")
        entry["exclusion_reason"] = "; ".join(reasons) if reasons else None
        entries.append(entry)

    # Verificação de referências quebradas: imagePath de cada XML Sparrow deve existir ao lado do XML.
    broken = []
    for x in xml_files:
        txt = (REPO_ROOT / x).read_text(encoding="utf-8", errors="replace")
        for ip in re.findall(r'imagePath="([^"]+)"', txt):
            if not (REPO_ROOT / Path(x).parent / ip).exists():
                broken.append({"xml": x, "imagePath": ip})

    total_before = sum(e["original_bytes"] for e in entries)
    total_after = sum((e["resulting_bytes"] or e["original_bytes"]) for e in entries)
    summary = {
        "threshold_bytes": THRESHOLD_BYTES,
        "eligible_images_discovered": len(entries),
        "images_resized": sum(1 for e in entries if e["processing_status"] == "resized"),
        "xml_files_updated": 0,
        "images_excluded": sum(1 for e in entries if e["processing_status"] == "excluded"),
        "exclusions_by_reason": {
            "fora_do_escopo": sum(1 for e in entries if e["category"] == "fora_do_escopo"),
            "dimensao_impar": sum(1 for e in entries if e["odd_dimensions"]),
            "coordenadas_impares_do_atlas": sum(
                1 for e in entries if e["even_subtextures"] is not None and e["even_subtextures"] != e["total_subtextures"]
            ),
            "imagem_avulsa_sem_metadados": sum(1 for e in entries if e["atlas_format"] == "imagem_avulsa"),
        },
        "total_bytes_before": total_before,
        "total_bytes_after": total_after,
        "broken_xml_image_references": len(broken),
    }

    manifest = {
        "descricao": "Auditoria de imagens > 200 KB para a redução exata de 2x. Gerada por tools/image_downscale_audit.py.",
        "politica": {
            "fator": "exatamente 1/2 em largura e altura, sem arredondamento",
            "requisitos": [
                "dimensões da imagem pares",
                "todas as coordenadas do atlas pares (inteiros lidos pelo engine)",
                "recurso de jogo, não documentação ou fotografia",
            ],
        },
        "summary": summary,
        "broken_references": broken,
        "assets": entries,
    }

    if "--stdout" in sys.argv:
        print(json.dumps(summary, indent=2, ensure_ascii=False))
        return
    MANIFEST_PATH.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Manifesto gravado em {MANIFEST_PATH.relative_to(REPO_ROOT)}")
    print(json.dumps(summary, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
