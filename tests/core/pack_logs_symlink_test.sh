#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

logdir="$workdir/logs"
cfgdir="$workdir/etc_linux_maint"
statedir="$workdir/state"
outdir="$workdir/out"
mkdir -p "$logdir" "$cfgdir" "$statedir" "$outdir"

target_log="$logdir/full_health_monitor_2026-03-09_000000.log"
printf 'real log contents\n' > "$target_log"
ln -s "$(basename "$target_log")" "$logdir/full_health_monitor_latest.log"

bundle_path="$(OUTDIR="$outdir" LOG_DIR="$logdir" CFG_DIR="$cfgdir" STATE_DIR="$statedir" "$ROOT_DIR/tools/pack_logs.sh")"
[[ -f "$bundle_path" ]] || {
  echo "pack-logs did not create bundle" >&2
  exit 1
}

entry_line="$(tar -tvzf "$bundle_path" | grep './logs/full_health_monitor_latest.log')"
case "$entry_line" in
  -*) ;;
  *)
    echo "expected full_health_monitor_latest.log to be stored as a regular file, got: $entry_line" >&2
    exit 1
    ;;
esac

extracted="$workdir/extracted_latest.log"
tar -xOf "$bundle_path" ./logs/full_health_monitor_latest.log > "$extracted"
grep -q '^real log contents$' "$extracted" || {
  echo "pack-logs did not dereference symlink content" >&2
  cat "$extracted" >&2
  exit 1
}

echo "pack-logs symlink ok"
