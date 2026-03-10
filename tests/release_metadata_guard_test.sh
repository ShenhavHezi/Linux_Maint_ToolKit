#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CURRENT_VERSION="$(head -n 1 "$ROOT_DIR/VERSION" | tr -d '[:space:]')"
CURRENT_REL="docs/release_notes/release_notes_v${CURRENT_VERSION}.md"
workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

copy_repo(){
  local dest="$1"
  mkdir -p "$dest"
  (
    cd "$ROOT_DIR"
    git ls-files -z | tar --null -T - -cf - | tar -xf - -C "$dest"
  )
}

remove_release_ref(){
  local doc_path="$1"
  python3 - "$doc_path" "$CURRENT_REL" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
current = sys.argv[2]
text = path.read_text(encoding="utf-8")
for pattern in (f"`{current}`, ", f", `{current}`", f"`{current}`"):
    text = text.replace(pattern, "")
path.write_text(text, encoding="utf-8")
PY
}

repo_missing_note="$workdir/missing_note"
copy_repo "$repo_missing_note"
rm -f "$repo_missing_note/$CURRENT_REL"
set +e
out="$(bash "$repo_missing_note/tools/release_check.sh" 2>&1)"
rc=$?
set -e
[[ "$rc" -ne 0 ]] || {
  echo "release_check.sh succeeded without current release notes" >&2
  exit 1
}
grep -q 'Current version release notes missing' <<< "$out" || {
  echo "release_check.sh did not flag missing current release notes" >&2
  echo "$out" >&2
  exit 1
}

repo_missing_readme_ref="$workdir/missing_readme_ref"
copy_repo "$repo_missing_readme_ref"
remove_release_ref "$repo_missing_readme_ref/docs/README.md"
set +e
out="$(bash "$repo_missing_readme_ref/tools/release_audit.sh" 2>&1)"
rc=$?
set -e
[[ "$rc" -ne 0 ]] || {
  echo "release_audit.sh succeeded without current release notes reference in docs/README.md" >&2
  exit 1
}
grep -q 'docs/README.md missing current release notes reference' <<< "$out" || {
  echo "release_audit.sh did not flag docs/README.md current release notes drift" >&2
  echo "$out" >&2
  exit 1
}

repo_missing_index_ref="$workdir/missing_index_ref"
copy_repo "$repo_missing_index_ref"
remove_release_ref "$repo_missing_index_ref/docs/INDEX.md"
set +e
out="$(bash "$repo_missing_index_ref/tools/release_audit.sh" 2>&1)"
rc=$?
set -e
[[ "$rc" -ne 0 ]] || {
  echo "release_audit.sh succeeded without current release notes reference in docs/INDEX.md" >&2
  exit 1
}
grep -q 'docs/INDEX.md missing current release notes reference' <<< "$out" || {
  echo "release_audit.sh did not flag docs/INDEX.md current release notes drift" >&2
  echo "$out" >&2
  exit 1
}

echo "release metadata guard ok"
