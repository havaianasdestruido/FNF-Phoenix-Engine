#!/usr/bin/env python3
"""
Validate that the preference defaults table in `source/backend/Diagnostics.hx`
still matches the initialisers in `source/backend/ClientPrefs.hx`.

The "Copy diagnostics" block reports a preference only when its current value
differs from its *default*. That comparison is only correct while
`Diagnostics.DEFAULTS` names the same preferences `ClientPrefs` declares and
carries the same initial values, so a new preference added to `ClientPrefs`
(and not to the table) silently disappears from every support report.

Exits non-zero on drift, printing one line per problem.
"""
from __future__ import annotations

import pathlib
import re
import sys
from typing import Optional

ROOT = pathlib.Path(__file__).resolve().parents[1]
CLIENT_PREFS = ROOT / "source/backend/ClientPrefs.hx"
DIAGNOSTICS = ROOT / "source/backend/Diagnostics.hx"

FIELD_RE = re.compile(r"^\s*public static var (\w+)\s*:\s*([^=\n]+?)\s*=\s*(.+);\s*$", re.M)


def normalise(value: str) -> str:
    """60 vs 60.0 vs 60 are the same default for a Float/Int preference."""
    value = value.strip()
    if re.fullmatch(r"-?\d+\.0", value):
        value = value[:-2]
    return value.replace(" ", "")


CONST_RE = re.compile(r"public static final (\w+)\s*:(?:\w+)\s*=\s*(.+?);")


def class_constants(class_name: str) -> dict[str, str]:
    """Literal values of `public static final` fields declared in `class_name`."""
    for path in ROOT.rglob(f"{class_name}.hx"):
        source = path.read_text(encoding="utf-8-sig")
        return {m.group(1): m.group(2).strip() for m in CONST_RE.finditer(source)}
    return {}


def resolve(value: str, seen: Optional[set] = None, scope: Optional[dict] = None) -> str:
    """Follow constant defaults (`OtherClass.CONST`, or a bare same-class name)
    down to the literal they ultimately stand for."""
    seen = seen or set()
    scope = scope or {}
    value = value.strip()
    if value in seen:
        return value
    seen.add(value)

    qualified = re.fullmatch(r"(\w+)\.(\w+)", value)
    if qualified:
        consts = class_constants(qualified.group(1))
        name = qualified.group(2)
    elif re.fullmatch(r"\w+", value) and value in scope:
        consts, name = scope, value
    else:
        return value

    resolved = consts.get(name)
    return resolve(resolved, seen, consts) if resolved else value


def client_prefs_defaults() -> dict[str, str]:
    source = CLIENT_PREFS.read_text(encoding="utf-8-sig")
    defaults: dict[str, str] = {}
    for match in FIELD_RE.finditer(source):
        name, kind, value = match.group(1), match.group(2), match.group(3).strip()
        if "Map<" in kind or "Array<" in kind or value.startswith("[") or value.startswith("new Map"):
            continue
        defaults[name] = resolve(value)
    return defaults


def report_defaults() -> dict[str, str]:
    source = DIAGNOSTICS.read_text(encoding="utf-8-sig")
    start = source.find("static final DEFAULTS:Dynamic")
    if start < 0:
        raise SystemExit("Diagnostics.hx: no `DEFAULTS:Dynamic` table found")
    block = source[start:]
    block = block[: block.index("};")]
    entries: dict[str, str] = {}
    for match in re.finditer(r"^\s*(\w+):\s*(.+?),?\s*$", block, re.M):
        entries[match.group(1)] = match.group(2).rstrip(",").strip()
    return entries


def main() -> int:
    expected = client_prefs_defaults()
    actual = report_defaults()
    problems: list[str] = []

    for name in sorted(set(expected) - set(actual)):
        problems.append(f"missing from Diagnostics.DEFAULTS: {name}")
    for name in sorted(set(actual) - set(expected)):
        problems.append(f"no longer declared in ClientPrefs: {name}")
    for name, value in sorted(expected.items()):
        if name not in actual:
            continue
        # ClientPrefs' `#if mobile` conditional default is kept verbatim in the
        # table, so those entries only need to exist.
        if "#if" in value:
            continue
        if normalise(actual[name]) != normalise(value):
            problems.append(f"default drifted for {name}: ClientPrefs={value!r} Diagnostics={actual[name]!r}")

    if problems:
        for problem in problems:
            print(f"error: {problem}")
        print(f"\n{len(problems)} problem(s) between ClientPrefs and Diagnostics.DEFAULTS")
        return 1

    print(f"Diagnostics.DEFAULTS matches ClientPrefs ({len(actual)} preferences)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
