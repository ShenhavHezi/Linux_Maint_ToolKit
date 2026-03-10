#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail=0

current_version(){
  head -n 1 "$ROOT_DIR/VERSION" | tr -d '[:space:]'
}

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

check_version_format(){
  local version
  version="$(current_version)"
  if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    fail_msg "VERSION must use x.y.z format: $version"
  fi
}

check_changelog_current_release(){
  local version="$1"
  check_file "$ROOT_DIR/CHANGELOG.md" "CHANGELOG" || return
  if ! grep -Fq -- "- Release v${version}" "$ROOT_DIR/CHANGELOG.md"; then
    fail_msg "CHANGELOG missing current release entry: v${version}"
  fi
}

check_current_release_note(){
  local version note_path
  version="$(current_version)"
  note_path="$ROOT_DIR/docs/release_notes/release_notes_v${version}.md"
  check_file "$note_path" "Current version release notes"
  [[ -f "$note_path" ]] || return
  grep -Fqx -- "# Release Notes v${version}" "$note_path" || fail_msg "Current version release notes title mismatch: $note_path"
  grep -Fqx -- "- Version: ${version}" "$note_path" || fail_msg "Current version release notes version mismatch: $note_path"
  grep -Fqx -- "- Git tag: v${version}" "$note_path" || fail_msg "Current version release notes tag mismatch: $note_path"
  grep -Eq '^- Date \(UTC\): [0-9]{4}-[0-9]{2}-[0-9]{2}$' "$note_path" || fail_msg "Current version release notes date missing or invalid: $note_path"
}

check_docs
check_schemas
check_version_format
check_release_notes
check_current_release_note
check_changelog_current_release "$(current_version)"

if [[ "$fail" -ne 0 ]]; then
  echo "release_check: FAILED" >&2
  exit 1
fi

echo "release_check: OK"
