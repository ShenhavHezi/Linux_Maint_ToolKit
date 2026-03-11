#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

prefix="$workdir/prefix"
cfg="$workdir/etc_linux_maint"
logs="$workdir/logs"
summary="$workdir/summary"
state="$workdir/state"
lock="$workdir/lock"
mkdir -p "$prefix/bin" "$prefix/sbin" "$prefix/lib" "$prefix/libexec/linux_maint" \
  "$prefix/share/linux_maint" "$cfg" "$logs" "$summary" "$state" "$lock"

cp "$ROOT_DIR/bin/linux-maint" "$prefix/bin/linux-maint"
chmod +x "$prefix/bin/linux-maint"
for support_lib in linux_maint_runtime.sh linux_maint_admin.sh linux_maint_help.sh linux_maint_tui.sh linux_maint_reporting.sh linux_maint_advanced.sh; do
  cp "$ROOT_DIR/lib/$support_lib" "$prefix/lib/$support_lib"
done

printf '#!/usr/bin/env bash\nexit 0\n' > "$prefix/sbin/run_full_health_monitor.sh"
chmod +x "$prefix/sbin/run_full_health_monitor.sh"
printf '# library\n' > "$prefix/lib/linux_maint.sh"
printf '# conf helper\n' > "$prefix/lib/linux_maint_conf.sh"
printf 'project=Linux_Maint_ToolKit\nversion=v0.0.0\ncommit=test\n' > "$prefix/share/linux_maint/BUILD_INFO"
cat > "$prefix/libexec/linux_maint/summary_diff.py" <<'EOF'
#!/usr/bin/env python3
import json
import sys

prev_path, cur_path = sys.argv[1:3]
json_mode = len(sys.argv) > 3 and sys.argv[3] == "--json"

def read_rows(path):
    rows = {}
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        for raw in f:
            raw = raw.strip()
            if not raw or not raw.startswith("monitor="):
                continue
            row = {}
            for token in raw.split():
                if "=" in token:
                    k, v = token.split("=", 1)
                    row[k] = v
            key = f'{row.get("monitor","")}|{row.get("host","")}'
            rows[key] = row
    return rows

prev_rows = read_rows(prev_path)
cur_rows = read_rows(cur_path)
added = []
removed = []
changed = []
for key, row in cur_rows.items():
    if key not in prev_rows:
        added.append({"key": key, "current": row})
    elif prev_rows[key] != row:
        changed.append({"key": key, "previous": prev_rows[key], "current": row})
for key, row in prev_rows.items():
    if key not in cur_rows:
        removed.append({"key": key, "previous": row})

payload = {
    "schema_version": 1,
    "diff_json_contract_version": 1,
    "diff_prev": prev_path,
    "diff_cur": cur_path,
    "added": added,
    "removed": removed,
    "changed": changed,
}

if json_mode:
    print(json.dumps(payload, sort_keys=True))
else:
    print(f"diff_prev={prev_path}")
    print(f"diff_cur={cur_path}")
EOF
chmod +x "$prefix/libexec/linux_maint/summary_diff.py"

printf '%s\n' localhost > "$cfg/servers.txt"
: > "$cfg/excluded.txt"
: > "$cfg/services.txt"
cat > "$cfg/linux-maint.conf" <<'EOF'
LM_NOTIFY=0
EOF

cat > "$logs/last_status_full" <<EOF
overall=CRIT
exit_code=2
timestamp=2026-03-11T01:02:03Z
run_id=run-installed-001
logfile=$logs/full_health_monitor_latest.log
EOF

cat > "$summary/full_health_monitor_summary_latest.log" <<'EOF'
monitor=health_monitor host=localhost status=OK
monitor=service_monitor host=web-1 status=WARN reason=failed_units
monitor=network_monitor host=web-2 status=CRIT reason=http_failed
EOF

cat > "$summary/full_health_monitor_summary_latest.json" <<'EOF'
{
  "meta": {
    "generated_at": "2026-03-11T01:02:03Z"
  },
  "rows": [
    {"monitor": "health_monitor", "host": "localhost", "status": "OK"},
    {"monitor": "service_monitor", "host": "web-1", "status": "WARN", "reason": "failed_units"},
    {"monitor": "network_monitor", "host": "web-2", "status": "CRIT", "reason": "http_failed"}
  ]
}
EOF

cat > "$summary/full_health_monitor_summary_2026-03-11_010203.log" <<'EOF'
monitor=health_monitor host=localhost status=OK
monitor=service_monitor host=web-1 status=WARN reason=failed_units
monitor=network_monitor host=web-2 status=CRIT reason=http_failed
EOF

cat > "$logs/full_health_monitor_2026-03-11_010203.log" <<'EOF'
[2026-03-11 01:02:03] RUNTIME monitor=service_monitor ms=1200
[2026-03-11 01:02:03] RUNTIME monitor=health_monitor ms=10
EOF

cat > "$logs/full_health_monitor_latest.log" <<'EOF'
[2026-03-11 01:02:03] SUMMARY_RESULT overall=CRIT exit_code=2
[2026-03-11 01:02:03] SUMMARY_HOSTS ok=1 warn=1 crit=1 unknown=0 skipped=0
EOF

cat > "$state/last_summary_monitor_lines.log" <<'EOF'
monitor=health_monitor host=localhost status=OK
monitor=service_monitor host=web-1 status=OK
monitor=network_monitor host=web-2 status=OK
EOF

lm="$prefix/bin/linux-maint"
common_env=(
  "PREFIX=$prefix"
  "LM_CFG_DIR=$cfg"
  "LOG_DIR=$logs"
  "SUMMARY_DIR=$summary"
  "LM_STATE_DIR=$state"
  "LM_LOCKDIR=$lock"
  "NO_COLOR=1"
)

status_out="$(env "${common_env[@]}" "$lm" status --json 2>&1)"
printf '%s' "$status_out" | python3 -c 'import json,sys; obj=json.load(sys.stdin); assert obj["last_status"]["run_id"]=="run-installed-001"; assert obj["totals"]["CRIT"]==1; assert obj["totals"]["WARN"]==1'

report_out="$(env "${common_env[@]}" "$lm" report --json 2>&1)"
printf '%s' "$report_out" | python3 -c 'import json,sys; obj=json.load(sys.stdin); assert obj["report_json_contract_version"]==1; assert obj["status"]["last_status"]["overall"]=="CRIT"'

summary_out="$(env "${common_env[@]}" "$lm" summary 2>&1)"
printf '%s\n' "$summary_out" | grep -q '^overall=CRIT ' || {
  echo "installed summary should run without root" >&2
  echo "$summary_out" >&2
  exit 1
}

metrics_out="$(env "${common_env[@]}" "$lm" metrics --json 2>&1)"
printf '%s' "$metrics_out" | python3 -c 'import json,sys; obj=json.load(sys.stdin); assert obj["metrics_json_contract_version"]==1; assert obj["host_counts"]["CRIT"]==1; assert any(r["monitor"]=="service_monitor" for r in obj["slow_monitors_top"])'

trend_out="$(env "${common_env[@]}" "$lm" trend --last 1 --json 2>&1)"
printf '%s' "$trend_out" | python3 -c 'import json,sys; obj=json.load(sys.stdin); assert obj["trend_json_contract_version"]==1; assert len(obj["runs"])==1; assert obj["runs"][0]["totals"]["CRIT"]==1'

runtimes_out="$(env "${common_env[@]}" "$lm" runtimes --last 1 --json 2>&1)"
printf '%s' "$runtimes_out" | python3 -c 'import json,sys; obj=json.load(sys.stdin); assert obj["runtimes_json_contract_version"]==1; assert any(r["monitor"]=="service_monitor" and r["ms"]==1200 for r in obj["rows"])'

export_out="$(env "${common_env[@]}" "$lm" export --json 2>&1)"
printf '%s' "$export_out" | python3 -c 'import json,sys; obj=json.load(sys.stdin); assert obj["mode"]=="installed"; assert obj["last_status"]["overall"]=="CRIT"; assert len(obj["rows"])==3'

diff_out="$(env "${common_env[@]}" "$lm" diff --json 2>&1)"
printf '%s' "$diff_out" | python3 -c 'import json,sys; obj=json.load(sys.stdin); assert "added" in obj; assert "changed" in obj; assert any(item["key"]=="service_monitor|web-1" for item in obj["changed"]); assert any(item["key"]=="network_monitor|web-2" for item in obj["changed"])'

echo "installed reporting commands ok"
