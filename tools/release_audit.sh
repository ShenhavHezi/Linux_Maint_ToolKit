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
    return 1
  fi
  if [[ ! -s "$path" ]]; then
    fail_msg "$label empty: $path"
    return 1
  fi
  return 0
}

check_governance(){
  check_file "$ROOT_DIR/.github/CODEOWNERS" "CODEOWNERS"
  check_file "$ROOT_DIR/.github/PULL_REQUEST_TEMPLATE.md" "PR template"
  check_file "$ROOT_DIR/.github/ISSUE_TEMPLATE/config.yml" "Issue template config"
  check_file "$ROOT_DIR/.github/ISSUE_TEMPLATE/bug_report.md" "Bug issue template"
  check_file "$ROOT_DIR/.github/ISSUE_TEMPLATE/feature_request.md" "Feature issue template"
  check_file "$ROOT_DIR/.github/ISSUE_TEMPLATE/operator_runbook_gap.md" "Operator runbook gap template"
}

check_release_refs(){
  local refs
  refs="$(python3 - "$ROOT_DIR/docs/README.md" <<'PY'
import re, sys
from pathlib import Path
p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8", errors="ignore")
for m in re.findall(r'`(docs/release_notes/release_notes_v[^`]+\.md)`', text):
    print(m)
PY
)"
  if [[ -z "${refs:-}" ]]; then
    fail_msg "docs/README.md missing release notes references"
    return
  fi
  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    if [[ ! -f "$ROOT_DIR/$rel" ]]; then
      fail_msg "docs/README.md references missing release notes file: $rel"
    fi
  done <<< "$refs"
}

check_release_notes_folder(){
  local notes=("$ROOT_DIR"/docs/release_notes/release_notes_v*.md)
  if [[ "${notes[0]}" == "$ROOT_DIR/docs/release_notes/release_notes_v*.md" ]]; then
    fail_msg "No release notes found under docs/release_notes/"
    return
  fi
  local n
  for n in "${notes[@]}"; do
    [[ -s "$n" ]] || fail_msg "Release notes file empty: $n"
  done
}

check_governance
check_release_notes_folder
check_release_refs

if [[ "$fail" -ne 0 ]]; then
  echo "release_audit: FAILED" >&2
  exit 1
fi

echo "release_audit: OK"
