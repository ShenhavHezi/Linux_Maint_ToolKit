#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

usage() {
  cat <<USAGE
Usage: tools/release.sh <version> [--release] [--with-tarball] [--notes-out PATH] [--no-tag] [--no-commit] [--allow-dirty] [--dry-run] [--skip-checks]

Automates:
  - VERSION bump
  - CHANGELOG entry (moves Unreleased into dated section)
  - release notes draft from docs/RELEASE_TEMPLATE.md
  - docs/README.md + docs/INDEX.md updated when notes live under docs/release_notes/
  - optional git tag and GitHub release
  - optional tarball build + checksum injection into notes

Examples:
  tools/release.sh 0.1.5
  tools/release.sh 0.1.5 --release
  tools/release.sh 0.1.5 --notes-out /tmp/release_notes.md --no-tag
USAGE
}

VERSION="${1:-}"
shift || true

DO_RELEASE=0
WITH_TARBALL=0
NO_TAG=0
NO_COMMIT=0
ALLOW_DIRTY=0
DRY_RUN=0
NOTES_OUT=""
SKIP_CHECKS=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --release) DO_RELEASE=1; shift 1;;
    --with-tarball) WITH_TARBALL=1; shift 1;;
    --notes-out) NOTES_OUT="$2"; shift 2;;
    --no-tag) NO_TAG=1; shift 1;;
    --no-commit) NO_COMMIT=1; shift 1;;
    --allow-dirty) ALLOW_DIRTY=1; shift 1;;
    --dry-run) DRY_RUN=1; shift 1;;
    --skip-checks) SKIP_CHECKS=1; shift 1;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2;;
  esac
done

if [[ -z "$VERSION" ]]; then
  usage >&2
  exit 2
fi

if [[ "$DO_RELEASE" -eq 1 ]]; then
  WITH_TARBALL=1
fi

TAG="v${VERSION}"
DATE_UTC="$(date -u +%Y-%m-%d)"

if [[ "$ALLOW_DIRTY" -ne 1 ]]; then
  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "ERROR: working tree is dirty. Commit or use --allow-dirty." >&2
    exit 2
  fi
fi

if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null 2>&1; then
  echo "ERROR: tag already exists: $TAG" >&2
  exit 2
fi

if [[ -z "$NOTES_OUT" ]]; then
  NOTES_OUT="docs/release_notes/release_notes_v${VERSION}.md"
fi

if [[ ! -f docs/RELEASE_TEMPLATE.md ]]; then
  echo "ERROR: docs/RELEASE_TEMPLATE.md not found" >&2
  exit 2
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  if [[ "$SKIP_CHECKS" -eq 0 ]]; then
    echo "[dry-run] would run: ./tools/release_check.sh"
    echo "[dry-run] would run: ./tools/release_audit.sh (if present)"
  fi
  echo "[dry-run] would update VERSION -> $VERSION"
  echo "[dry-run] would update CHANGELOG.md with date $DATE_UTC and tag $TAG"
  echo "[dry-run] would write notes: $NOTES_OUT"
  if [[ "$WITH_TARBALL" -eq 1 ]]; then
    echo "[dry-run] would build tarball and update checksum in notes"
  fi
  echo "[dry-run] no git commit/tag/release"
  exit 0
fi

if [[ "$SKIP_CHECKS" -eq 0 ]]; then
  ./tools/release_check.sh
  if [[ -x ./tools/release_audit.sh ]]; then
    ./tools/release_audit.sh
  fi
fi

echo "$VERSION" > VERSION

python3 - "$ROOT_DIR/CHANGELOG.md" "$DATE_UTC" "$VERSION" <<'PY'
import sys
from pathlib import Path

path, date, version = sys.argv[1:4]
text = Path(path).read_text().splitlines()

def find_unreleased(lines):
    for i, line in enumerate(lines):
        if line.strip() == "## Unreleased":
            return i
    return -1

idx = find_unreleased(text)
if idx == -1:
    raise SystemExit("ERROR: CHANGELOG missing '## Unreleased'")

# collect unreleased section
start = idx + 1
end = len(text)
for j in range(start, len(text)):
    if text[j].startswith("## ") and j != idx:
        end = j
        break

unreleased = text[start:end]
items = [l for l in unreleased if l.strip() and l.strip() != "- (add changes here)"]

new_section = []
new_section.append(f"## {date}")
new_section.append("")
new_section.append(f"- Release v{version}")
if items:
    new_section.extend(items)
else:
    new_section.append("- (no notable changes)")

out = []
out.extend(text[:idx+1])
out.append("")
out.append("- (add changes here)")
out.append("")
out.extend(new_section)
out.append("")
out.extend(text[end:])

Path(path).write_text("\n".join(out).rstrip() + "\n")
PY

python3 - "$ROOT_DIR/docs/RELEASE_TEMPLATE.md" "$NOTES_OUT" "$VERSION" "$DATE_UTC" "$TAG" <<'PY'
import sys
from pathlib import Path

tpl_path, out_path, version, date, tag = sys.argv[1:6]
Path(out_path).parent.mkdir(parents=True, exist_ok=True)
tpl = Path(tpl_path).read_text().splitlines()
out = []
for line in tpl:
    if line.startswith("- Version:"):
        out.append(f"- Version: {version}")
    elif line.startswith("- Date (UTC):"):
        out.append(f"- Date (UTC): {date}")
    elif line.startswith("- Git tag:"):
        out.append(f"- Git tag: {tag}")
    else:
        out.append(line)
Path(out_path).write_text("\n".join(out).rstrip() + "\n")
PY

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

if notes_rel.startswith("docs/release_notes/"):
    update_readme(readme_path, notes_rel)
    update_index(index_path, notes_rel)
PY

git add VERSION CHANGELOG.md "$NOTES_OUT" docs/README.md docs/INDEX.md
if [[ "$NO_COMMIT" -ne 1 ]]; then
  git commit -m "Release ${TAG}"
fi

if [[ "$NO_TAG" -ne 1 ]]; then
  git tag "${TAG}"
fi

tarball=""
sums_file="dist/SHA256SUMS"
checksum=""
if [[ "$WITH_TARBALL" -eq 1 ]]; then
  ./tools/make_tarball.sh
  tarball="$(find dist -maxdepth 1 -type f -name "Linux_Maint_ToolKit-v${VERSION}-*.tgz" -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n 1 | awk '{print $2}')"
  if [[ -z "$tarball" ]]; then
    echo "ERROR: tarball not found under dist/" >&2
    exit 2
  fi
  if command -v sha256sum >/dev/null 2>&1; then
    checksum="$(sha256sum "$tarball" | awk '{print $1}')"
  fi
  if [[ -n "$checksum" && -f "$NOTES_OUT" ]]; then
    python3 - "$NOTES_OUT" "$checksum" "$(basename "$tarball")" <<'PY'
import sys
from pathlib import Path

path, checksum, tarball = sys.argv[1:4]
lines = Path(path).read_text().splitlines()
out = []
replaced = False
for line in lines:
    if line.strip().startswith("- SHA256SUMS:"):
        out.append(f"- SHA256SUMS: {checksum}  {tarball}")
        replaced = True
    else:
        out.append(line)
if not replaced:
    out.append(f"- SHA256SUMS: {checksum}  {tarball}")
Path(path).write_text("\n".join(out).rstrip() + "\n")
PY
  fi
fi

if [[ "$DO_RELEASE" -eq 1 ]]; then
  if ! command -v gh >/dev/null 2>&1; then
    echo "ERROR: gh not found; install GitHub CLI or omit --release" >&2
    exit 2
  fi
  git push origin "${TAG}"
  if [[ -n "$tarball" && -f "$tarball" && -f "$sums_file" ]]; then
    gh release create "${TAG}" --title "${TAG}" --notes-file "${NOTES_OUT}" "$tarball" "$sums_file"
  else
    gh release create "${TAG}" --title "${TAG}" --notes-file "${NOTES_OUT}"
  fi
fi

echo "Release prep complete."
echo "Notes: $NOTES_OUT"
echo "Tag: $TAG"
