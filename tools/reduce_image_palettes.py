#!/usr/bin/env python3
"""Reduce the colour palettes of the repository's raster assets.

This is a *maintenance* tool, not a game dependency.  It walks every tracked
raster image, requantizes PNGs to the smallest palette that still passes a
measured quality gate, writes an indexed PNG (1/2/4/8 bits per pixel, with a
``tRNS`` chunk for the alpha levels) and re-optimizes the deflate stream with
oxipng when it is available.  A file is replaced only when the result is
strictly smaller than the original; pixel dimensions never change, so Sparrow
XML / JSON atlas coordinates stay valid.  Besides PSNR/alpha/opaque-pixel
checks, an anti-banding gate (`changed_gt8`) rejects palettes that would
posterize smooth gradients (skies, blurs, hair shading).

Why indexed PNGs: almost all game art is flat-colour sprite work.  Storing it
as RGBA wastes both disk space and download bandwidth.  Reducing the palette
also lets the PNG use 4, 2 or even 1 bits per pixel instead of 8.

Caveat: OpenFL/Lime decodes PNGs into RGBA bitmaps at runtime, so a smaller
palette reduces *download/disk* size, not the decoded texture size.  Runtime
RAM is dominated by the pixel dimensions; see tools/IMAGE_DOWNSCALE.md for the
(separate) geometric downscale work.

Dependencies (install into any virtualenv, e.g. ``pip install -r
tools/requirements-image-palette.txt``):

    Pillow, numpy, imagequant (libimagequant wheels), oxipng (optional binary)

``imagequant`` is the quantizer; ``oxipng`` is used only as a lossless final
deflate/filter optimizer.  Without oxipng the tool still works using its own
built-in PNG encoder, just with slightly larger files.

Usage::

    python3 tools/reduce_image_palettes.py --dry-run
    python3 tools/reduce_image_palettes.py
    python3 tools/reduce_image_palettes.py --check
    python3 tools/reduce_image_palettes.py --profile safe
    python3 tools/reduce_image_palettes.py --paths assets/shared/images/characters/BOYFRIEND.png
    python3 tools/reduce_image_palettes.py --oxipng /path/to/oxipng --jobs 2

Report: ``tools/reports/palette-reduction-report.json``.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import math
import os
import shutil
import struct
import subprocess
import sys
import tempfile
import time
import zlib
from concurrent.futures import ProcessPoolExecutor, as_completed
from dataclasses import dataclass
from pathlib import Path

IMPORT_ERROR = ""
try:
    import numpy as np
    import imagequant
    from PIL import Image
except ImportError as exc:  # pragma: no cover - exercised only without deps
    IMPORT_ERROR = str(exc)

REPO_ROOT = Path(__file__).resolve().parent.parent
REPORT_PATH = REPO_ROOT / "tools" / "reports" / "palette-reduction-report.json"
PNG_SIG = b"\x89PNG\r\n\x1a\n"
RASTER_EXTS = {".png", ".jpg", ".jpeg", ".gif", ".bmp", ".webp", ".ico", ".svg", ".tga"}
JPEG_QUALITY = 78

# Quality gates.  All error measures are computed only on visible pixels
# (source alpha > 0 OR output alpha > 0) over the *whole* image, comparing the
# premultiplied RGB channels plus the alpha channel.
PROFILES = {
    #                 psnr  alpha_mae  alpha_max  opaque_bad  changed_gt8  halo_ratio
    "safe":       dict(psnr=36.0, alpha_mae=1.0, alpha_max=96,  opaque_bad=0.01, gt8=0.10, halo=0.0001),
    "balanced":   dict(psnr=31.0, alpha_mae=2.0, alpha_max=160, opaque_bad=0.05, gt8=0.15, halo=0.0005),
    "aggressive": dict(psnr=30.0, alpha_mae=3.0, alpha_max=192, opaque_bad=0.10, gt8=0.20, halo=0.0005),
}
# Palette sizes worth trying.  256 is the "requantize losslessly / reorder
# palette" candidate; 16/4/2 are the bit-depth boundaries of indexed PNGs.
PALETTE_TARGETS = (256, 128, 64, 32, 16, 8, 4, 2)


# --------------------------------------------------------------------------
# Low-level PNG writing (portable fallback + candidate size estimation)
# --------------------------------------------------------------------------

def _chunk(tag: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)


def png_ihdr(data: bytes) -> dict:
    """Parse IHDR and the first chunks of a PNG without decoding pixels."""
    info = {"width": 0, "height": 0, "bit_depth": 0, "color_type": 0,
            "interlace": 0, "apng": False, "palette_entries": 0}
    pos = 8
    while pos + 12 <= len(data):
        length = struct.unpack(">I", data[pos:pos + 4])[0]
        tag = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if tag == b"IHDR":
            w, h, bd, ct, _, _, il = struct.unpack(">IIBBBBB", body[:13])
            info.update(width=w, height=h, bit_depth=bd, color_type=ct, interlace=il)
        elif tag == b"PLTE":
            info["palette_entries"] = length // 3
        elif tag == b"acTL":
            info["apng"] = True
        elif tag == b"IDAT":
            break
    return info


def _pack_rows(indices: np.ndarray, bits: int) -> np.ndarray:
    """(h, w) uint8 indices -> (h, stride) packed scanlines."""
    h, w = indices.shape
    if bits == 8:
        return np.ascontiguousarray(indices, dtype=np.uint8)
    per_byte = 8 // bits
    stride = (w + per_byte - 1) // per_byte
    padded = np.zeros((h, stride * per_byte), dtype=np.uint8)
    padded[:, :w] = indices
    shaped = padded.reshape(h, stride, per_byte)
    out = np.zeros((h, stride), dtype=np.uint8)
    for i in range(per_byte):
        out |= shaped[:, :, i] << (8 - bits * (i + 1))
    return out


def _filter_scanlines(rows: np.ndarray) -> bytes:
    """Best PNG delta filter per scanline, libpng's sum-of-abs heuristic."""
    h, stride = rows.shape
    raw = bytearray()
    prev = np.zeros(stride, dtype=np.uint8)
    for y in range(h):
        row = rows[y]
        cur = row.astype(np.int16)
        left = np.zeros(stride, dtype=np.int16)
        left[1:] = row[:-1]
        up = prev.astype(np.int16)
        upleft = np.zeros(stride, dtype=np.int16)
        upleft[1:] = prev[:-1]
        p = left + up - upleft
        pa, pb, pc = np.abs(p - left), np.abs(p - up), np.abs(p - upleft)
        pred = np.where(pa <= pb, np.where(pa <= pc, left, upleft),
                        np.where(pb <= pc, up, upleft))
        candidates = (cur, cur - left, cur - up, cur - ((left + up) // 2), cur - pred)
        best_i, best, best_score = 0, None, None
        for i, cand in enumerate(candidates):
            filt = (cand & 0xFF).astype(np.uint8)
            score = int(np.abs(filt.astype(np.int8).astype(np.int16)).sum())
            if best_score is None or score < best_score:
                best_score, best, best_i = score, filt, i
        raw.append(best_i)
        raw.extend(best.tobytes())
        prev = row
    return bytes(raw)


def encode_paletted(pal: "Palette") -> bytes:
    """Encode a Palette as an indexed PNG (no external encoder required)."""
    bits = pal.bits
    rows = _pack_rows(pal.indices, bits)
    idat = zlib.compress(_filter_scanlines(rows), 9)
    out = bytearray(PNG_SIG)
    out += _chunk(b"IHDR", struct.pack(">IIBBBBB", pal.w, pal.h, bits, 3, 0, 0, 0))
    out += _chunk(b"PLTE", pal.rgb)
    if pal.alpha is not None:
        trns = bytes(pal.alpha)
        while trns and trns[-1] == 255:
            trns = trns[:-1]
        if trns:
            out += _chunk(b"tRNS", trns)
    out += _chunk(b"IDAT", idat)
    out += _chunk(b"IEND", b"")
    return bytes(out)


# --------------------------------------------------------------------------
# Palette representation
# --------------------------------------------------------------------------

@dataclass
class Palette:
    w: int
    h: int
    indices: np.ndarray          # (h, w) uint8, values < len(rgb)//3
    rgb: bytes                   # RGB triplets
    alpha: bytes | None          # one alpha byte per palette entry, or None

    @property
    def ncolors(self) -> int:
        return len(self.rgb) // 3

    @property
    def bits(self) -> int:
        n = self.ncolors
        return 1 if n <= 2 else 2 if n <= 4 else 4 if n <= 16 else 8

    @classmethod
    def from_quantized(cls, q: Image.Image) -> "Palette":
        """imagequant returns a P image with an RGBA palette (alpha is *not*
        in ``info['transparency']``); read the palette with rawmode='RGBA'."""
        pal_rgba = q.getpalette("RGBA")
        if pal_rgba is None:  # pragma: no cover - defensive
            raise ValueError("quantizer returned no RGBA palette")
        entries = np.asarray(pal_rgba, dtype=np.uint8).reshape(-1, 4)
        idx = np.asarray(q, dtype=np.uint8)
        counts = np.bincount(idx.ravel(), minlength=len(entries))
        used = np.flatnonzero(counts)
        lut = np.zeros(len(entries), dtype=np.uint8)
        lut[used] = np.arange(len(used), dtype=np.uint8)
        new_idx = np.ascontiguousarray(lut[idx])
        rgb = entries[used, :3].tobytes()
        alpha_arr = entries[used, 3]
        alpha = alpha_arr.tobytes() if np.any(alpha_arr != 255) else None
        return cls(q.width, q.height, new_idx, rgb, alpha)

    @classmethod
    def from_p_mode(cls, im: Image.Image) -> "Palette":
        """Losslessly compact an already-indexed PNG (used for reports/tests)."""
        idx = np.asarray(im, dtype=np.uint8)
        raw_pal = im.getpalette() or []
        n = len(raw_pal) // 3
        tr = im.info.get("transparency")
        if isinstance(tr, bytes):
            alpha = list(tr[:n]) + [255] * max(0, n - len(tr))
        elif isinstance(tr, int):
            alpha = [0 if i == tr else 255 for i in range(n)]
        else:
            alpha = None
        pal = np.asarray(raw_pal, dtype=np.uint8).reshape(-1, 3)
        counts = np.bincount(idx.ravel(), minlength=len(pal))
        used = np.flatnonzero(counts)
        lut = np.zeros(len(pal), dtype=np.uint8)
        lut[used] = np.arange(len(used), dtype=np.uint8)
        new_idx = np.ascontiguousarray(lut[idx])
        rgb = pal[used].tobytes()
        new_alpha = None
        if alpha is not None:
            arr = np.asarray(alpha, dtype=np.uint8)[used]
            new_alpha = arr.tobytes() if np.any(arr != 255) else None
        return cls(im.width, im.height, new_idx, rgb, new_alpha)

    def to_pil(self) -> Image.Image:
        im = Image.fromarray(self.indices, mode="P")
        im.putpalette(self.rgb)
        if self.alpha is not None:
            im.info["transparency"] = self.alpha
        return im

    def to_png(self) -> bytes:
        """Pillow's encoder (C, fast); oxipng polishes the deflate stream later."""
        buf = io.BytesIO()
        im = self.to_pil()
        try:
            im.save(buf, format="PNG", bits=self.bits, optimize=True, compress_level=9)
        except Exception:  # pragma: no cover - older Pillow without 'bits'
            im.save(buf, format="PNG", optimize=True, compress_level=9)
        return buf.getvalue()

    def rgba_array(self) -> np.ndarray:
        return np.asarray(self.to_pil().convert("RGBA"))


def quantize_fast(rgba: Image.Image, arr: np.ndarray, target: int, dithering: float) -> Image.Image:
    """imagequant with raw bytes (avoids its slow Python pixel loop on big art)."""
    h, w = arr.shape[:2]
    indices, palette = imagequant.quantize_raw_rgba_bytes(
        arr.tobytes(), w, h, dithering_level=dithering, max_colors=target)
    q = Image.frombytes("P", (w, h), indices)
    q.putpalette(palette, rawmode="RGBA")
    return q


def decoded_matches(png_bytes: bytes, pal: Palette) -> bool:
    try:
        dec = Image.open(io.BytesIO(png_bytes))
        if dec.size != (pal.w, pal.h):
            return False
        return np.array_equal(np.asarray(dec.convert("RGBA")), pal.rgba_array())
    except Exception:
        return False


# --------------------------------------------------------------------------
# Quality gate
# --------------------------------------------------------------------------

def quality_metrics(src: np.ndarray, out: np.ndarray) -> dict:
    """Compare premultiplied RGBA on visible pixels; chunked to bound memory."""
    h, w = src.shape[:2]
    total = h * w
    se = 0.0
    alpha_abs_sum = 0
    alpha_max = 0
    halo = 0
    lost = 0
    visible = 0
    opaque_total = 0
    opaque_bad = 0
    changed_gt8 = 0
    rows = max(1, (1 << 21) // max(1, w))  # <= ~2M pixels per chunk
    for y0 in range(0, h, rows):
        a = src[y0:y0 + rows]
        b = out[y0:y0 + rows]
        sa = a[:, :, 3].astype(np.int16)
        qa = b[:, :, 3].astype(np.int16)
        dalpha = np.abs(sa - qa)
        vis = (sa > 0) | (qa > 0)
        nvis = int(vis.sum())
        visible += nvis
        if nvis:
            alpha_abs_sum += int(dalpha[vis].sum())
            alpha_max = max(alpha_max, int(dalpha[vis].max()))
            aa = a[vis].astype(np.float32)
            bb = b[vis].astype(np.float32)
            pa = aa[:, :3] * (aa[:, 3:4] / 255.0)
            pb = bb[:, :3] * (bb[:, 3:4] / 255.0)
            d = pa - pb
            se += float(np.sum(d * d))
            da = aa[:, 3] - bb[:, 3]
            se += float(np.sum(da * da))
            # Banding guard: fraction of visible pixels with a perceptible
            # (>8) shift.  Smooth gradients fail here even when PSNR looks
            # acceptable and the >24 "opaque_bad" count stays tiny.
            per_pixel = np.maximum(np.abs(d).max(axis=1), np.abs(da))
            changed_gt8 += int((per_pixel > 8).sum())
        halo += int(((sa == 0) & (qa > 32)).sum())
        lost += int(((sa >= 64) & (qa < 16)).sum())
        op = sa == 255
        nop = int(op.sum())
        opaque_total += nop
        if nop:
            diff = np.abs(a[:, :, :3].astype(np.int16) - b[:, :, :3].astype(np.int16))
            opaque_bad += int((diff.max(axis=2)[op] > 24).sum())
    mse = se / (visible * 4) if visible else 0.0
    psnr = 10 * math.log10(255.0 ** 2 / mse) if mse > 0 else 99.0
    return {
        "psnr": round(psnr, 2),
        "alpha_mae": round(alpha_abs_sum / visible, 4) if visible else 0.0,
        "alpha_max": alpha_max,
        "halo": halo,
        "lost": lost,
        "opaque_bad": round(opaque_bad / opaque_total, 5) if opaque_total else 0.0,
        "changed_gt8": round(changed_gt8 / visible, 5) if visible else 0.0,
        "visible": visible,
        "total": total,
    }


def quality_gate(m: dict, limits: dict) -> tuple[bool, str]:
    if m["psnr"] < limits["psnr"]:
        return False, "psnr %.2f < %.1f" % (m["psnr"], limits["psnr"])
    if m["alpha_mae"] > limits["alpha_mae"]:
        return False, "alpha_mae %.2f > %.1f" % (m["alpha_mae"], limits["alpha_mae"])
    if m["alpha_max"] > limits["alpha_max"]:
        return False, "alpha_max %d > %d" % (m["alpha_max"], limits["alpha_max"])
    if m["opaque_bad"] > limits["opaque_bad"]:
        return False, "opaque_bad %.4f > %.2f" % (m["opaque_bad"], limits["opaque_bad"])
    if m.get("changed_gt8", 0.0) > limits["gt8"]:
        return False, "changed_gt8 %.4f > %.2f" % (m.get("changed_gt8", 0.0), limits["gt8"])
    if m["lost"] != 0:
        return False, "lost %d visible pixels" % m["lost"]
    halo_max = max(16, int(m["total"] * limits["halo"]))
    if m["halo"] > halo_max:
        return False, "halo %d > %d" % (m["halo"], halo_max)
    return True, "ok"


# --------------------------------------------------------------------------
# External lossless optimizer
# --------------------------------------------------------------------------

def oxipng_optimize(data: bytes, oxipng: str | None, size_hint: int, tmpdir: Path) -> bytes:
    if not oxipng:
        return data
    inp = tmpdir / ("oxi_%d.png" % os.getpid())
    out = tmpdir / ("oxi_%d.out.png" % os.getpid())
    inp.write_bytes(data)
    if out.exists():
        out.unlink()
    level = 1 if size_hint > 1 << 20 else 2 if size_hint > 200_000 else 3
    timeout = 8 if level == 1 else 5 if level == 2 else 3
    args = [oxipng, "-o", str(level), "-D", "--nc", "--strip", "safe", "--quiet",
            "--timeout", str(timeout), "-t", "1", "--out", str(out), str(inp)]
    try:
        res = subprocess.run(args, capture_output=True, timeout=timeout + 25)
        if res.returncode == 0 and out.exists():
            candidate = out.read_bytes()
            if len(candidate) < len(data):
                return candidate
    except (subprocess.TimeoutExpired, OSError):
        pass
    return data


# --------------------------------------------------------------------------
# Per-file processing
# --------------------------------------------------------------------------

def sniff(path: Path) -> str:
    with path.open("rb") as f:
        head = f.read(32)
    if head[:8] == PNG_SIG:
        return "png"
    if head[:3] == b"\xff\xd8\xff":
        return "jpeg"
    if head[:6] in (b"GIF87a", b"GIF89a"):
        return "gif"
    if head[:4] == b"RIFF" and head[8:12] == b"WEBP":
        return "webp"
    if head[:4] == b"\x00\x00\x01\x00":
        return "ico"
    if b"<svg" in head or b"<?xml" in head:
        return "svg"
    return "unknown"


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def process_png(path: Path, data: bytes, cfg: dict, tmpdir: Path) -> dict:
    info = png_ihdr(data)
    result = {
        "path": str(path.relative_to(REPO_ROOT)),
        "kind": "png",
        "bytes_before": len(data),
        "bytes_after": len(data),
        "sha256_before": sha256(data),
        "sha256_after": sha256(data),
        "width": info["width"], "height": info["height"],
        "palette_before": info["palette_entries"] if info["color_type"] == 3 else None,
        "palette_after": info["palette_entries"] if info["color_type"] == 3 else None,
        "bits_before": info["bit_depth"], "bits_after": info["bit_depth"],
        "changed": False, "reason": "", "chosen": None, "quality": None,
    }
    if info["apng"]:
        result["reason"] = "animated PNG: quantization would flatten the frames"
        return result
    try:
        src = Image.open(io.BytesIO(data))
        src.load()
    except Exception as exc:
        result["reason"] = "cannot decode PNG: %s" % exc
        return result
    rgba = src.convert("RGBA")
    src_arr = np.ascontiguousarray(np.asarray(rgba))
    if src.mode == "P":
        n_unique = int((np.bincount(np.asarray(src, dtype=np.uint8).ravel(), minlength=256) > 0).sum())
    else:
        n_unique = int(np.unique(src_arr.view(np.uint32).reshape(-1)).size)
    result["unique_colors_before"] = n_unique
    dithering = 0.0 if n_unique <= 256 else 0.8
    targets = sorted(set([256] + [c for c in PALETTE_TARGETS if c < n_unique]), reverse=True)

    passing = []
    consecutive_rejects = 0
    for target in targets:
        try:
            q = quantize_fast(rgba, src_arr, target, dithering)
        except RuntimeError as exc:
            result.setdefault("notes", []).append("q%d: %s" % (target, exc))
            consecutive_rejects += 1
            if consecutive_rejects >= 3:
                break
            continue
        pal = Palette.from_quantized(q)
        q_arr = pal.rgba_array()
        # A palette at least as large as the source's colour count is expected
        # to be lossless; a byte comparison is much cheaper than full metrics.
        if target >= n_unique and np.array_equal(q_arr, src_arr):
            m = {"psnr": 99.0, "alpha_mae": 0.0, "alpha_max": 0, "halo": 0,
                 "lost": 0, "opaque_bad": 0.0, "changed_gt8": 0.0,
                 "visible": int((src_arr[:, :, 3] > 0).sum()),
                 "total": src_arr.shape[0] * src_arr.shape[1]}
        else:
            m = quality_metrics(src_arr, q_arr)
        ok, why = quality_gate(m, cfg["limits"])
        if not ok:
            result.setdefault("rejected", []).append({"target": target, "reason": why, "psnr": m["psnr"]})
            consecutive_rejects += 1
            # Smaller palettes are monotonically worse; stop after 3 failures.
            if consecutive_rejects >= 3 or m["lost"] > 0 or m["alpha_mae"] > 2 * cfg["limits"]["alpha_mae"]:
                break
            continue
        consecutive_rejects = 0
        encoded = pal.to_png()
        if not decoded_matches(encoded, pal):  # pragma: no cover - safety net
            result.setdefault("notes", []).append("q%d: encoder round-trip failed" % target)
            continue
        passing.append((len(encoded), target, pal, m, encoded))

    if not passing:
        result["reason"] = "no palette passed the quality gate"
        return result

    # oxipng can change the ranking, so optimize the two smallest estimates
    # (one for very large sheets, where a second trial is expensive).
    passing.sort(key=lambda item: item[0])
    finalists = passing[:1] if len(data) > 1 << 20 else passing[:2]
    best = None
    for est, target, pal, m, encoded in finalists:
        final = oxipng_optimize(encoded, cfg["oxipng"], est, tmpdir)
        if not decoded_matches(final, pal):
            final = encoded  # oxipng changed the image: fall back to our encoder
        if len(final) < len(data) and (best is None or len(final) < len(best[0])):
            best = (final, target, pal, m)
    if best is None:
        result["reason"] = "all candidates were larger than the original"
        return result

    final, target, pal, m = best
    final_info = png_ihdr(final)
    result.update(
        bytes_after=len(final), sha256_after=sha256(final),
        palette_after=(final_info["palette_entries"] if final_info["color_type"] == 3 else None),
        bits_after=final_info["bit_depth"],
        changed=True, reason="palette reduced", chosen="q%d" % target,
        chosen_colors=pal.ncolors, quality=m,
    )
    if not cfg["dry_run"]:
        dest = tmpdir / (sha256(data) + ".png")
        dest.write_bytes(final)
        result["staged"] = str(dest)
    return result


def process_jpeg(path: Path, data: bytes, cfg: dict, tmpdir: Path) -> dict:
    result = {
        "path": str(path.relative_to(REPO_ROOT)), "kind": "jpeg",
        "bytes_before": len(data), "bytes_after": len(data),
        "sha256_before": sha256(data), "sha256_after": sha256(data),
        "changed": False, "reason": "",
    }
    try:
        im = Image.open(io.BytesIO(data))
        im.load()
        out = io.BytesIO()
        im.convert("RGB").save(out, format="JPEG", quality=JPEG_QUALITY,
                               optimize=True, progressive=True, subsampling=2)
        final = out.getvalue()
    except Exception as exc:
        result["reason"] = "cannot re-encode JPEG: %s" % exc
        return result
    if len(final) >= len(data):
        result["reason"] = "re-encoded JPEG was not smaller (already well compressed)"
        return result
    # Guard: dimensions must not change.
    if Image.open(io.BytesIO(final)).size != im.size:  # pragma: no cover
        result["reason"] = "re-encoded JPEG changed dimensions"
        return result
    result.update(bytes_after=len(final), sha256_after=sha256(final),
                  changed=True, reason="JPEG re-encoded at quality %d" % JPEG_QUALITY)
    if not cfg["dry_run"]:
        dest = tmpdir / (sha256(data) + ".jpg")
        dest.write_bytes(final)
        result["staged"] = str(dest)
    return result


def process_one(task: tuple[str, dict, str]) -> dict:
    rel, cfg, tmpdir_s = task
    tmpdir = Path(tmpdir_s)
    path = REPO_ROOT / rel
    data = path.read_bytes()
    kind = sniff(path)
    try:
        if kind == "png":
            return process_png(path, data, cfg, tmpdir)
        if kind == "jpeg":
            return process_jpeg(path, data, cfg, tmpdir)
        return {
            "path": rel, "kind": kind, "bytes_before": len(data),
            "bytes_after": len(data), "sha256_before": sha256(data),
            "sha256_after": sha256(data), "changed": False,
            "reason": {
                "gif": "animated GIF: lossless re-optimization grew it; left untouched",
                "webp": "WebP payload (even under a .png name): already compact; left untouched",
                "ico": "icon container: no palette to reduce; left untouched",
                "svg": "vector asset: no raster palette; left untouched",
            }.get(kind, "unrecognized raster format; left untouched"),
        }
    except Exception as exc:  # keep one bad file from aborting the whole run
        return {
            "path": rel, "kind": kind, "bytes_before": len(data),
            "bytes_after": len(data), "sha256_before": sha256(data),
            "sha256_after": sha256(data), "changed": False,
            "reason": "error: %s: %s" % (type(exc).__name__, exc),
        }


# --------------------------------------------------------------------------
# Repository / report / CLI
# --------------------------------------------------------------------------

def tracked_images(root: Path, paths: list[str] | None) -> list[str]:
    if paths:
        out = []
        for raw in paths:
            p = Path(raw)
            if not p.is_absolute():
                p = root / p
            if p.is_file():
                out.append(str(p.relative_to(root)))
        return sorted(set(out))
    raw = subprocess.check_output(["git", "ls-files", "-z"], cwd=root)
    return sorted({p.decode("utf-8", "surrogateescape") for p in raw.split(b"\0")
                   if p and Path(p.decode("utf-8", "surrogateescape")).suffix.lower() in RASTER_EXTS})


def build_report(results: list[dict], cfg: dict) -> dict:
    changed = [r for r in results if r["changed"]]
    before = sum(r["bytes_before"] for r in results)
    after = sum(r["bytes_after"] for r in results)
    pal_before = [r["palette_before"] for r in changed if r.get("palette_before")]
    pal_after = [r["palette_after"] for r in changed if r.get("palette_after")]
    return {
        "description": "Palette reduction of the repository's raster assets (tools/reduce_image_palettes.py).",
        "settings": {
            "profile": cfg["profile"], "limits": cfg["limits"],
            "jpeg_quality": JPEG_QUALITY,
            "oxipng": bool(cfg["oxipng"]), "dry_run": cfg["dry_run"],
            "palette_targets": list(PALETTE_TARGETS),
        },
        "summary": {
            "files_scanned": len(results),
            "files_changed": len(changed),
            "files_unchanged": len(results) - len(changed),
            "png_scanned": sum(1 for r in results if r["kind"] == "png"),
            "jpeg_scanned": sum(1 for r in results if r["kind"] == "jpeg"),
            "bytes_before": before, "bytes_after": after,
            "bytes_saved": before - after,
            "reduction_percent": round(100.0 * (before - after) / before, 2) if before else 0.0,
            "avg_palette_before": round(sum(pal_before) / len(pal_before), 1) if pal_before else None,
            "avg_palette_after": round(sum(pal_after) / len(pal_after), 1) if pal_after else None,
        },
        "assets": results,
    }


def check_report(report_path: Path) -> int:
    if not report_path.is_file():
        sys.stderr.write("Report not found: %s\n" % report_path)
        return 1
    report = json.loads(report_path.read_text())
    errors = []
    for asset in report.get("assets", []):
        path = REPO_ROOT / asset["path"]
        if not path.is_file():
            errors.append("missing file: %s" % asset["path"])
            continue
        data = path.read_bytes()
        if len(data) != asset["bytes_after"] or sha256(data) != asset["sha256_after"]:
            errors.append("size/hash mismatch: %s" % asset["path"])
            continue
        # Only PNG/JPEG payloads are decodable by Pillow; SVG/ICO/WebP/GIF
        # are recorded in the report as "skipped" and keep their exact bytes.
        if asset.get("kind") in ("png", "jpeg") or sniff(path) in ("png", "jpeg"):
            try:
                im = Image.open(io.BytesIO(data))
                im.load()
            except Exception as exc:
                errors.append("cannot decode %s: %s" % (asset["path"], exc))
                continue
            if asset.get("width") and im.size != (asset["width"], asset["height"]):
                errors.append("dimensions changed: %s" % asset["path"])
        if asset.get("changed") and asset["kind"] == "png":
            if png_ihdr(data)["color_type"] != 3:
                errors.append("output is not an indexed PNG: %s" % asset["path"])
    if errors:
        for e in errors:
            sys.stderr.write("FAIL %s\n" % e)
        return 1
    s = report["summary"]
    print("OK: %d assets, %d changed, %d -> %d bytes (%.2f%% smaller)" %
          (s["files_scanned"], s["files_changed"], s["bytes_before"],
           s["bytes_after"], s["reduction_percent"]))
    return 0


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dry-run", action="store_true", help="measure only; do not replace any file")
    ap.add_argument("--check", action="store_true", help="validate the report against the files on disk")
    ap.add_argument("--root", default=str(REPO_ROOT), help="repository root (default: parent of tools/)")
    ap.add_argument("--paths", nargs="+", help="process only these files instead of all tracked images")
    ap.add_argument("--profile", choices=sorted(PROFILES), default="balanced",
                    help="quality gate (default: balanced; use aggressive for max savings)")
    ap.add_argument("--jobs", type=int, default=max(1, min(4, (os.cpu_count() or 1))),
                    help="parallel workers (default: up to 4)")
    ap.add_argument("--oxipng", default=os.environ.get("OXIPNG") or shutil.which("oxipng"),
                    help="path to the oxipng binary (default: $OXIPNG or oxipng in PATH)")
    ap.add_argument("--report", default=str(REPORT_PATH), help="report path")
    return ap.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    if IMPORT_ERROR:  # pragma: no cover - only on machines without the deps
        sys.stderr.write(
            "Missing Python dependency: %s\n"
            "Install with: pip install -r tools/requirements-image-palette.txt\n" % IMPORT_ERROR
        )
        return 2
    report_path = Path(args.report)
    if args.check:
        return check_report(report_path)
    cfg = {
        "profile": args.profile,
        "limits": PROFILES[args.profile],
        "oxipng": args.oxipng,
        "dry_run": args.dry_run,
    }
    root = Path(args.root).resolve()
    files = tracked_images(root, args.paths)
    if not files:
        print("No images found.")
        return 0
    print("Profile: %s | limits: %s" % (args.profile, cfg["limits"]))
    print("oxipng: %s" % (args.oxipng or "not found (using the built-in PNG encoder)"))
    print("Files: %d | jobs: %d | %s" %
          (len(files), args.jobs, "DRY RUN" if args.dry_run else "APPLY"))
    start = time.time()
    tmpdir_obj = tempfile.TemporaryDirectory(prefix="phoenix-palette-")
    tmpdir = Path(tmpdir_obj.name)
    tasks = [(rel, cfg, str(tmpdir)) for rel in files]
    results: list[dict] = []
    done = 0
    with ProcessPoolExecutor(max_workers=args.jobs) as pool:
        futures = {pool.submit(process_one, t): t[0] for t in tasks}
        for fut in as_completed(futures):
            rel = futures[fut]
            res = fut.result()
            results.append(res)
            done += 1
            if res["changed"]:
                print("[%d/%d] %-70s %8d -> %8d B (%5.1f%%) %s" %
                      (done, len(files), rel, res["bytes_before"], res["bytes_after"],
                       100.0 * (1 - res["bytes_after"] / res["bytes_before"]), res.get("chosen", "")),
                      flush=True)
            elif done % 50 == 0:
                print("[%d/%d] ..." % (done, len(files)), flush=True)

    results.sort(key=lambda r: r["path"])
    # Apply staged replacements atomically, preserving timestamps.
    if not args.dry_run:
        for res in results:
            if not res.get("staged"):
                continue
            staged = Path(res.pop("staged"))
            dest = REPO_ROOT / res["path"]
            stat = dest.stat()
            tmp_dest = dest.with_name(dest.name + ".palette-tmp")
            shutil.copyfile(staged, tmp_dest)
            os.replace(tmp_dest, dest)
            os.utime(dest, ns=(stat.st_atime_ns, stat.st_mtime_ns))

    report = build_report(results, cfg)
    if not args.dry_run:
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
    s = report["summary"]
    print("\nScanned %d images | changed %d | %d -> %d bytes | saved %d bytes (%.2f%%) in %.1fs" %
          (s["files_scanned"], s["files_changed"], s["bytes_before"], s["bytes_after"],
           s["bytes_saved"], s["reduction_percent"], time.time() - start))
    if args.dry_run:
        print("Dry run: no files were replaced and the report was not written.")
    else:
        print("Report: %s" % report_path)
    tmpdir_obj.cleanup()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
