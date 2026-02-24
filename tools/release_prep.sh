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
  tools/release_prep.sh 0.2.2 --notes-out docs/release_notes_v0.2.2.md
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

args=("$VERSION" --no-tag --no-commit)
[[ -n "$NOTES_OUT" ]] && args+=(--notes-out "$NOTES_OUT")
[[ "$ALLOW_DIRTY" -eq 1 ]] && args+=(--allow-dirty)
[[ "$DRY_RUN" -eq 1 ]] && args+=(--dry-run)

exec "$ROOT_DIR/tools/release.sh" "${args[@]}"
