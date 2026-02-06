#!/usr/bin/env python3
"""Generate summarize.txt sections from repository source-of-truth.

This script is intentionally conservative: it only regenerates well-defined sections
between markers in summarize.txt.

Markers:
  <!-- AUTOGEN:MONITORS:START --> ... <!-- AUTOGEN:MONITORS:END -->
  <!-- AUTOGEN:INSTALL_FLAGS:START --> ... <!-- AUTOGEN:INSTALL_FLAGS:END -->

Usage:
  python3 tools/gen_summarize.py
"""

from __future__ import annotations

from pathlib import Path
import re

REPO_ROOT = Path(__file__).resolve().parents[1]
SUMMARIZE = REPO_ROOT / "summarize.txt"
INSTALL = REPO_ROOT / "install.sh"
MONITORS_DIR = REPO_ROOT / "monitors"


def read_install_flags() -> list[str]:
    txt = INSTALL.read_text(encoding="utf-8", errors="ignore")
    # Parse `case "$1" in` options like `--with-user)`
    flags = sorted(set(re.findall(r"\n\s*(--[a-z0-9-]+)\)\s", txt)))
    # Keep only user-facing ones
    keep_prefixes = (
        "--with-",
        "--uninstall",
        "--purge",
        "--user",
        "--prefix",
        "--help",
    )
    flags = [f for f in flags if f.startswith(keep_prefixes)]
    return flags


def read_monitors() -> list[str]:
    mons = []
    for p in sorted(MONITORS_DIR.glob("*.sh")):
        mons.append(p.stem)
    return mons


def replace_block(text: str, start_marker: str, end_marker: str, new_block: str) -> str:
    pat = re.compile(
        re.escape(start_marker) + r".*?" + re.escape(end_marker),
        flags=re.S,
    )
    m = pat.search(text)
    if not m:
        raise SystemExit(f"Missing markers: {start_marker} .. {end_marker}")
    return text[: m.start()] + start_marker + "\n" + new_block + "\n" + end_marker + text[m.end() :]


def main() -> None:
    text = SUMMARIZE.read_text(encoding="utf-8", errors="replace")

    # Monitors block
    monitors = read_monitors()
    monitors_block = "\n".join([f"- `{m}`" for m in monitors])
    text = replace_block(
        text,
        "<!-- AUTOGEN:MONITORS:START -->",
        "<!-- AUTOGEN:MONITORS:END -->",
        monitors_block,
    )

    # Install flags block
    flags = read_install_flags()
    flags_block = "\n".join([f"- `{f}`" for f in flags])
    text = replace_block(
        text,
        "<!-- AUTOGEN:INSTALL_FLAGS:START -->",
        "<!-- AUTOGEN:INSTALL_FLAGS:END -->",
        flags_block,
    )

    SUMMARIZE.write_text(text, encoding="utf-8")


if __name__ == "__main__":
    main()
