#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

cfg="$(mktemp -d)"
trap 'rm -rf "$cfg"' EXIT

printf '%s\n' localhost > "$cfg/servers.txt"

out="$(LM_CFG_DIR="$cfg" LM_SERVERLIST="$cfg/servers.txt" LM_LOCAL_ONLY=true bash "$LM" baseline ports --local-only 2>&1 || true)"
printf '%s\n' "$out" | grep -q 'ports_baseline' || {
  echo "baseline ports output missing" >&2
  echo "$out" >&2
  exit 1
}

base_file="$cfg/baselines/ports/localhost.baseline"
if [[ ! -s "$base_file" ]]; then
  echo "baseline file not created: $base_file" >&2
  exit 1
fi

echo "baseline command ok"
