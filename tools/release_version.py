#!/usr/bin/env python3
"""Validate a Phoenix release tag against the version in project.hxp.

Release notes are authored on GitHub, not in a repository changelog file.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

VERSION_RE = re.compile(
    r"^[vV]?(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)"
    r"(?:-(alpha|beta|pre|rc)(?:[.-]?(0|[1-9][0-9]*))?)?$",
    re.IGNORECASE,
)
PROJECT_VERSION_RE = re.compile(r'static final VERSION:String = "([^"]+)"')


def normalize_version(raw: str) -> str:
    match = VERSION_RE.match(raw.strip())
    if not match:
        raise ValueError(
            f"{raw!r} is not a Phoenix version. Use MAJOR.MINOR.PATCH with an "
            "optional -alpha, -beta, -preN or -rcN suffix (tag may start with v)."
        )
    core = ".".join(match.group(1, 2, 3))
    stage = match.group(4)
    if not stage:
        return core
    revision = match.group(5)
    return f"{core}-{stage.lower()}" + (f".{revision}" if revision else "")


def project_version(root: Path) -> str:
    text = (root / "project.hxp").read_text(encoding="utf-8")
    match = PROJECT_VERSION_RE.search(text)
    if not match:
        raise ValueError("project.hxp does not define static final VERSION:String")
    return normalize_version(match.group(1))


def validate(root: Path, tag: str) -> str:
    version = normalize_version(tag)
    expected = project_version(root)
    if version != expected:
        raise ValueError(
            f"Release tag {tag!r} normalizes to {version}, but project.hxp "
            f"VERSION is {expected}. Bump project.hxp first."
        )
    return version


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("tag", help="Phoenix release tag, e.g. v0.0.1-pre1")
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--check-only", action="store_true", help="validate the tag")
    parser.add_argument("--print-tag", action="store_true", help="print the validated tag exactly as supplied and exit")
    args = parser.parse_args(argv)
    try:
        validate(args.root, args.tag)
    except (OSError, ValueError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    if args.print_tag:
        print(args.tag.strip())
        return 0
    print(f"OK: {args.tag} matches project.hxp")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
