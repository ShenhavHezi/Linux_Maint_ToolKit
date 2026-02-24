#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail=0

fail_msg(){
  echo "FAIL: $*" >&2
  fail=1
}

check_file(){
  local path="$1" label="$2"
  if [[ ! -f "$path" ]]; then
    fail_msg "$label missing: $path"
    return
  fi
  if [[ ! -s "$path" ]]; then
    fail_msg "$label empty: $path"
  fi
}

check_docs(){
  check_file "$ROOT_DIR/README.md" "README"
  check_file "$ROOT_DIR/CHANGELOG.md" "CHANGELOG"
  check_file "$ROOT_DIR/VERSION" "VERSION"

  check_file "$ROOT_DIR/docs/README.md" "Docs index"
  check_file "$ROOT_DIR/docs/reference.md" "Reference doc"
  check_file "$ROOT_DIR/docs/REASONS.md" "Reasons doc"
  check_file "$ROOT_DIR/docs/DARK_SITE.md" "Dark-site doc"
  check_file "$ROOT_DIR/docs/RELEASE_CHECKLIST.md" "Release checklist"
  check_file "$ROOT_DIR/docs/RELEASE_TEMPLATE.md" "Release template"
}

check_schemas(){
  local schema_dir="$ROOT_DIR/docs/schemas"
  if [[ ! -d "$schema_dir" ]]; then
    fail_msg "Schemas directory missing: $schema_dir"
    return
  fi
  local found=0
  for f in "$schema_dir"/*.json; do
    [[ -f "$f" ]] || continue
    found=1
    if ! python3 -m json.tool "$f" >/dev/null 2>&1; then
      fail_msg "Invalid JSON schema: $f"
    fi
  done
  if [[ "$found" -eq 0 ]]; then
    fail_msg "No JSON schemas found in $schema_dir"
  fi
}

check_release_notes(){
  local notes=("$ROOT_DIR"/docs/release_notes/release_notes_v*.md)
  if [[ "${notes[0]}" == "$ROOT_DIR/docs/release_notes/release_notes_v*.md" ]]; then
    fail_msg "No release notes found under docs/release_notes/ (expected docs/release_notes/release_notes_v*.md)"
    return
  fi
  local n
  for n in "${notes[@]}"; do
    if [[ ! -s "$n" ]]; then
      fail_msg "Release notes file empty: $n"
    fi
  done
}

check_docs
check_schemas
check_release_notes

if [[ "$fail" -ne 0 ]]; then
  echo "release_check: FAILED" >&2
  exit 1
fi

echo "release_check: OK"
