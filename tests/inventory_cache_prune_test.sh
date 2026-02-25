#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

export LINUX_MAINT_LIB="$ROOT_DIR/lib/linux_maint.sh"
export LM_SERVERLIST="$workdir/hosts.txt"
export LM_INVENTORY_OUTPUT_DIR="$workdir/out"
export LM_INVENTORY_CACHE_DIR="$workdir/cache"
export LM_INVENTORY_CACHE=1
export LM_INVENTORY_CACHE_TTL=99999
export LM_INVENTORY_CACHE_MAX=2
export LM_LOGFILE="$workdir/inventory_export.log"
export LM_LOCKDIR="$workdir/lock"
export LM_EMAIL_ENABLED=false

mkdir -p "$LM_INVENTORY_CACHE_DIR"

# Seed cache with three files (2 kv + 1 details) and set mtimes.
for name in a.kv b.kv c.kv; do
  echo "DATE=2026-02-24T10:00:00+0000" > "$LM_INVENTORY_CACHE_DIR/$name"
  sleep 1
  echo "x" >> "$LM_INVENTORY_CACHE_DIR/$name"
done
for name in a.details.txt b.details.txt c.details.txt; do
  echo "cached" > "$LM_INVENTORY_CACHE_DIR/$name"
  sleep 1
  echo "x" >> "$LM_INVENTORY_CACHE_DIR/$name"
done

# Provide a single host to keep run light.
echo "localhost" > "$LM_SERVERLIST"

bash "$ROOT_DIR/monitors/inventory_export.sh" >/dev/null 2>&1 || true

# Only the newest two files should remain (across kv/details), per prune logic.
count=$(find "$LM_INVENTORY_CACHE_DIR" -maxdepth 1 -type f \( -name '*.kv' -o -name '*.details.txt' \) | wc -l | tr -d ' ')
if [[ "$count" -gt 2 ]]; then
  echo "expected cache prune to keep <=2 files, found $count" >&2
  find "$LM_INVENTORY_CACHE_DIR" -type f -maxdepth 1 >&2 || true
  exit 1
fi

echo "inventory cache prune ok"
