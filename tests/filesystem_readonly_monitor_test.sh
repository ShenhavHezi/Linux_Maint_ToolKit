#!/usr/bin/env bash
set -euo pipefail

TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
MON="$ROOT_DIR/monitors/filesystem_readonly_monitor.sh"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

mounts="$workdir/mounts"

run_case() {
  local label="$1"; shift
  local expect="$1"; shift
  printf '%s\n' "$@" > "$mounts"
  out="$(env LM_MOUNTS_FILE="$mounts" LM_LOCKDIR="$workdir" LM_LOGFILE="$workdir/fs_ro.log" bash "$MON")"
  echo "$out" | grep -q "$expect" || { echo "FAIL: $label: $out" >&2; exit 1; }
}

run_case "ok mounts" "status=OK" \
"/dev/sda1 / ext4 rw,relatime 0 0" \
"tmpfs /run tmpfs rw,nosuid 0 0"

run_case "readonly mount" "reason=filesystem_readonly" \
"/dev/sda1 / ext4 rw,relatime 0 0" \
"/dev/sda2 /data ext4 ro,relatime 0 0"

echo "filesystem readonly monitor ok"
