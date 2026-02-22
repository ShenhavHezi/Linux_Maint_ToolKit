#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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

json_out="$(LOG_DIR="$logdir" bash "$ROOT_DIR/bin/linux-maint" runtimes --json)"
python3 -c 'import json,sys; obj=json.loads(sys.stdin.read()); rows=obj.get("rows",[]); assert obj.get("unit")=="ms"; assert any(r.get("monitor")=="slow" and r.get("unit")=="ms" and r.get("source_file") for r in rows); assert any(r.get("monitor")=="fast" and r.get("unit")=="ms" and r.get("source_file") for r in rows)' <<<"$json_out"
printf '%s' "$json_out" | python3 "$ROOT_DIR/tools/json_schema_validate.py" "$ROOT_DIR/docs/schemas/runtimes.json"

echo "ok: runtimes json fields"
