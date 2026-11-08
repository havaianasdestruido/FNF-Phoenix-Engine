#!/usr/bin/env python3
"""Compile-check every GLSL shader embedded in the engine's Haxe sources.

Extracts the @:glFragmentSource / @:glVertexSource / @:glFragmentHeader /
@:glVertexHeader / @:glVertexBody string literals (plus the runtime-shader
strings in shaders/RuntimeShaders.hx), assembles them the way OpenFL/Flixel
does at runtime -- `#pragma header` expansion and, for FlxFixedShader
subclasses, the GLSL ES 3.00 source rewrite from FlxFixedShader.initGood() --
and feeds the result to Khronos' glslangValidator in three dialects:

  * GLSL ES 1.00   (Android GLES2 / WebGL1 path)
  * GLSL 1.20      (desktop OpenFL path)
  * GLSL ES 3.00   (FlxFixedShader on lime_opengles, FlxFixedShader subclasses only)

Usage:
  python3 tools/validate_shaders.py [--validator PATH] [--ref GITREF] [--keep DIR]

  --validator   path to glslangValidator (default: search PATH)
  --ref         validate sources from a git ref instead of the working tree
                (e.g. --ref HEAD~1 to compare before/after a change)
  --keep        directory to write the assembled .frag/.vert files into

Exit code is the number of failed compilations (0 = all pass), or 2 when the
validator binary is missing.
"""

import argparse
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

SHADER_FILES = [
    "source/objects/ColorSwap.hx",
    "source/shaders/BlockedGlitchShader.hx",
    "source/shaders/BloomShader.hx",
    "source/shaders/BuildingShader.hx",
    "source/shaders/ChromaticAberrationShader.hx",
    "source/shaders/DistantNoteShader.hx",
    "source/shaders/DistortBGShader.hx",
    "source/shaders/TriangleShader.hx",
    "source/shaders/GlitchShader.hx",
    "source/shaders/Grain.hx",
    "source/shaders/GreyscaleShader.hx",
    "source/shaders/InvertShader.hx",
    "source/shaders/PulseShader.hx",  # no embedded GLSL (uses RuntimeShaders)
    "source/shaders/RGBPalette.hx",
    "source/shaders/RainShader.hx",
    "source/shaders/RuntimeShaders.hx",
    "source/shaders/Scanline.hx",
    "source/shaders/ThreeDShader.hx",
    "source/shaders/Tiltshift.hx",
    "source/shaders/VCRDistortionShader.hx",
    "source/shaders/VFDOverlay.hx",
    "source/shaders/WiggleEffect.hx",
]

# Classes extending backend.FlxFixedShader get the ES 3.00 rewrite on GLES.
FIXED_SHADER_FILES = {
    "source/objects/ColorSwap.hx",
    "source/shaders/DistantNoteShader.hx",
    "source/shaders/RGBPalette.hx",
    "source/shaders/RainShader.hx",
    "source/shaders/WiggleEffect.hx",
}

FRAG_PRAGMA_HEADER = """
varying float openfl_Alphav;
varying vec4 openfl_ColorMultiplierv;
varying vec4 openfl_ColorOffsetv;
varying vec2 openfl_TextureCoordv;
uniform bool openfl_HasColorTransform;
uniform vec2 openfl_TextureSize;
uniform sampler2D bitmap;
uniform bool hasTransform;
uniform bool hasColorTransform;
vec4 flixel_texture2D(sampler2D bitmap, vec2 coord)
{
    vec4 color = texture2D(bitmap, coord);
    if (!hasTransform) return color;
    if (color.a == 0.0) return vec4(0.0, 0.0, 0.0, 0.0);
    if (!hasColorTransform) return color * openfl_Alphav;
    color = vec4(color.rgb / color.a, color.a);
    color = clamp(openfl_ColorOffsetv + color * openfl_ColorMultiplierv, 0.0, 1.0);
    if (color.a > 0.0) return vec4(color.rgb * color.a * openfl_Alphav, color.a * openfl_Alphav);
    return vec4(0.0, 0.0, 0.0, 0.0);
}
"""

VERTEX_TEMPLATE = """
attribute float openfl_Alpha;
attribute vec4 openfl_ColorMultiplier;
attribute vec4 openfl_ColorOffset;
attribute vec4 openfl_Position;
attribute vec2 openfl_TextureCoord;
varying float openfl_Alphav;
varying vec4 openfl_ColorMultiplierv;
varying vec4 openfl_ColorOffsetv;
varying vec2 openfl_TextureCoordv;
uniform mat4 openfl_Matrix;
uniform bool openfl_HasColorTransform;
uniform vec2 openfl_TextureSize;
attribute float alpha;
attribute vec4 colorMultiplier;
attribute vec4 colorOffset;
uniform bool hasColorTransform;
%%VERTEX_HEADER%%
void main(void)
{
    openfl_Alphav = openfl_Alpha;
    openfl_TextureCoordv = openfl_TextureCoord;
    if (openfl_HasColorTransform)
    {
        openfl_ColorMultiplierv = openfl_ColorMultiplier;
        openfl_ColorOffsetv = openfl_ColorOffset / 255.0;
    }
    openfl_Alphav = openfl_Alpha * alpha;
    if (hasColorTransform)
    {
        openfl_ColorOffsetv = colorOffset / 255.0;
        openfl_ColorMultiplierv = colorMultiplier;
    }
    %%VERTEX_BODY%%
    gl_Position = openfl_Matrix * openfl_Position;
}
"""


def parse_haxe_string(text, i):
    """Parse a Haxe string literal starting at text[i] (a quote). Returns (value, next_index)."""
    quote = text[i]
    assert quote in "'\""
    i += 1
    out = []
    while i < len(text):
        c = text[i]
        if c == "\\" and i + 1 < len(text):
            nxt = text[i + 1]
            escapes = {"n": "\n", "r": "\r", "t": "\t", "\\": "\\", "'": "'", '"': '"'}
            out.append(escapes.get(nxt, "\\" + nxt))
            i += 2
        elif c == quote:
            return "".join(out), i + 1
        else:
            out.append(c)
            i += 1
    raise ValueError("unterminated string literal")


GL_META = ["glFragmentSource", "glVertexSource", "glFragmentHeader", "glVertexHeader", "glVertexBody"]


def extract(text):
    """Return {metadata_name: source} for every @:gl* annotation in a Haxe file."""
    # Drop Haxe block comments so commented-out shaders are not picked up.
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    found = {}
    for name in GL_META:
        idx = 0
        while True:
            m = text.find("@:" + name, idx)
            if m < 0:
                break
            j = text.find("(", m) + 1
            while text[j] in " \t\r\n":
                j += 1
            if text[j] in "'\"":
                value, idx = parse_haxe_string(text, j)
                found.setdefault(name, value)
            else:
                idx = j
    return found


def extract_runtime_shader_strings(text):
    """RuntimeShaders.hx: enum abstract fields holding whole fragment sources."""
    found = {}
    for m in re.finditer(r"final\s+(\w+)\s*:\s*String\s*=\s*", text):
        j = m.end()
        if text[j] in "'\"":
            value, _ = parse_haxe_string(text, j)
            found[m.group(1)] = value
    return found


def read_source(path, ref):
    if ref:
        return subprocess.run(
            ["git", "show", f"{ref}:{path}"],
            cwd=REPO_ROOT, capture_output=True, text=True, check=True,
        ).stdout
    return (REPO_ROOT / path).read_text()


def assemble(meta, runtime_strings):
    """Yield (label, fragment_source, vertex_source) tuples ready for versioning."""
    frag_source = meta.get("glFragmentSource")
    if frag_source is not None:
        frag = frag_source
        header = meta.get("glFragmentHeader", "")
        if "#pragma header" in frag or header:
            frag = frag.replace("#pragma header", "")
            header = header.replace("#pragma header", "")
            frag = FRAG_PRAGMA_HEADER + header + frag
        if "glVertexSource" in meta:
            vert = meta["glVertexSource"]
        else:
            vert = (VERTEX_TEMPLATE
                    .replace("%%VERTEX_HEADER%%", meta.get("glVertexHeader", ""))
                    .replace("%%VERTEX_BODY%%", meta.get("glVertexBody", "")))
        yield "fragmentShader", frag, vert
    for name, src in runtime_strings.items():
        frag = src.replace("#pragma header", FRAG_PRAGMA_HEADER)
        yield name, frag, (VERTEX_TEMPLATE
                           .replace("%%VERTEX_HEADER%%", "")
                           .replace("%%VERTEX_BODY%%", ""))


def versioned(source, stage, dialect, fixed_rewrite):
    """Prepend a #version for the given dialect, optionally applying the
    FlxFixedShader ES 3.00 textual rewrite."""
    if dialect == "es100":
        prefix = "#version 100\n"
        if stage == "frag":
            prefix += "precision mediump float;\nprecision mediump int;\n"
        return prefix + source
    if dialect == "gl120":
        return "#version 120\n" + source
    if dialect == "es300":
        assert fixed_rewrite
        prefix = "#version 300 es\nprecision highp float;\nprecision highp int;\n"
        if stage == "frag":
            prefix += "out vec4 output_FragColor;\n"
            source = (source.replace("varying", "in")
                            .replace("texture2D", "texture")
                            .replace("gl_FragColor", "output_FragColor"))
        else:
            source = (source.replace("attribute", "in")
                            .replace("varying", "out")
                            .replace("texture2D", "texture")
                            .replace("gl_FragColor", "output_FragColor"))
        return prefix + source
    raise ValueError(dialect)


def compile_one(validator, workdir, name, stage, source):
    path = Path(workdir) / f"{name}.{stage}"
    path.write_text(source)
    proc = subprocess.run(
        [validator, "-S", stage, str(path)],
        capture_output=True, text=True,
    )
    return proc.returncode == 0, (proc.stdout + proc.stderr).strip()


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--validator", default=shutil.which("glslangValidator"))
    ap.add_argument("--ref", default=None, help="git ref to read sources from")
    ap.add_argument("--keep", default=None, help="keep assembled sources in this dir")
    args = ap.parse_args()

    if not args.validator or not Path(args.validator).exists():
        print("glslangValidator not found; build it from https://github.com/KhronosGroup/glslang",
              file=sys.stderr)
        return 2

    workdir = args.keep or tempfile.mkdtemp(prefix="shader_validate_")
    Path(workdir).mkdir(parents=True, exist_ok=True)
    failures = 0
    tested = 0
    for rel in SHADER_FILES:
        try:
            text = read_source(rel, args.ref)
        except (FileNotFoundError, subprocess.CalledProcessError):
            print(f"SKIP {rel}: not found")
            continue
        meta = extract(text)
        runtime = extract_runtime_shader_strings(text) if rel.endswith("RuntimeShaders.hx") else {}
        if not meta and not runtime:
            continue
        fixed = rel in FIXED_SHADER_FILES
        dialects = ["es100", "gl120"] + (["es300"] if fixed else [])
        base = Path(rel).stem
        for label, frag, vert in assemble(meta, runtime):
            for dialect in dialects:
                for stage, src in (("frag", frag), ("vert", vert)):
                    name = f"{base}_{label}_{dialect}"
                    ok, output = compile_one(args.validator, workdir, name, stage,
                                             versioned(src, stage, dialect, fixed))
                    tested += 1
                    status = "PASS" if ok else "FAIL"
                    if not ok:
                        failures += 1
                    print(f"{status} {rel} [{label}] {dialect} {stage}")
                    if not ok:
                        for line in output.splitlines()[:12]:
                            print(f"     {line}")
    print(f"\n{tested - failures}/{tested} compilations passed; assembled sources in {workdir}")
    return failures


if __name__ == "__main__":
    sys.exit(main())
