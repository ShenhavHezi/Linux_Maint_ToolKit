#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

workdir="$(mktemp -d -p "${TMPDIR:-/tmp}")"
trap 'rm -rf "$workdir"' EXIT

# Use a writable TMPDIR under workdir.
TMPDIR="$workdir/tmp"
mkdir -p "$TMPDIR"

# Force LM_STATE_DIR to an unwritable location to trigger fallback.
LM_STATE_DIR="/proc"

# Source library and create a temp file via lm_mktemp.
# Expect the file to be created under TMPDIR.
# shellcheck disable=SC1090
. "$ROOT_DIR/lib/linux_maint.sh"

f="$(lm_mktemp lm_mktemp_test.XXXXXX)"

if [[ -z "$f" || ! -f "$f" ]]; then
  echo "lm_mktemp did not create a file" >&2
  exit 1
fi

case "$f" in
  "$TMPDIR"/*) : ;;
  *)
    echo "lm_mktemp did not use TMPDIR fallback: $f" >&2
    exit 1
    ;;
esac

rm -f "$f" 2>/dev/null || true

echo "ok: lm_mktemp fallback"
