#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
CURRENT_VERSION="$(head -n 1 "$ROOT_DIR/VERSION" | tr -d '[:space:]')"
CURRENT_REL="docs/release_notes/release_notes_v${CURRENT_VERSION}.md"
workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

. "$ROOT_DIR/tests/testlib.sh"

remove_release_refs(){
  local doc_path="$1"
  python3 - "$doc_path" "$CURRENT_REL" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
current = sys.argv[2]
text = path.read_text(encoding="utf-8")
for pattern in (
    f"`{current}`, ",
    f", `{current}`",
    f"`{current}`",
    "`docs/release_notes/README.md`, ",
    ", `docs/release_notes/README.md`",
    "`docs/release_notes/README.md`",
    "(release_notes/README.md)",
):
    text = text.replace(pattern, "")
path.write_text(text, encoding="utf-8")
PY
}

repo_missing_note="$workdir/missing_note"
testlib_copy_repo_tracked "$repo_missing_note"
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
testlib_copy_repo_tracked "$repo_missing_readme_ref"
remove_release_refs "$repo_missing_readme_ref/docs/README.md"
set +e
out="$(bash "$repo_missing_readme_ref/tools/release_audit.sh" 2>&1)"
rc=$?
set -e
[[ "$rc" -ne 0 ]] || {
  echo "release_audit.sh succeeded without current release notes reference in docs/README.md" >&2
  exit 1
}
grep -Eq 'docs/README.md missing (current release notes reference|release notes references)' <<< "$out" || {
  echo "release_audit.sh did not flag docs/README.md release notes drift" >&2
  echo "$out" >&2
  exit 1
}

echo "release metadata guard ok"
