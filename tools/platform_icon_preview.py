#!/usr/bin/env python3
"""Render the platform watermark badges straight from the Haxe artwork.

``source/backend/PlatformIcons.hx`` is the single source of truth for the
glyphs the engine draws on top of the version watermark. This script parses
that file and rasterises the same shapes with the same three-pass recipe
(dark silhouette, white fill, dark details) so artwork changes can be eyeballed
without a full ``lime test`` cycle.

Usage::

    python3 tools/platform_icon_preview.py                       # sheet to tools/reports/
    python3 tools/platform_icon_preview.py --sizes 16 24 48 96
    python3 tools/platform_icon_preview.py --out /tmp/badges.png --background 1a1a1a

Rendering needs Pillow (``pip install Pillow``); the parser underneath is
plain stdlib and is reused by ``tests/test_platform_icons.py``.
"""

from __future__ import annotations

import argparse
import math
import re
import sys
from pathlib import Path
from typing import Dict, List, Sequence, Tuple

REPO_ROOT = Path(__file__).resolve().parent.parent
HAXE_SOURCE = REPO_ROOT / "source" / "backend" / "PlatformIcons.hx"

Point = Tuple[float, float]

# ---------------------------------------------------------------------------
# Parsing the Haxe artwork
# ---------------------------------------------------------------------------

_TOKEN = re.compile(r"\s*(?:(-?\d+(?:\.\d+)?)|([A-Za-z_][A-Za-z0-9_]*)|(.))")
_GLYPH_FIELD = re.compile(r"static\s+final\s+([A-Z0-9_]+)_GLYPH\s*:\s*Glyph\s*=\s*", re.MULTILINE)
_CONSTANT = re.compile(r"public\s+static\s+inline\s+var\s+([A-Z0-9_]+)\s*:\s*(?:Float|Int)\s*=\s*(-?\d+(?:\.\d+)?)\s*;")
_GLYPH_CASE = re.compile(r"case\s+((?:PlatformKind\.[A-Z]+\s*\|?\s*)+):\s*([A-Z0-9_]+)_GLYPH\s*;")
_DEFAULT_CASE = re.compile(r"default\s*:\s*([A-Z0-9_]+)_GLYPH\s*;")

INKS = {"body": "BODY", "detail": "DETAIL", "mark": "MARK"}


class Part:
    """One painted shape of a glyph."""

    def __init__(self, ink: str, shape: str, args: Sequence):
        self.ink = ink
        self.shape = shape
        self.args = list(args)

    def __repr__(self) -> str:  # pragma: no cover - debugging aid
        return f"Part({self.ink}, {self.shape}, {self.args})"


def strip_comments(text: str) -> str:
    """Drop // and /* */ comments. The artwork block contains no strings."""
    text = re.sub(r"/\*.*?\*/", " ", text, flags=re.DOTALL)
    return re.sub(r"//[^\n]*", " ", text)


def _tokenize(text: str) -> List[str]:
    tokens: List[str] = []
    index = 0
    while index < len(text):
        match = _TOKEN.match(text, index)
        if match is None or match.end() == index:
            break
        index = match.end()
        number, name, symbol = match.groups()
        token = number or name or symbol
        if token is not None and not token.isspace():
            tokens.append(token)
    return tokens


def _parse_value(tokens: List[str], position: int):
    """Parse a number, an `Ident(...)` call or a `[...]` list."""
    token = tokens[position]
    if token == "[":
        items = []
        position += 1
        while tokens[position] != "]":
            value, position = _parse_value(tokens, position)
            items.append(value)
            if tokens[position] == ",":
                position += 1
        return items, position + 1
    if re.fullmatch(r"-?\d+(\.\d+)?", token):
        return float(token), position + 1
    if position + 1 < len(tokens) and tokens[position + 1] == "(":
        args = []
        position += 2
        while tokens[position] != ")":
            value, position = _parse_value(tokens, position)
            args.append(value)
            if tokens[position] == ",":
                position += 1
        return (token, args), position + 1
    return token, position + 1


def _balanced_block(text: str, start: int) -> Tuple[str, int]:
    """Return the `[...]` literal starting at `start` and the index after it."""
    depth = 0
    for index in range(start, len(text)):
        char = text[index]
        if char == "[":
            depth += 1
        elif char == "]":
            depth -= 1
            if depth == 0:
                return text[start : index + 1], index + 1
    raise ValueError("unterminated glyph literal")


def load_source(path: Path = HAXE_SOURCE) -> str:
    return path.read_text(encoding="utf-8-sig")


def parse_constants(source: str) -> Dict[str, float]:
    """The sizing/outline constants declared in the Haxe class."""
    return {name: float(value) for name, value in _CONSTANT.findall(source)}


def parse_glyphs(source: str) -> Dict[str, List[Part]]:
    """Every `NAME_GLYPH` artwork block, keyed by its NAME."""
    clean = strip_comments(source)
    glyphs: Dict[str, List[Part]] = {}
    for match in _GLYPH_FIELD.finditer(clean):
        literal, _ = _balanced_block(clean, clean.index("[", match.end()))
        tokens = _tokenize(literal)
        value, _ = _parse_value(tokens, 0)
        parts: List[Part] = []
        for item in value:
            assert isinstance(item, tuple), f"unexpected glyph entry: {item!r}"
            call, args = item
            ink = INKS.get(call)
            assert ink is not None, f"unknown ink helper: {call}"
            assert len(args) == 1 and isinstance(args[0], tuple), f"bad part: {item!r}"
            shape, shape_args = args[0]
            parts.append(Part(ink, shape, shape_args))
        glyphs[match.group(1)] = parts
    return glyphs


def parse_kind_map(source: str) -> Dict[str, str]:
    """Which artwork each `PlatformKind` resolves to, from `glyph()`."""
    clean = strip_comments(source)
    mapping: Dict[str, str] = {}
    for kinds, glyph in _GLYPH_CASE.findall(clean):
        for kind in re.findall(r"PlatformKind\.([A-Z]+)", kinds):
            mapping[kind] = glyph
    default = _DEFAULT_CASE.search(clean)
    if default:
        mapping.setdefault("UNKNOWN", default.group(1))
    return mapping


# ---------------------------------------------------------------------------
# Geometry: flatten every shape to polylines on the 0..100 grid
# ---------------------------------------------------------------------------

CURVE_STEPS = 24
ARC_STEPS = 24


def _quadratic(start: Point, control: Point, end: Point) -> List[Point]:
    points = []
    for step in range(1, CURVE_STEPS + 1):
        t = step / CURVE_STEPS
        inv = 1 - t
        points.append(
            (
                inv * inv * start[0] + 2 * inv * t * control[0] + t * t * end[0],
                inv * inv * start[1] + 2 * inv * t * control[1] + t * t * end[1],
            )
        )
    return points


def _commands_to_points(commands: Sequence) -> List[Point]:
    points: List[Point] = []
    for command in commands:
        name, args = command
        if name == "Move":
            points.append((args[0], args[1]))
        elif name == "Line":
            points.append((args[0], args[1]))
        elif name == "Curve":
            start = points[-1] if points else (args[2], args[3])
            points.extend(_quadratic(start, (args[0], args[1]), (args[2], args[3])))
        else:  # pragma: no cover - guarded by the tests
            raise ValueError(f"unknown path command: {name}")
    return points


def _ellipse_points(cx: float, cy: float, rx: float, ry: float) -> List[Point]:
    steps = ARC_STEPS * 2
    return [
        (cx + rx * math.cos(2 * math.pi * step / steps), cy + ry * math.sin(2 * math.pi * step / steps))
        for step in range(steps)
    ]


def _round_rect_points(x: float, y: float, width: float, height: float, radius: float) -> List[Point]:
    radius = min(radius, width / 2, height / 2)
    corners = [
        (x + width - radius, y + height - radius, 0),
        (x + radius, y + height - radius, 90),
        (x + radius, y + radius, 180),
        (x + width - radius, y + radius, 270),
    ]
    points: List[Point] = []
    for cx, cy, start in corners:
        for step in range(ARC_STEPS // 4 + 1):
            angle = math.radians(start + step * 90 / (ARC_STEPS // 4))
            points.append((cx + radius * math.cos(angle), cy + radius * math.sin(angle)))
    return points


def outline(part: Part) -> Tuple[List[Point], bool]:
    """Flatten a part to (points, closed) on the glyph grid."""
    shape, args = part.shape, part.args
    if shape == "Rect":
        x, y, width, height = args
        return [(x, y), (x + width, y), (x + width, y + height), (x, y + height)], True
    if shape == "RoundRect":
        return _round_rect_points(*args), True
    if shape == "Circle":
        x, y, radius = args
        return _ellipse_points(x, y, radius, radius), True
    if shape == "Ellipse":
        x, y, rx, ry = args
        return _ellipse_points(x, y, rx, ry), True
    if shape == "Polygon":
        flat = args[0]
        return [(flat[i], flat[i + 1]) for i in range(0, len(flat), 2)], True
    if shape == "Contour":
        return _commands_to_points(args[0]), True
    if shape == "Stroke":
        return _commands_to_points(args[0]), False
    raise ValueError(f"unknown shape: {shape}")


def bounds(parts: Sequence[Part]) -> Tuple[float, float, float, float]:
    xs: List[float] = []
    ys: List[float] = []
    for part in parts:
        points, _ = outline(part)
        xs.extend(point[0] for point in points)
        ys.extend(point[1] for point in points)
    return min(xs), min(ys), max(xs), max(ys)


# ---------------------------------------------------------------------------
# Rasterising (Pillow)
# ---------------------------------------------------------------------------


def _draw_shape(draw, points: Sequence[Point], closed: bool, fill, stroke, width: float) -> None:
    from PIL import ImageDraw  # noqa: F401  (imported for typing/readability)

    if fill is not None and closed and len(points) >= 3:
        draw.polygon(list(points), fill=fill)
    if stroke is None or width <= 0:
        return
    line = list(points) + ([points[0]] if closed else [])
    draw.line(line, fill=stroke, width=max(1, int(round(width))), joint="curve")
    radius = width / 2
    for point in line:
        draw.ellipse(
            [point[0] - radius, point[1] - radius, point[0] + radius, point[1] + radius],
            fill=stroke,
        )


def render(parts: Sequence[Part], size: int, constants: Dict[str, float], supersample: int = 8):
    """Rasterise one badge, mirroring objects/PlatformIcon.hx."""
    from PIL import Image, ImageDraw

    grid = constants.get("GRID", 100.0)
    outline_px = max(1.0, size * constants.get("OUTLINE_RATIO", 0.055))
    content = (size - 2 * outline_px) / grid

    canvas = Image.new("RGBA", (size * supersample, size * supersample), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    dark = (0, 0, 0, 255)
    white = (255, 255, 255, 255)

    def project(points: Sequence[Point]) -> List[Point]:
        return [
            ((outline_px + point[0] * content) * supersample, (outline_px + point[1] * content) * supersample)
            for point in points
        ]

    bodies = [part for part in parts if part.ink == "BODY"]
    for part in bodies:  # pass 1: welded dark silhouette
        points, closed = outline(part)
        _draw_shape(draw, project(points), closed, dark, dark, outline_px * 2 * supersample)
    for part in bodies:  # pass 2: white fill, no stroke
        points, closed = outline(part)
        _draw_shape(draw, project(points), closed, white, None, 0)
    for part in parts:  # pass 3: details and marks
        if part.ink == "DETAIL":
            points, closed = outline(part)
            _draw_shape(draw, project(points), closed, dark, None, 0)
        elif part.ink == "MARK":
            points, closed = outline(part)
            _draw_shape(draw, project(points), closed, None, dark, outline_px * constants.get("MARK_RATIO", 0.8) * supersample)

    return canvas.resize((size, size), Image.LANCZOS)


def build_sheet(glyphs: Dict[str, List[Part]], order: Sequence[str], sizes: Sequence[int], constants, background):
    from PIL import Image, ImageDraw

    margin = 16
    label_height = 18
    column = max(sizes) + margin
    width = margin + column * len(order)
    height = margin + label_height + sum(size + margin for size in sizes)

    sheet = Image.new("RGBA", (width, height), background)
    draw = ImageDraw.Draw(sheet)
    for index, name in enumerate(order):
        x = margin + index * column
        draw.text((x, 2), name.lower()[:10], fill=(255, 255, 255, 255))
        y = margin + label_height
        for size in sizes:
            sheet.alpha_composite(render(glyphs[name], size, constants), (int(x), int(y)))
            y += size + margin
    return sheet


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--sizes", type=int, nargs="+", default=[16, 24, 36, 64, 128])
    parser.add_argument("--out", type=Path, default=REPO_ROOT / "tools" / "reports" / "platform-icons.png")
    parser.add_argument("--background", default="101010", help="sheet background, RRGGBB")
    parser.add_argument("--source", type=Path, default=HAXE_SOURCE)
    args = parser.parse_args(argv)

    source = load_source(args.source)
    glyphs = parse_glyphs(source)
    constants = parse_constants(source)

    try:
        sheet = build_sheet(
            glyphs,
            sorted(glyphs),
            args.sizes,
            constants,
            tuple(int(args.background[i : i + 2], 16) for i in (0, 2, 4)) + (255,),
        )
    except ImportError:
        print("Pillow is required to render previews: pip install Pillow", file=sys.stderr)
        return 1

    args.out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(args.out)
    print(f"wrote {args.out} ({len(glyphs)} glyphs, sizes {args.sizes})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
