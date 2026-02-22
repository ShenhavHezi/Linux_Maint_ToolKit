#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

usage() {
  cat <<USAGE
Usage: tools/release.sh <version> [--release] [--notes-out PATH] [--no-tag] [--no-commit] [--allow-dirty] [--dry-run]

Automates:
  - VERSION bump
  - CHANGELOG entry (moves Unreleased into dated section)
  - release notes draft from docs/RELEASE_TEMPLATE.md
  - optional git tag and GitHub release

Examples:
  tools/release.sh 0.1.5
  tools/release.sh 0.1.5 --release
  tools/release.sh 0.1.5 --notes-out /tmp/release_notes.md --no-tag
USAGE
}

VERSION="${1:-}"
shift || true

DO_RELEASE=0
NO_TAG=0
NO_COMMIT=0
ALLOW_DIRTY=0
DRY_RUN=0
NOTES_OUT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --release) DO_RELEASE=1; shift 1;;
    --notes-out) NOTES_OUT="$2"; shift 2;;
    --no-tag) NO_TAG=1; shift 1;;
    --no-commit) NO_COMMIT=1; shift 1;;
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
  mkdir -p dist
  NOTES_OUT="dist/release_notes_${TAG}.md"
fi

if [[ ! -f docs/RELEASE_TEMPLATE.md ]]; then
  echo "ERROR: docs/RELEASE_TEMPLATE.md not found" >&2
  exit 2
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "[dry-run] would update VERSION -> $VERSION"
  echo "[dry-run] would update CHANGELOG.md with date $DATE_UTC and tag $TAG"
  echo "[dry-run] would write notes: $NOTES_OUT"
  echo "[dry-run] no git commit/tag/release"
  exit 0
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

git add VERSION CHANGELOG.md
if [[ "$NO_COMMIT" -ne 1 ]]; then
  git commit -m "Release ${TAG}"
fi

if [[ "$NO_TAG" -ne 1 ]]; then
  git tag "${TAG}"
fi

if [[ "$DO_RELEASE" -eq 1 ]]; then
  if ! command -v gh >/dev/null 2>&1; then
    echo "ERROR: gh not found; install GitHub CLI or omit --release" >&2
    exit 2
  fi
  git push origin "${TAG}"
  gh release create "${TAG}" --title "${TAG}" --notes-file "${NOTES_OUT}"
fi

echo "Release prep complete."
echo "Notes: $NOTES_OUT"
echo "Tag: $TAG"
