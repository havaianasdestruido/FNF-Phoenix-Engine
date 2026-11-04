#!/usr/bin/env python3
"""
Validate that every JNI.createStaticMethod site in source/android/platform/
has a matching Java method with the correct signature.

Parses Haxe files for JNI.createStaticMethod('class', 'method', 'signature')
and Java files for public static method declarations, converts Java types to
JNI signatures, and reports mismatches.

Also generates a markdown table for docs/ANDROID_PLATFORM.md.
"""
from __future__ import annotations
import re
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
HAXE_DIR = ROOT / "source/android/platform"
JAVA_DIR = ROOT / "source/android/src/quack/fnf/phoenix/android"

# Mapping Java type -> JNI signature fragment
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
    # Common Android types
    "View": "Landroid/view/View;",
}

def java_type_to_jni(java_type: str) -> str:
    """Convert a Java type declaration to JNI signature."""
    java_type = java_type.strip()
    # Handle arrays: byte[] -> [B, String[] -> [Ljava/lang/String;
    array_depth = 0
    while java_type.endswith("[]"):
        array_depth += 1
        java_type = java_type[:-2].strip()
    # Remove generics
    java_type = re.sub(r"<.*>", "", java_type)
    # Handle fully qualified names: use simple name
    if "." in java_type:
        simple = java_type.split(".")[-1]
        if simple in JNI_TYPE_MAP:
            jtype = JNI_TYPE_MAP[simple]
        else:
            # Convert to object signature: Ljava/lang/Object; style
            # Use the full path with / instead of .
            jtype = f"L{java_type.replace('.', '/')};"
    else:
        jtype = JNI_TYPE_MAP.get(java_type, f"L{java_type};")
    return "[" * array_depth + jtype

def parse_java_methods():
    """Parse all Java files for public static methods."""
    java_methods = {}  # (class, method) -> signature
    java_signatures = {}  # (class, method) -> computed JNI sig
    pattern = re.compile(
        r"public\s+static\s+(?:synchronized\s+)?(?:final\s+)?"
        r"([\w<>\.,\s\[\]]+?)\s+(\w+)\s*\(([^)]*)\)",
        re.MULTILINE
    )
    for java_file in JAVA_DIR.glob("*.java"):
        class_name = java_file.stem
        fqcn = f"quack.fnf.phoenix.android.{class_name}"
        content = java_file.read_text(encoding="utf-8")
        for m in pattern.finditer(content):
            return_type = m.group(1).strip()
            method_name = m.group(2).strip()
            params_str = m.group(3).strip()
            # Skip constructors, skip non-method matches
            if method_name[0].isupper() and return_type == "":
                continue
            # Parse params
            param_types = []
            if params_str:
                # Split by comma, but handle generics with commas inside <>
                # Simple split - good enough for our codebase
                for param in params_str.split(","):
                    param = param.strip()
                    if not param:
                        continue
                    # Remove annotations and modifiers, get type
                    # param is like "final String title" or "String title"
                    parts = param.split()
                    # Filter out modifiers
                    filtered = [p for p in parts if p not in ("final", "@NonNull", "@Nullable")]
                    if len(filtered) >= 2:
                        ptype = " ".join(filtered[:-1])
                    elif len(filtered) == 1:
                        ptype = filtered[0]
                    else:
                        continue
                    # Remove varargs
                    ptype = ptype.replace("...", "[]")
                    param_types.append(ptype)
            # Build JNI signature
            jni_params = "".join(java_type_to_jni(t) for t in param_types)
            jni_return = java_type_to_jni(return_type) if return_type else "V"
            jni_sig = f"({jni_params}){jni_return}"
            key = (fqcn, method_name)
            # Handle overloads: keep list
            if key not in java_methods:
                java_methods[key] = []
                java_signatures[key] = []
            java_methods[key].append((params_str, return_type))
            java_signatures[key].append(jni_sig)
    return java_methods, java_signatures

def parse_haxe_bindings():
    """Parse all Haxe files for JNI.createStaticMethod calls."""
    haxe_bindings = []  # list of (haxe_file, class, method, sig)
    pattern = re.compile(
        r"JNI\.createStaticMethod\s*\(\s*['\"]([^'\"]+)['\"]\s*,\s*['\"]([^'\"]+)['\"]\s*,\s*['\"]([^'\"]+)['\"]\s*\)",
        re.MULTILINE
    )
    for haxe_file in HAXE_DIR.glob("*.hx"):
        content = haxe_file.read_text(encoding="utf-8")
        for m in pattern.finditer(content):
            fqcn = m.group(1)
            method = m.group(2)
            sig = m.group(3)
            haxe_bindings.append((haxe_file.name, fqcn, method, sig))
    # Also check mobile/StorageUtil and android/PsychJNI
    for extra in [ROOT / "source/mobile/StorageUtil.hx", ROOT / "source/android/PsychJNI.hx"]:
        if extra.exists():
            content = extra.read_text(encoding="utf-8")
            for m in pattern.finditer(content):
                fqcn = m.group(1)
                method = m.group(2)
                sig = m.group(3)
                haxe_bindings.append((extra.name, fqcn, method, sig))
    return haxe_bindings

def main(check_only=False):
    java_methods, java_sigs = parse_java_methods()
    haxe_bindings = parse_haxe_bindings()
    
    print(f"Found {len(haxe_bindings)} Haxe JNI bindings")
    java_total = sum(len(v) for v in java_methods.values())
    print(f"Found {java_total} Java public static methods")
    
    errors = []
    warnings = []
    
    # External classes provided by Lime/SDL fork (not in this repo)
    EXTERNAL_CLASSES = {"org/libsdl/app/SDLActivity", "org/haxe/lime/GameActivity"}
    # Check each Haxe binding has a Java target
    for haxe_file, fqcn, method, sig in haxe_bindings:
        if fqcn in EXTERNAL_CLASSES:
            continue
        key = (fqcn, method)
        if key not in java_sigs:
            errors.append(f"MISSING Java target: {haxe_file} -> {fqcn}.{method}{sig} (no such class/method in Java)")
        else:
            # Check if any overload matches signature
            if sig not in java_sigs[key]:
                # Try to provide helpful message
                errors.append(
                    f"SIGNATURE MISMATCH: {haxe_file} -> {fqcn}.{method}{sig}\n"
                    f"  Java has: {', '.join(java_sigs[key])} for {fqcn}.{method}\n"
                    f"  Java overloads: {java_methods[key]}"
                )
    
    # Generate docs table
    table_lines = []
    table_lines.append("| Haxe Module | Java Class | Method | Signature | Status |")
    table_lines.append("|---|---|---|---|---|")
    for haxe_file, fqcn, method, sig in sorted(haxe_bindings, key=lambda x: (x[1], x[2])):
        java_class_short = fqcn.split(".")[-1]
        key = (fqcn, method)
        status = "OK" if key in java_sigs and sig in java_sigs.get(key, []) else "MISMATCH"
        table_lines.append(f"| `{haxe_file}` | `{java_class_short}` | `{method}` | `{sig}` | {status} |")
    
    if errors:
        print("\n=== ERRORS ===")
        for e in errors:
            print(e)
    if warnings:
        print("\n=== WARNINGS ===")
        for w in warnings:
            print(w)
    
    if not check_only:
        print("\n=== MARKDOWN TABLE ===")
        for line in table_lines:
            print(line)
    
    # Also report Java methods not referenced from Haxe (informational)
    haxe_targets = {(fqcn, method) for _, fqcn, method, _ in haxe_bindings}
    unreferenced = []
    for key in java_methods:
        if key not in haxe_targets:
            # Filter to only our Phoenix classes
            if "quack.fnf.phoenix.android" in key[0]:
                unreferenced.append(key)
    if unreferenced:
        print(f"\n=== UNREFERENCED Java methods (not called from Haxe) ===")
        for fqcn, method in sorted(unreferenced):
            print(f"  {fqcn}.{method} -> {java_methods[(fqcn, method)]}")
    
    if errors:
        print(f"\nFAILED: {len(errors)} binding errors")
        return 1
    else:
        print(f"\nPASSED: All {len(haxe_bindings)} bindings match Java targets")
        return 0

if __name__ == "__main__":
    check_only = "--check" in sys.argv
    sys.exit(main(check_only=check_only))
