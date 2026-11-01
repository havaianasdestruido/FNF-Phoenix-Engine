"""Structural sanity checks for Haxe sources touched by the vlog feature.

Catches the common breakage modes of hand-edited Haxe:
- unbalanced braces / parens / brackets outside strings, regexes & comments,
- unbalanced #if/#elseif/#else/#end preprocessor blocks (inline included),
- a preprocessor conditional glued to an expression token.

Because large legacy files (Paths.hx, FlxGame.hx…) contain pre-existing
inline-preprocessor patterns the checker would also flag, the interesting
result is the *delta* against the git baseline: run with a git root and it
reports only findings that are new relative to `git show HEAD:<file>`.
"""
from __future__ import annotations

import re
import subprocess
import sys

FILES = [
    "source/backend/VLog.hx",
    "source/Main.hx",
    "source/backend/Paths.hx",
    "source/backend/CrashHandler.hx",
    "source/psychlua/LuaUtils.hx",
    "source/psychlua/PythonScript.hx",
    "source/source-haxelib-patches/flixel/FlxGame.hx",
]

PREPROC = re.compile(r"#(if|elseif|else|end)\b")


def strip_haxe(text: str) -> str:
    """Replace string/char/regex contents and comments with spaces."""
    out = []
    i, n = 0, len(text)
    state = "code"  # code | line | block | string | char | regex
    block_depth = 0
    while i < n:
        c = text[i]
        nxt = text[i + 1] if i + 1 < n else ""
        if state == "code":
            if c == "/" and nxt == "/":
                state = "line"
                out.append("  ")
                i += 2
                continue
            if c == "/" and nxt == "*":
                state = "block"
                block_depth = 1
                out.append("  ")
                i += 2
                continue
            if c == "~" and nxt == "/":  # Haxe regex literal: ~/pattern/flags
                state = "regex"
                out.append("  ")
                i += 2
                continue
            if c == '"':
                state = "string"
                out.append('"')
                i += 1
                continue
            if c == "'":
                state = "char"
                out.append(" ")
                i += 1
                continue
            out.append(c)
            i += 1
            continue
        if state == "line":
            if c == "\n":
                state = "code"
                out.append("\n")
            else:
                out.append(" ")
            i += 1
            continue
        if state == "block":
            if c == "/" and nxt == "*":
                block_depth += 1
                out.append("  ")
                i += 2
                continue
            if c == "*" and nxt == "/":
                block_depth -= 1
                out.append("  ")
                i += 2
                if block_depth == 0:
                    state = "code"
                continue
            out.append("\n" if c == "\n" else " ")
            i += 1
            continue
        if state == "string":
            if c == "\\":
                out.append("  ")
                i += 2
                continue
            if c == '"':
                state = "code"
                out.append('"')
            else:
                out.append("\n" if c == "\n" else " ")
            i += 1
            continue
        if state == "char":
            if c == "\\":
                out.append("  ")
                i += 2
                continue
            if c == "'":
                state = "code"
                out.append(" ")
            else:
                out.append(" ")
            i += 1
            continue
        if state == "regex":
            if c == "\\":
                out.append("  ")
                i += 2
                continue
            if c == "/":
                state = "code"
                out.append(" ")
                i += 1
                # consume trailing flags (gmi…)
                while i < n and text[i].isalpha():
                    out.append(" ")
                    i += 1
                continue
            out.append("\n" if c == "\n" else " ")
            i += 1
            continue
        raise AssertionError("bad state")
    if state not in ("code",):
        out.append(f"/* unterminated {state} */")
    return "".join(out)


def preproc_lines(text: str):
    """Yield (lineno, token) for every preprocessor token in the stripped text."""
    for lineno, line in enumerate(text.split("\n"), start=1):
        for m in PREPROC.finditer(line):
            start = m.start()
            # # must be a standalone token (line start, or preceded by
            # whitespace / an operator), not glued like `x#if`.
            if start > 0 and line[start - 1] not in " \t;({,=+*&|!?:-]":
                yield lineno, "glued"
                continue
            yield lineno, m.group(1)


def check_file(path: str, text: str) -> list[str]:
    errors = []
    stripped = strip_haxe(text)
    lines = stripped.split("\n")

    # 1. Brace / paren / bracket balance.
    pairs = {"}": "{", ")": "(", "]": "["}
    stack: list[tuple[str, int]] = []
    for lineno, line in enumerate(lines, start=1):
        for ch in line:
            if ch in "{([":
                stack.append((ch, lineno))
            elif ch in "})]":
                if not stack or stack[-1][0] != pairs[ch]:
                    errors.append(f"{path}:{lineno}: unbalanced '{ch}'")
                    stack = []
                    break
                stack.pop()
    if stack:
        ch, lineno = stack[-1]
        errors.append(f"{path}:{lineno}: unclosed '{ch}'")

    # 2. Preprocessor balance (inline #if/#end included).
    depth = 0
    last_if_line = 0
    for lineno, token in preproc_lines(stripped):
        if token == "glued":
            errors.append(f"{path}:{lineno}: preprocessor glued to token: {lines[lineno - 1].strip()[:80]}")
        elif token == "if":
            depth += 1
            last_if_line = lineno
        elif token in ("elseif", "else"):
            if depth == 0:
                errors.append(f"{path}:{lineno}: #{token} without matching #if")
        elif token == "end":
            if depth == 0:
                errors.append(f"{path}:{lineno}: #end without matching #if (last #if at line {last_if_line})")
            else:
                depth -= 1
    if depth != 0:
        errors.append(f"{path}: {depth} unclosed #if block(s) at EOF (last #if at line {last_if_line})")

    return errors


def git_baseline(root: str, rel: str) -> str | None:
    try:
        data = subprocess.run(
            ["git", "-C", root, "show", f"HEAD:{rel}"],
            check=False, capture_output=True, text=True, timeout=60,
        )
        return data.stdout if data.returncode == 0 else None
    except Exception:
        return None


def main() -> int:
    root = sys.argv[1] if len(sys.argv) > 1 else "."
    failed = False
    for rel in FILES:
        path = f"{root}/{rel}"
        try:
            with open(path, encoding="utf-8") as fh:
                current = fh.read()
        except FileNotFoundError:
            print(f"MISSING: {rel}")
            failed = True
            continue

        errors = check_file(rel, current)
        baseline = git_baseline(root, rel)
        if baseline is not None and baseline != current:
            base_errors = check_file(rel, base) if (base := baseline) else []
            base_keys = {e.split(": ", 1)[-1] for e in base_errors}
            errors = [e for e in errors if e.split(": ", 1)[-1] not in base_keys]

        if errors:
            failed = True
            print(f"FAIL {rel}")
            for e in errors:
                print("   ", e)
        else:
            print(f"OK   {rel}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
