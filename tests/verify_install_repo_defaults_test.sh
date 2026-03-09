#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

cfg_dir="$workdir/etc_linux_maint"
mkdir -p "$cfg_dir"
printf '%s\n' localhost > "$cfg_dir/servers.txt"
: > "$cfg_dir/excluded.txt"
: > "$cfg_dir/services.txt"

out="$(env -u LM_LOCKDIR -u LM_STATE_DIR -u LOG_DIR LM_CFG_DIR="$cfg_dir" bash "$LM" verify-install 2>&1)"

printf '%s\n' "$out" | grep -q '^OK: writable lockdir: /tmp$' || {
  echo "verify-install did not use repo-mode default lockdir" >&2
  echo "$out" >&2
  exit 1
}

printf '%s\n' "$out" | grep -q '^OK: writable state: /tmp$' || {
  echo "verify-install did not use repo-mode default state dir" >&2
  echo "$out" >&2
  exit 1
}

printf '%s\n' "$out" | grep -q "^OK: writable logs: $ROOT_DIR/.logs$" || {
  echo "verify-install did not use repo-mode default log dir" >&2
  echo "$out" >&2
  exit 1
}

printf '%s\n' "$out" | grep -q '^verify-install ok$' || {
  echo "verify-install did not complete successfully" >&2
  echo "$out" >&2
  exit 1
}

echo "verify-install repo defaults ok"
