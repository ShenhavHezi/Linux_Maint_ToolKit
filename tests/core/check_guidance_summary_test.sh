#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

cfg="$workdir/etc_linux_maint"
mkdir -p "$cfg" "$workdir/state" "$workdir/lock" "$workdir/logs"
printf '%s\n' localhost > "$cfg/servers.txt"
printf '%s\n' localhost > "$cfg/excluded.txt"
printf '%s\n' sshd > "$cfg/services.txt"

out="$(
  set +e
  LM_CFG_DIR="$cfg" \
  LM_STATE_DIR="$workdir/state" \
  LM_LOCKDIR="$workdir/lock" \
  LOG_DIR="$workdir/logs" \
  LM_PREFLIGHT_OPT_CMDS='awk sed grep df ssh' \
  bash "$LM" check 2>&1
  echo "__RC=$?"
)"

printf '%s\n' "$out" | grep -q '^== Guidance ==$' || {
  echo "check guidance header missing" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q '^next_step: linux-maint doctor$' || {
  echo "check doctor next_step missing" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q '^== Summary ==$' || {
  echo "check summary header missing" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q '^check warn$' || {
  echo "check final status missing" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q '^__RC=1$' || {
  echo "check rc marker missing" >&2
  echo "$out" >&2
  exit 1
}

echo "check guidance summary ok"

