"""JNI bridge contract: every Haxe JNI.createStaticMethod must match a Java method.

Parses both sides and fails CI on a mismatch — a Java rename or signature
edit still compiles and fails only at runtime as a silent no-op.

Run: python3 -m unittest discover -s tests -p 'test_android_bridge_contract.py' -v
Also: python3 tools/check_android_bridge.py --check
"""
from __future__ import annotations
import pathlib
import re
import subprocess
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
HAXE_DIR = ROOT / "source/android/platform"
JAVA_DIR = ROOT / "source/android/src/quack/fnf/phoenix/android"
TOOL = ROOT / "tools/check_android_bridge.py"
DOC = ROOT / "docs/ANDROID_PLATFORM.md"

# External classes provided by Lime/SDL fork (not in this repo)
EXTERNAL_CLASSES = {"org/libsdl/app/SDLActivity", "org/haxe/lime/GameActivity"}

JNI_TYPE_MAP = {
    "void": "V",
    "boolean": "Z",
    "byte": "B",
    "char": "C",
    "short": "S",
    "int": "I",
    "long": "J",
    "float": "F",
    "double": "D",
    "String": "Ljava/lang/String;",
    "HaxeObject": "Lorg/haxe/lime/HaxeObject;",
    "Intent": "Landroid/content/Intent;",
    "Context": "Landroid/content/Context;",
    "Activity": "Landroid/app/Activity;",
    "Bundle": "Landroid/os/Bundle;",
    "View": "Landroid/view/View;",
}

def java_type_to_jni(java_type: str) -> str:
    java_type = java_type.strip()
    array_depth = 0
    while java_type.endswith("[]"):
        array_depth += 1
        java_type = java_type[:-2].strip()
    java_type = re.sub(r"<.*>", "", java_type)
    if "." in java_type:
        simple = java_type.split(".")[-1]
        if simple in JNI_TYPE_MAP:
            jtype = JNI_TYPE_MAP[simple]
        else:
            jtype = f"L{java_type.replace('.', '/')};"
    else:
        jtype = JNI_TYPE_MAP.get(java_type, f"L{java_type};")
    return "[" * array_depth + jtype

def parse_java_methods():
    pattern = re.compile(
        r"public\s+static\s+(?:synchronized\s+)?(?:final\s+)?"
        r"([\w<>\.,\s\[\]]+?)\s+(\w+)\s*\(([^)]*)\)",
        re.MULTILINE
    )
    java_sigs = {}
    for java_file in JAVA_DIR.glob("*.java"):
        fqcn = f"quack.fnf.phoenix.android.{java_file.stem}"
        content = java_file.read_text(encoding="utf-8")
        for m in pattern.finditer(content):
            return_type = m.group(1).strip()
            method_name = m.group(2).strip()
            params_str = m.group(3).strip()
            if method_name[0].isupper() and return_type == "":
                continue
            param_types = []
            if params_str:
                for param in params_str.split(","):
                    param = param.strip()
                    if not param:
                        continue
                    parts = param.split()
                    filtered = [p for p in parts if p not in ("final", "@NonNull", "@Nullable")]
                    if len(filtered) >= 2:
                        ptype = " ".join(filtered[:-1])
                    elif len(filtered) == 1:
                        ptype = filtered[0]
                    else:
                        continue
                    ptype = ptype.replace("...", "[]")
                    param_types.append(ptype)
            jni_params = "".join(java_type_to_jni(t) for t in param_types)
            jni_return = java_type_to_jni(return_type) if return_type else "V"
            jni_sig = f"({jni_params}){jni_return}"
            key = (fqcn, method_name)
            java_sigs.setdefault(key, []).append(jni_sig)
    return java_sigs

def parse_haxe_bindings():
    pattern = re.compile(
        r"JNI\.createStaticMethod\s*\(\s*['\"]([^'\"]+)['\"]\s*,\s*['\"]([^'\"]+)['\"]\s*,\s*['\"]([^'\"]+)['\"]\s*\)",
        re.MULTILINE
    )
    bindings = []
    for haxe_file in HAXE_DIR.glob("*.hx"):
        content = haxe_file.read_text(encoding="utf-8")
        for m in pattern.finditer(content):
            bindings.append((haxe_file.name, m.group(1), m.group(2), m.group(3)))
    for extra in [ROOT / "source/mobile/StorageUtil.hx", ROOT / "source/android/PsychJNI.hx"]:
        if extra.exists():
            content = extra.read_text(encoding="utf-8")
            for m in pattern.finditer(content):
                bindings.append((extra.name, m.group(1), m.group(2), m.group(3)))
    return bindings


class BridgeContractTests(unittest.TestCase):
    def test_every_haxe_binding_has_matching_java_method(self):
        java_sigs = parse_java_methods()
        haxe_bindings = parse_haxe_bindings()
        # At least 50 Phoenix bindings (57 currently, 64 with SDL)
        self.assertGreaterEqual(len(haxe_bindings), 50, f"Expected >=50 bindings, found {len(haxe_bindings)}")
        errors = []
        for haxe_file, fqcn, method, sig in haxe_bindings:
            if fqcn in EXTERNAL_CLASSES:
                continue
            key = (fqcn, method)
            if key not in java_sigs:
                errors.append(f"{haxe_file}: {fqcn}.{method}{sig} -> missing Java method")
            elif sig not in java_sigs[key]:
                errors.append(f"{haxe_file}: {fqcn}.{method}{sig} -> mismatch, Java has {java_sigs[key]}")
        self.assertEqual(errors, [], "\n".join(errors))

    def test_tool_exits_zero(self):
        result = subprocess.run([sys.executable, str(TOOL), "--check"], capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_docs_contain_bridge_table(self):
        doc = DOC.read_text(encoding="utf-8")
        self.assertIn("JNI Bridge Contract", doc)
        self.assertIn("AndroidBridge.hx", doc)
        self.assertIn("PhoenixMedia", doc)
        self.assertIn("| Haxe Module | Java Class | Method | Signature |", doc)
        # Ensure at least 50 Phoenix rows are documented (57 exist)
        rows = [l for l in doc.splitlines() if l.strip().startswith("| `") and "Phoenix" in l]
        self.assertGreaterEqual(len(rows), 50, f"Docs table should list >=50 methods, found {len(rows)}")
        # Verify docs table is not stale vs tool output
        haxe_bindings = parse_haxe_bindings()
        phoenix_bindings = [b for b in haxe_bindings if b[1] not in EXTERNAL_CLASSES]
        self.assertEqual(len(rows), len(phoenix_bindings), f"Docs rows {len(rows)} != tool bindings {len(phoenix_bindings)} — regenerate with tools/check_android_bridge.py")

    def test_docs_cover_all_modules(self):
        doc = DOC.read_text(encoding="utf-8")
        for module in ("AndroidMedia", "AndroidDisplay", "AndroidSystem", "AndroidStorage", "PhoenixInput"):
            self.assertIn(module, doc, f"Docs should mention {module}")

if __name__ == "__main__":
    unittest.main()
