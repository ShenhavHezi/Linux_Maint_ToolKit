#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

source "$LM" >/dev/null 2>&1

tmp_root="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp_root"
}
trap cleanup EXIT

MODE=repo
LM_CFG_DIR="$tmp_root/cfg"
LOG_DIR="$tmp_root/logs"
SUMMARY_DIR="$tmp_root/summary"
LM_STATE_DIR="$tmp_root/state"
mkdir -p "$LM_CFG_DIR" "$LOG_DIR" "$SUMMARY_DIR" "$LM_STATE_DIR"
printf '%s\n' "localhost" > "$LM_CFG_DIR/servers.txt"
touch "$LOG_DIR/full_health_monitor_latest.log"
touch "$LM_STATE_DIR/run_index.jsonl"
cat > "$SUMMARY_DIR/full_health_monitor_summary_latest.json" <<'JSON'
{"rows":[{"monitor":"network_monitor","host":"web-2","status":"CRIT","reason":"http_failed"}],"problems":[{"monitor":"network_monitor","host":"web-2","status":"CRIT","reason":"http_failed"}],"reason_rollup":[{"reason":"http_failed","count":1}],"totals":{"OK":0,"WARN":0,"CRIT":1,"UNKNOWN":0,"SKIP":0},"meta":{"overall":"CRIT"}}
JSON

status_json="$(tui_status_snapshot_json)"
boot_snapshot="$(tui_bootstrap_state_snapshot)"

aliases="$(tui_palette_aliases pack_logs export)"
[[ "$aliases" == *bundle* ]] || {
  echo "pack_logs aliases should include bundle, got: $aliases" >&2
  exit 1
}

report_rank="$(tui_palette_rank report export "$status_json" "$boot_snapshot")"
back_rank="$(tui_palette_rank back export "$status_json" "$boot_snapshot")"
(( report_rank > back_rank )) || {
  echo "expected report rank ($report_rank) > back rank ($back_rank)" >&2
  exit 1
}

logs_rank="$(tui_palette_rank logs investigate "$status_json" "$boot_snapshot")"
about_rank="$(tui_palette_rank about docs "$status_json" "$boot_snapshot")"
(( logs_rank > about_rank )) || {
  echo "expected logs rank ($logs_rank) > about rank ($about_rank)" >&2
  exit 1
}

rm -f "$SUMMARY_DIR/full_health_monitor_summary_latest.json"
missing_boot="$(tui_bootstrap_state_snapshot)"
first_setup_rank="$(tui_palette_rank first_setup overview "" "$missing_boot")"
report_missing_rank="$(tui_palette_rank report overview "" "$missing_boot")"
(( first_setup_rank > report_missing_rank )) || {
  echo "expected first_setup rank ($first_setup_rank) > report rank ($report_missing_rank) in empty state" >&2
  exit 1
}

echo "menu palette rank ok"
