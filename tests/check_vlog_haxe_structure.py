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

import bisect
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
TRY_RE = re.compile(r"\btry\b")
CATCH_RE = re.compile(r"\bcatch\b")


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

    # 3. try/catch body shape (Haxe 4.3 binds one expression per body).
    errors.extend(try_catch_findings(path, stripped))

    return errors


def try_catch_findings(path: str, stripped: str) -> list[str]:
    """Haxe 4.3 binds a single *expression* (secure_expr) as the try body and
    as each catch body. A brace-less try body whose statement ends with `;`
    before the `catch` orphans the catch clause ("Expected }" at the catch, as
    the Haxe compiler reports). A brace-less catch body ends at its first
    top-level `;`, so a statement on the following same-indent line is
    silently outside the catch. Both are flagged."""
    errors: list[str] = []
    n = len(stripped)
    line_starts = [0]
    for idx, ch in enumerate(stripped):
        if ch == "\n":
            line_starts.append(idx + 1)

    def line_of(pos: int) -> int:
        return bisect.bisect_right(line_starts, pos)

    def skip_ws(j: int) -> int:
        while j < n and stripped[j] in " \t\n\r":
            j += 1
        return j

    # try bodies
    for m in TRY_RE.finditer(stripped):
        i = skip_ws(m.end())
        if i < n and stripped[i] == "{":
            continue  # braced body
        depth = 0
        j = i
        semi_line: int | None = None
        catch_found = False
        while j < n:
            c = stripped[j]
            if c in "([{":
                depth += 1
            elif c in ")]}":
                if c == "}" and depth == 0:
                    break  # left the enclosing block: no catch at all
                depth -= 1
            elif c == ";" and depth == 0:
                semi_line = line_of(j)
                break
            elif c == "c" and depth == 0 and stripped[j:j + 5] == "catch":
                if j == 0 or not (stripped[j - 1].isalnum() or stripped[j - 1] in "_$"):
                    catch_found = True
                break
            j += 1
        if semi_line is not None and not catch_found:
            errors.append(
                f"{path}:{line_of(m.start())}: brace-less try body ends with ';' "
                f"before its catch clause (Haxe binds one expression; wrap the "
                f"body in {{ }})"
            )

    # catch bodies. A brace-less catch body is one expression ending at the
    # first top-level ';'; a statement on the following same-indent line is
    # almost always meant to be part of the body but is silently outside the
    # catch. (Multi-line bodies are skipped: the intent is undecidable.)
    for m in CATCH_RE.finditer(stripped):
        j = skip_ws(m.end())
        if j >= n or stripped[j] != "(":
            continue
        depth = 0
        while j < n:
            if stripped[j] == "(":
                depth += 1
            elif stripped[j] == ")":
                depth -= 1
                if depth == 0:
                    j += 1
                    break
            j += 1
        j = skip_ws(j)
        if j < n and stripped[j] == "{":
            continue  # braced body
        depth = 0
        semi_line: int | None = None
        k = j
        while k < n:
            c = stripped[k]
            if c in "([{":
                depth += 1
            elif c in ")]}":
                if depth == 0:
                    break  # enclosing block closer
                depth -= 1
            elif c == ";" and depth == 0:
                semi_line = line_of(k)
                break
            k += 1
        if semi_line is None:
            continue
        if line_of(j) != semi_line:
            continue  # body spans multiple lines
        body_line = stripped.split("\n")[semi_line - 1]
        body_indent = len(body_line) - len(body_line.lstrip(" \t"))
        nxt = semi_line + 1  # 1-based line index of the next line
        while nxt <= len(stripped.split("\n")):
            line = stripped.split("\n")[nxt - 1]
            content = line.strip()
            if content == "" or content.startswith("#"):
                nxt += 1
                continue  # blank line or preprocessor token
            break
        if nxt > len(stripped.split("\n")):
            continue
        line = stripped.split("\n")[nxt - 1]
        indent = len(line) - len(line.lstrip(" \t"))
        if indent == body_indent:
            errors.append(
                f"{path}:{line_of(m.start())}: brace-less catch body; the "
                f"statement on line {nxt} is at the body's indent and is NOT "
                f"caught (wrap the body in {{ }})"
            )

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
