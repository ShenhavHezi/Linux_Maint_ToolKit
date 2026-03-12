#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

cfg="$workdir/etc_linux_maint"
mkdir -p "$cfg"
printf '%s\n' localhost > "$cfg/servers.txt"
printf '%s\n' sshd > "$cfg/services.txt"
: > "$cfg/excluded.txt"
: > "$cfg/emails.txt"

out="$(LM_CFG_DIR="$cfg" "$LM" doctor)"

printf '%s\n' "$out" | grep -q '^== Guidance ==$' || {
  echo "doctor guidance header missing" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q '^next_step: linux-maint verify-install$' || {
  echo "doctor verify-install next_step missing" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q '^== Summary ==$' || {
  echo "doctor summary header missing" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -Eq '^doctor (ok|warn|crit)$' || {
  echo "doctor final status missing" >&2
  echo "$out" >&2
  exit 1
}

echo "doctor guidance summary ok"
