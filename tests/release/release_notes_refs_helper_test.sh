#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

mkdir -p "$workdir/docs/release_notes"
readme="$workdir/docs/README.md"
release_index="$workdir/docs/release_notes/README.md"
notes="$workdir/docs/release_notes/release_notes_v9.9.9.md"
cat > "$readme" <<'EOF'
# Docs

- Release notes (latest): `docs/release_notes/release_notes_v0.3.4.md`, `docs/release_notes/README.md`
EOF
cat > "$release_index" <<'EOF'
# Release Notes

## Latest releases

| Version | Focus | Open |
| --- | --- | --- |
| `v0.3.4` | older release | [release_notes_v0.3.4.md](release_notes_v0.3.4.md) |

## Full history

- [release_notes_v0.3.4.md](release_notes_v0.3.4.md)
EOF
: > "$notes"

python3 "$ROOT_DIR/tools/update_release_notes_refs.py" "$readme" "$notes"

expected="\`docs/release_notes/release_notes_v9.9.9.md\`, \`docs/release_notes/release_notes_v0.3.4.md\`"
grep -F -q "$expected" "$readme" || {
  echo "release notes helper did not rotate latest release notes reference correctly" >&2
  cat "$readme" >&2
  exit 1
}

grep -F -q '| `v9.9.9` | see release notes | [release_notes_v9.9.9.md](release_notes_v9.9.9.md) |' "$release_index" || {
  echo "release notes helper did not update latest releases table" >&2
  cat "$release_index" >&2
  exit 1
}

first_history_line="$(awk '/^## Full history/{getline; getline; print; exit}' "$release_index")"
[[ "$first_history_line" == "- [release_notes_v9.9.9.md](release_notes_v9.9.9.md)" ]] || {
  echo "release notes helper did not prepend full history entry" >&2
  cat "$release_index" >&2
  exit 1
}

echo "release notes refs helper ok"
