#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"
TMPDIR="${TMPDIR:-/tmp}"

if [[ "$(id -u)" -eq 0 ]]; then
  if ! command -v su >/dev/null 2>&1 || ! getent passwd nobody >/dev/null 2>&1; then
    echo "doctor --fix-deps root check skipped under root: no su/nobody"
    exit 0
  fi
  # The test needs to execute as non-root. Use a readable temp copy because the
  # original checkout may live under a private home directory.
  # shellcheck source=../testlib.sh
  . "$ROOT_DIR/tests/testlib.sh"
  workdir="$(mktemp -d -p "$TMPDIR")"
  trap 'rm -rf "$workdir"' EXIT
  repo="$workdir/repo"
  testlib_copy_repo_worktree "$repo"
  chmod 0755 "$workdir" "$repo"
  chmod -R a+rX "$repo"
  LM="$repo/bin/linux-maint"

  out="$(su -s /bin/bash nobody -c "bash '$LM' doctor --fix-deps --dry-run" 2>&1 || true)"
  printf '%s\n' "$out" | grep -qi 'requires root' || {
    echo "doctor --fix-deps should require root" >&2
    echo "$out" >&2
    exit 1
  }

  out2="$(su -s /bin/bash nobody -c "bash '$LM' doctor --fix-deps --dry-run --yes" 2>&1 || true)"
  printf '%s\n' "$out2" | grep -qi 'requires root' || {
    echo "doctor --fix-deps --dry-run should still require root" >&2
    echo "$out2" >&2
    exit 1
  }

  echo "doctor --fix-deps root check ok"
  exit 0
fi

out="$(bash "$LM" doctor --fix-deps --dry-run 2>&1 || true)"
printf '%s\n' "$out" | grep -qi 'requires root' || {
  echo "doctor --fix-deps should require root" >&2
  echo "$out" >&2
  exit 1
}

out2="$(bash "$LM" doctor --fix-deps --dry-run --yes 2>&1 || true)"
printf '%s\n' "$out2" | grep -qi 'requires root' || {
  echo "doctor --fix-deps --dry-run should still require root" >&2
  echo "$out2" >&2
  exit 1
}

echo "doctor --fix-deps root check ok"
