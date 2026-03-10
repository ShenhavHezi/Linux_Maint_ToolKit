#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

prefix="$workdir/prefix"
mkdir -p "$prefix/bin"

cp "$ROOT_DIR/bin/linux-maint" "$prefix/bin/linux-maint"
chmod +x "$prefix/bin/linux-maint"

set +e
out="$(PREFIX="$prefix" "$prefix/bin/linux-maint" make-tarball 2>&1)"
rc=$?
set -e

if [[ "$rc" -eq 0 ]]; then
  echo "installed make-tarball unexpectedly succeeded without a repo tree" >&2
  exit 1
fi

printf '%s\n' "$out" | grep -q 'requires a repo checkout or extracted release tree' || {
  echo "installed make-tarball did not explain repo-tree requirement" >&2
  echo "$out" >&2
  exit 1
}

echo "installed make-tarball repo requirement ok"
