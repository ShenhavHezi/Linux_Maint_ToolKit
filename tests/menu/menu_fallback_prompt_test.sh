#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
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
SUMMARY_DIR="$tmp_root/logs"
LM_STATE_DIR="$tmp_root/state"
mkdir -p "$LOG_DIR" "$LM_STATE_DIR"

out="$(tui_fallback_menu_prompt_body "Run checks" "run")"
[[ "$out" == *"Section:"* ]] || {
  echo "fallback prompt missing section block" >&2
  echo "$out" >&2
  exit 1
}
[[ "$out" == *"Preview scope first, then execute checks when the plan looks right."* ]] || {
  echo "fallback prompt missing section summary" >&2
  echo "$out" >&2
  exit 1
}
[[ "$out" == *"State:"* ]] || {
  echo "fallback prompt missing state block" >&2
  echo "$out" >&2
  exit 1
}
[[ "$out" == *"Recommended now:"* ]] || {
  echo "fallback prompt missing recommended block" >&2
  echo "$out" >&2
  exit 1
}
[[ "$out" == *"Highlighted action:"* ]] || {
  echo "fallback prompt missing highlighted action block" >&2
  echo "$out" >&2
  exit 1
}
[[ "$out" == *"start=first_setup"* ]] || {
  echo "fallback prompt should recommend first_setup for empty run context" >&2
  echo "$out" >&2
  exit 1
}
[[ "$out" == *"inventory=missing"* ]] || {
  echo "fallback prompt should expose missing inventory state" >&2
  echo "$out" >&2
  exit 1
}

mkdir -p "$LM_CFG_DIR"
printf '%s\n' "localhost" > "$LM_CFG_DIR/servers.txt"
cat > "$LM_CFG_DIR/inventory_meta.csv" <<'EOF'
host,tags,role,env
localhost,ops;web,web,prod
EOF
cat > "$LOG_DIR/full_health_monitor_summary_latest.json" <<'JSON'
{"rows":[{"monitor":"service_monitor","host":"web-1","status":"WARN","reason":"service_inactive"}],"problems":[{"monitor":"service_monitor","host":"web-1","status":"WARN","reason":"service_inactive"}],"reason_rollup":[{"reason":"service_inactive","count":1}],"totals":{"OK":0,"WARN":1,"CRIT":0,"UNKNOWN":0,"SKIP":0},"meta":{"overall":"WARN"}}
JSON

out="$(tui_fallback_menu_prompt_body "Repair" "repair")"
[[ "$out" == *"overall=WARN"* ]] || {
  echo "fallback prompt should reflect current overall status" >&2
  echo "$out" >&2
  exit 1
}
[[ "$out" == *"start=incident"* ]] || {
  echo "fallback prompt should recommend incident in repair context" >&2
  echo "$out" >&2
  exit 1
}
[[ "$out" == *"metadata=ok"* ]] || {
  echo "fallback prompt should expose inventory metadata state" >&2
  echo "$out" >&2
  exit 1
}
[[ "$out" == *"coverage=1/1"* ]] || {
  echo "fallback prompt should expose inventory coverage counts" >&2
  echo "$out" >&2
  exit 1
}

echo "menu fallback prompt ok"
