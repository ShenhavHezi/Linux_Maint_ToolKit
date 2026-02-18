#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

cfg="$workdir/etc_linux_maint"
mkdir -p "$cfg"
printf '%s\n' localhost > "$cfg/servers.txt"
printf '%s\n' sshd > "$cfg/services.txt"
printf '%s\n' > "$cfg/excluded.txt"
printf '%s\n' > "$cfg/emails.txt"

out="$(LM_CFG_DIR="$cfg" "$ROOT_DIR/bin/linux-maint" doctor)"

echo "$out" | grep -q '^== Monitor gates (what may SKIP) ==' 
echo "$out" | grep -q '^== Dependencies (best-effort) ==' 
echo "$out" | grep -q '^== Next recommended actions ==' 
echo "$out" | grep -q "^SKIP gate: network_monitor -> missing/empty "

echo "ok: doctor offline hints"
