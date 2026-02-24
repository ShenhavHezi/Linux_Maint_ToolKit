#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

usage() {
  cat <<USAGE
Usage: tools/release_prep.sh <version> [--notes-out PATH] [--allow-dirty] [--dry-run]

Automates:
  - VERSION bump
  - CHANGELOG entry (moves Unreleased into dated section)
  - release notes draft from docs/RELEASE_TEMPLATE.md

Examples:
  tools/release_prep.sh 0.2.2
  tools/release_prep.sh 0.2.2 --notes-out docs/release_notes/release_notes_v0.2.2.md
USAGE
}

VERSION="${1:-}"
shift || true

NOTES_OUT=""
ALLOW_DIRTY=0
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --notes-out) NOTES_OUT="$2"; shift 2;;
    --allow-dirty) ALLOW_DIRTY=1; shift 1;;
    --dry-run) DRY_RUN=1; shift 1;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2;;
  esac
done

if [[ -z "$VERSION" ]]; then
  usage >&2
  exit 2
fi

if [[ -z "$NOTES_OUT" ]]; then
  NOTES_OUT="docs/release_notes/release_notes_v${VERSION}.md"
fi

args=("$VERSION" --no-tag --no-commit --notes-out "$NOTES_OUT")
[[ "$ALLOW_DIRTY" -eq 1 ]] && args+=(--allow-dirty)
[[ "$DRY_RUN" -eq 1 ]] && args+=(--dry-run)

"$ROOT_DIR/tools/release.sh" "${args[@]}"

if [[ "$DRY_RUN" -eq 1 ]]; then
  exit 0
fi

python3 - "$ROOT_DIR/docs/README.md" "$ROOT_DIR/docs/INDEX.md" "$NOTES_OUT" <<'PY'
import re
import sys
from pathlib import Path

readme_path, index_path, notes_path = map(Path, sys.argv[1:4])
notes_rel = notes_path.as_posix()
if notes_rel.startswith(str(readme_path.parent) + "/"):
  notes_rel = notes_rel[len(str(readme_path.parent)) + 1:]
notes_rel = f"docs/{notes_rel}" if not notes_rel.startswith("docs/") else notes_rel

def update_readme(path: Path, notes: str) -> None:
    lines = path.read_text(encoding="utf-8").splitlines()
    out = []
    pat = re.compile(r"`(docs/release_notes/release_notes_v[^`]+)`")
    replaced = False
    for line in lines:
        if line.strip().startswith("- Release notes (latest):"):
            found = pat.findall(line)
            items = [notes] + [f for f in found if f != notes]
            items = items[:2]
            line = "- Release notes (latest): " + ", ".join(f"`{f}`" for f in items)
            replaced = True
        out.append(line)
    if replaced:
        path.write_text("\n".join(out) + "\n", encoding="utf-8")

def update_index(path: Path, notes: str) -> None:
    lines = path.read_text(encoding="utf-8").splitlines()
    link = f"- [`{notes}`]({notes.replace('docs/','')})"
    if any(link in line for line in lines):
        return
    out = []
    inserted = False
    for line in lines:
        if not inserted and "security_best_practices_report.md" in line:
            out.append(line)
            out.append(link)
            inserted = True
            continue
        if not inserted and "release_notes_v" in line:
            out.append(link)
            inserted = True
        out.append(line)
    if not inserted:
        out.append(link)
    path.write_text("\n".join(out) + "\n", encoding="utf-8")

update_readme(readme_path, notes_rel)
update_index(index_path, notes_rel)
PY
