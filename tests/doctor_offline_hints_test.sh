#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

cfg="$workdir/etc_linux_maint"
mkdir -p "$cfg"
printf '%s\n' localhost > "$cfg/servers.txt"
printf '%s\n' sshd > "$cfg/services.txt"
: > "$cfg/excluded.txt"
: > "$cfg/emails.txt"

out="$(LM_CFG_DIR="$cfg" "$ROOT_DIR/bin/linux-maint" doctor)"

echo "$out" | grep -Eq '^==+ Monitor gates \(what may SKIP\) ==+' 
echo "$out" | grep -Eq '^==+ Dependencies \(best-effort\) ==+' 
echo "$out" | grep -Eq '^==+ Fix suggestions ==+'
echo "$out" | grep -Eq '^==+ Next recommended actions ==+' 
echo "$out" | grep -Eq '^network_monitor[[:space:]]+MISSING[[:space:]]+'

echo "ok: doctor offline hints"
