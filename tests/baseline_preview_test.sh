#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

cfg="$(mktemp -d)"
trap 'rm -rf "$cfg"' EXIT

printf '%s\n' localhost > "$cfg/servers.txt"

# create baseline first
LM_CFG_DIR="$cfg" LM_SERVERLIST="$cfg/servers.txt" LM_LOCAL_ONLY=true \
  bash "$LM" baseline users --local-only >/dev/null 2>&1 || true

out_show="$(LM_CFG_DIR="$cfg" LM_SERVERLIST="$cfg/servers.txt" LM_LOCAL_ONLY=true bash "$LM" baseline users --show 2>&1 || true)"
printf '%s\n' "$out_show" | grep -q 'baseline snapshot' || {
  echo "baseline --show missing snapshot output" >&2
  echo "$out_show" >&2
  exit 1
}

out_diff="$(LM_CFG_DIR="$cfg" LM_SERVERLIST="$cfg/servers.txt" LM_LOCAL_ONLY=true bash "$LM" baseline users --diff 2>&1 || true)"
printf '%s\n' "$out_diff" | grep -q 'baseline diff' || {
  echo "baseline --diff missing diff output" >&2
  echo "$out_diff" >&2
  exit 1
}

echo "baseline preview ok"
