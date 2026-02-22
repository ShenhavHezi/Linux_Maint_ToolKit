#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

logdir="$workdir/logs"
mkdir -p "$logdir"

cat > "$logdir/full_health_monitor_2099-12-31_235959.log" <<'LOG'
[2026-02-18 00:00:00] RUNTIME monitor=slow ms=1200
[2026-02-18 00:00:00] RUNTIME monitor=fast ms=10
LOG

out="$(LOG_DIR="$logdir" bash "$ROOT_DIR/bin/linux-maint" runtimes)"
printf '%s\n' "$out" | grep -q '^monitor=slow ms=1200$'
printf '%s\n' "$out" | grep -q '^monitor=fast ms=10$'

warn_file="$workdir/monitor_runtime_warn.conf"
cat > "$warn_file" <<'WARN'
slow=1
WARN
color_out="$(NO_COLOR= LM_FORCE_COLOR=1 MONITOR_RUNTIME_WARN_FILE="$warn_file" LOG_DIR="$logdir" bash "$ROOT_DIR/bin/linux-maint" runtimes)"
printf '%s\n' "$color_out" | grep -q $'\033' || {
  echo "runtimes output should contain ANSI when warn threshold exceeded and color forced" >&2
  echo "$color_out" >&2
  exit 1
}

json_out="$(LOG_DIR="$logdir" bash "$ROOT_DIR/bin/linux-maint" runtimes --json)"
python3 -c 'import json,sys; obj=json.loads(sys.stdin.read()); rows=obj.get("rows",[]); assert any(r.get("monitor")=="slow" and r.get("ms")==1200 for r in rows); assert any(r.get("monitor")=="fast" and r.get("ms")==10 for r in rows)' <<<"$json_out"

echo "ok: runtimes command"
