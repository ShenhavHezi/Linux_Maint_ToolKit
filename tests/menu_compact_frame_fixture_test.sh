#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"
EXPECTED="$ROOT_DIR/tests/fixtures/menu_compact_frame.txt"

if ! command -v gum >/dev/null 2>&1; then
  echo "menu compact frame fixture skipped: gum not found"
  exit 0
fi

fixture_root="/tmp/linux_maint_menu_render_fixture"
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
TUI_MENU_STYLE=compact
NO_COLOR=1

tui_gum_render_menu_frame "Choose your next step" "main" $'overview|Dashboard, current state, and next moves [o]\nrun|Execute checks, preview plans, and scope runs [r]\nexport|Reports, metrics, JSON, and bundles [e]\n' 8 2>"$out"

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
  echo "menu compact frame fixture mismatch" >&2
  diff -u "$EXPECTED" "$norm" >&2 || true
  exit 1
fi

echo "menu compact frame fixture ok"
