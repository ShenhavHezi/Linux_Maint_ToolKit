#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<'USAGE'
Usage: tools/clean_local_state.sh [--dist] [--build-info] [--all] [--dry-run]

Removes repo-local generated state without touching tracked source files.

Default cleanup:
  - .logs/
  - .tmp_test/
  - .etc_linux_maint/
  - __pycache__/ directories
  - *.pyc files

Optional:
  --dist        also remove dist/
  --build-info  also remove repo-root BUILD_INFO
  --all         same as --dist --build-info
  --dry-run     print what would be removed
USAGE
}

include_dist=0
include_build_info=0
dry_run=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dist) include_dist=1 ;;
    --build-info) include_build_info=1 ;;
    --all) include_dist=1; include_build_info=1 ;;
    --dry-run) dry_run=1 ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

paths=(
  "$ROOT_DIR/.logs"
  "$ROOT_DIR/.tmp_test"
  "$ROOT_DIR/.etc_linux_maint"
)

[[ "$include_dist" -eq 1 ]] && paths+=("$ROOT_DIR/dist")
[[ "$include_build_info" -eq 1 ]] && paths+=("$ROOT_DIR/BUILD_INFO")

deleted=0

remove_path() {
  local path="$1"
  if [[ ! -e "$path" ]]; then
    return 0
  fi
  if [[ "$dry_run" -eq 1 ]]; then
    printf 'would remove %s\n' "$path"
  else
    rm -rf -- "$path"
    printf 'removed %s\n' "$path"
  fi
  deleted=1
}

for path in "${paths[@]}"; do
  remove_path "$path"
done

while IFS= read -r -d '' path; do
  if [[ "$dry_run" -eq 1 ]]; then
    printf 'would remove %s\n' "$path"
  else
    rm -rf -- "$path"
    printf 'removed %s\n' "$path"
  fi
  deleted=1
done < <(find "$ROOT_DIR" -type d -name '__pycache__' -print0)

while IFS= read -r -d '' path; do
  if [[ "$dry_run" -eq 1 ]]; then
    printf 'would remove %s\n' "$path"
  else
    rm -f -- "$path"
    printf 'removed %s\n' "$path"
  fi
  deleted=1
done < <(find "$ROOT_DIR" -type f -name '*.pyc' -print0)

if [[ "$deleted" -eq 0 ]]; then
  echo "nothing to clean"
fi
