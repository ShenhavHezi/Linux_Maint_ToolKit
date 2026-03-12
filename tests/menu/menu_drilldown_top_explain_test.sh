#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

source "$LM" >/dev/null 2>&1

export LM_TUI_DRILL_JSON
LM_TUI_DRILL_JSON="$(cat <<'JSON'
{"problems":[{"status":"WARN","monitor":"service_monitor","host":"db-01","reason":"service_inactive"},{"status":"CRIT","monitor":"disk_trend_monitor","host":"db-02","reason":"disk_full"}]}
JSON
)"

top="$(tui_status_drilldown_top_problem "WARN" "" "" "" || true)"
[[ "$top" == "service_monitor|service_inactive" ]] || {
  echo "unexpected top filtered row: $top" >&2
  exit 1
}

top="$(tui_status_drilldown_top_problem "CRIT" "db-02" "" "" || true)"
[[ "$top" == "disk_trend_monitor|disk_full" ]] || {
  echo "unexpected host filtered top row: $top" >&2
  exit 1
}

top="$(tui_status_drilldown_top_problem "OK" "" "" "" || true)"
[[ -z "${top:-}" ]] || {
  echo "expected empty top row for unmatched filter, got: $top" >&2
  exit 1
}

echo "menu drilldown top explain ok"
