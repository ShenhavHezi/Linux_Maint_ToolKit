#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

python3 - "$ROOT_DIR" "$@" <<'PY'
import glob
import os
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
args = sys.argv[2:]

if not args:
    paths = [root / "README.md"] + list((root / "docs").glob("*.md"))
else:
    paths = []
    for arg in args:
        p = Path(arg)
        if not p.is_absolute():
            p = root / p
        if any(ch in str(p) for ch in ["*", "?", "["]):
            paths.extend(Path().glob(str(p)))
        else:
            paths.append(p)

link_re = re.compile(r"(?<!\!)\[[^\]]*\]\(([^)]+)\)")
code_inline_re = re.compile(r"`[^`]*`")

errors = []


def slugify(text: str) -> str:
    t = text.strip().lower()
    t = re.sub(r"[^a-z0-9 -]", "", t)
    t = t.replace(" ", "-")
    return t.strip("-")


def collect_anchors(path: Path) -> set[str]:
    anchors: set[str] = set()
    counts: dict[str, int] = {}
    in_fence = False
    for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        if line.lstrip().startswith("```") or line.lstrip().startswith("~~~"):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        m = re.match(r"^\s*(#{1,6})\s+(.*)", line)
        if not m:
            continue
        heading = m.group(2).strip()
        if not heading:
            continue
        base = slugify(heading)
        if not base:
            continue
        n = counts.get(base, 0)
        if n == 0:
            slug = base
        else:
            slug = f"{base}-{n}"
        counts[base] = n + 1
        anchors.add(slug)
    return anchors


anchors_cache: dict[Path, set[str]] = {}


def get_anchors(path: Path) -> set[str]:
    if path not in anchors_cache:
        anchors_cache[path] = collect_anchors(path)
    return anchors_cache[path]


for path in paths:
    if not path.exists():
        errors.append(f"missing file: {path}")
        continue
    text = path.read_text(encoding="utf-8", errors="ignore")
    in_fence = False
    for lineno, line in enumerate(text.splitlines(), 1):
        if line.lstrip().startswith("```") or line.lstrip().startswith("~~~"):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        line = code_inline_re.sub("", line)
        for m in link_re.finditer(line):
            target = m.group(1).strip()
            if not target:
                continue
            if target.startswith("http://") or target.startswith("https://"):
                continue
            if target.startswith("mailto:"):
                continue
            target = target.split()[0]
            if target.startswith("#"):
                anchor = target[1:]
                if anchor:
                    anchors = get_anchors(path)
                    if anchor not in anchors:
                        errors.append(f"{path}:{lineno}: missing anchor #{anchor}")
                continue

            if "#" in target:
                file_part, anchor = target.split("#", 1)
            else:
                file_part, anchor = target, ""

            file_part = file_part.strip()
            if not file_part:
                continue

            if file_part.startswith("/"):
                link_path = root / file_part.lstrip("/")
            else:
                link_path = (path.parent / file_part).resolve()

            if not link_path.exists():
                errors.append(f"{path}:{lineno}: missing target {file_part}")
                continue

            if anchor and link_path.suffix.lower() == ".md":
                anchors = get_anchors(link_path)
                if anchor not in anchors:
                    errors.append(f"{path}:{lineno}: missing anchor #{anchor} in {file_part}")

if errors:
    print("Docs link check failed:")
    for err in errors:
        print(f"- {err}")
    sys.exit(2)

print("docs link check ok")
PY
