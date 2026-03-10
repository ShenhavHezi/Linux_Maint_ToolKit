#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"
EXPECTED="$ROOT_DIR/tests/fixtures/menu_all_sections.txt"

if ! command -v gum >/dev/null 2>&1; then
  echo "menu all sections fixture skipped: gum not found"
  exit 0
fi

fixture_root="/tmp/linux_maint_menu_render_fixture_probe"
out="$(mktemp)"
norm="$(mktemp)"

cleanup() {
  rm -rf "$fixture_root" 2>/dev/null || true
  rm -f "$out" "$norm"
}
trap cleanup EXIT

mkdir -p "$fixture_root/logs"
cat > "$fixture_root/logs/full_health_monitor_summary_latest.json" <<'JSON'
{"rows":[{"monitor":"network_monitor","host":"web-2","status":"CRIT","reason":"http_failed"},{"monitor":"service_monitor","host":"web-1","status":"WARN","reason":"service_inactive"}],"problems":[{"monitor":"network_monitor","host":"web-2","status":"CRIT","reason":"http_failed"}],"reason_rollup":[{"reason":"http_failed","count":1},{"reason":"service_inactive","count":1}],"totals":{"OK":0,"WARN":1,"CRIT":1,"UNKNOWN":0,"SKIP":0},"meta":{"overall":"CRIT"}}
JSON

source "$LM" >/dev/null 2>&1
MODE=repo
LOG_DIR="$fixture_root/logs"
LM_CFG_DIR=/tmp/linux_maint_cfg_fixture
LM_STATE_DIR=/tmp/linux_maint_state_fixture
TUI_BACKEND=gum
TUI_MENU_STYLE=full
NO_COLOR=1

render_one() {
  local title="$1" context="$2" catalog="$3" width="$4"
  printf '=== %s ===\n' "$title" >&2
  tui_gum_render_menu_frame "$title" "$context" "$catalog" "$width" 2>&2
}

{
  render_one "Quickstart" "quickstart" $'first_setup|Guide: first setup and safe first run [f]\ncurrent_incident|Guide: current incident triage [i]\nescalation|Guide: export and escalation workflow [e]\ninventory|Edit: servers.txt inventory [s]\ngroups|Open: hosts.d groups overview [g]\ndocs|Open: setup docs [d]\nback|Back to main menu [b]\n' 16
  render_one "Overview" "overview" $'dashboard|Open: live operations dashboard [d]\nstatus|Open: current status snapshot [s]\nproblems|Review: latest non-OK rows [p]\nreport|Review: short operator summary [r]\ntrend|Analyze: recent trend (last 10 runs) [t]\nback|Back to main menu [b]\n' 10
  render_one "Run checks" "run" $'run|Execute: run checks now (live output) [r] [changes]\nplan|Preview: resolved run plan only [p]\nwizard|Guide: guided run setup wizard [w]\nback|Back to main menu [b]\n' 8
  render_one "Triage" "triage" $'incident|Guide: incident response workflow [i]\ndrilldown|Inspect: filtered status drilldown [d]\nlogs|Inspect: latest wrapper log [l]\nreasons|Review: top reason tokens [r]\ndiff|Review: changes since previous run [x]\ncheck|Validate: config and readiness [c]\ndoctor|Diagnose: deeper checks and fixes [o] [changes]\nfocused_run|Run: focused service and network checks [f] [changes]\nhistory|Inspect: recent run history [h]\nback|Back to main menu [b]\n' 12
  render_one "Share" "share" $'report|Share: short report summary [r]\nexport_json|Export: unified snapshot JSON [e]\npack_logs|Bundle: guided support package [p] [changes]\ntrend|Review: recent trend (last 10 runs) [t]\nruntimes|Review: runtime summary (last 10 runs) [u]\nmetrics_prom|Export: Prometheus metrics [m]\nquickref|Read: quick command reference [h]\ntroubleshooting|Read: troubleshooting guide [g]\nconfig|Inspect: effective config [c]\nsettings|Adjust: menu preferences [s]\nabout|Inspect: version and project details [a]\nback|Back to main menu [b]\n' 16
} 2>"$out"

python3 - "$out" >"$norm" <<'PY'
import re
import sys

text = open(sys.argv[1], encoding="utf-8").read()
text = re.sub(r"\x1b\[[0-9;]*[A-Za-z]", "", text)
lines = [line.rstrip() for line in text.splitlines()]
while lines and not lines[0]:
    lines.pop(0)
while lines and not lines[-1]:
    lines.pop()
print("\n".join(lines))
PY

if ! diff -u "$EXPECTED" "$norm" >/dev/null; then
  echo "menu all sections fixture mismatch" >&2
  diff -u "$EXPECTED" "$norm" >&2 || true
  exit 1
fi

echo "menu all sections fixture ok"
