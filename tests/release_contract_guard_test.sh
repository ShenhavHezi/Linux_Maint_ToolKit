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
    git ls-files -z | while IFS= read -r -d '' path; do
      [[ -e "$path" ]] && printf '%s\0' "$path"
    done | tar --null -T - -cf - | tar -xf - -C "$dest"
  )
}

repo_missing_changelog="$workdir/missing_changelog"
copy_repo "$repo_missing_changelog"
python3 - "$repo_missing_changelog/CHANGELOG.md" "$CURRENT_VERSION" <<'PY'
import sys
from pathlib import Path
path = Path(sys.argv[1])
version = sys.argv[2]
text = path.read_text(encoding="utf-8")
text = text.replace(f"- Release v{version}\n", "", 1)
path.write_text(text, encoding="utf-8")
PY
set +e
out="$(bash "$repo_missing_changelog/tools/release_check.sh" 2>&1)"
rc=$?
set -e
[[ "$rc" -ne 0 ]] || {
  echo "release_check.sh succeeded without current CHANGELOG release entry" >&2
  exit 1
}
grep -q "CHANGELOG missing current release entry: v${CURRENT_VERSION}" <<< "$out" || {
  echo "release_check.sh did not flag missing current CHANGELOG release entry" >&2
  echo "$out" >&2
  exit 1
}

repo_bad_notes="$workdir/bad_notes"
copy_repo "$repo_bad_notes"
python3 - "$repo_bad_notes/$CURRENT_REL" <<'PY'
import sys
from pathlib import Path
path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
text = text.replace("- Git tag: v", "- Git tag: release-", 1)
path.write_text(text, encoding="utf-8")
PY
set +e
out="$(bash "$repo_bad_notes/tools/release_check.sh" 2>&1)"
rc=$?
set -e
[[ "$rc" -ne 0 ]] || {
  echo "release_check.sh succeeded with mismatched release notes tag" >&2
  exit 1
}
grep -q "Current version release notes tag mismatch: $repo_bad_notes/$CURRENT_REL" <<< "$out" || {
  echo "release_check.sh did not flag mismatched release notes tag" >&2
  echo "$out" >&2
  exit 1
}

echo "release contract guard ok"
