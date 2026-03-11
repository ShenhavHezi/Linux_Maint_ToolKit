#!/usr/bin/env python3
import re
import sys
from pathlib import Path


def normalize_notes_ref(readme_path: Path, notes_path: Path) -> str:
    notes_rel = notes_path.as_posix()
    prefix = str(readme_path.parent) + "/"
    if notes_rel.startswith(prefix):
        notes_rel = notes_rel[len(prefix):]
    if not notes_rel.startswith("docs/"):
        notes_rel = f"docs/{notes_rel}"
    return notes_rel


def update_readme(path: Path, notes_ref: str) -> None:
    lines = path.read_text(encoding="utf-8").splitlines()
    out = []
    pat = re.compile(r"`(docs/release_notes/release_notes_v[^`]+)`")
    replaced = False
    for line in lines:
        if line.strip().startswith("- Release notes (latest):"):
            found = pat.findall(line)
            items = [notes_ref] + [ref for ref in found if ref != notes_ref]
            items = items[:2]
            line = "- Release notes (latest): " + ", ".join(f"`{ref}`" for ref in items)
            replaced = True
        out.append(line)
    if replaced:
        path.write_text("\n".join(out) + "\n", encoding="utf-8")


def main() -> int:
    if len(sys.argv) != 3:
      print("usage: update_release_notes_refs.py <docs-readme> <notes-path>", file=sys.stderr)
      return 2
    readme_path = Path(sys.argv[1])
    notes_path = Path(sys.argv[2])
    notes_ref = normalize_notes_ref(readme_path, notes_path)
    update_readme(readme_path, notes_ref)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
