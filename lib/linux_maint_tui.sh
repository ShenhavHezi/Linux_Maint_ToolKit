#!/usr/bin/env bash
# TUI/menu state and settings helpers for linux-maint.

menu_settings_path() {
  local cfg_home="${XDG_CONFIG_HOME:-$HOME/.config}"
  printf '%s/linux-maint/menu.conf' "$cfg_home"
}

sanitize_int_range() {
  local int_raw="$1" min="$2" max="$3" fallback="$4"
  if [[ "$int_raw" =~ ^[0-9]+$ ]]; then
    if (( int_raw < min )); then
      printf '%s' "$min"
      return 0
    fi
    if (( int_raw > max )); then
      printf '%s' "$max"
      return 0
    fi
    printf '%s' "$int_raw"
    return 0
  fi
  printf '%s' "$fallback"
}

normalize_menu_settings() {
  local backend="${LM_TUI_BACKEND:-}"
  case "$backend" in
    ""|gum|dialog|whiptail) ;;
    *) unset LM_TUI_BACKEND ;;
  esac
  LM_TUI_DASH_REFRESH="$(sanitize_int_range "${LM_TUI_DASH_REFRESH:-0}" 0 300 0)"
  LM_TUI_DEFAULT_PROBLEMS="$(sanitize_int_range "${LM_TUI_DEFAULT_PROBLEMS:-20}" 1 100 20)"
  LM_TUI_DEFAULT_REASONS="$(sanitize_int_range "${LM_TUI_DEFAULT_REASONS:-5}" 0 20 5)"
  case "${LM_TUI_DEFAULT_STATUS_VIEW:-table}" in
    table|compact) ;;
    *) LM_TUI_DEFAULT_STATUS_VIEW="table" ;;
  esac
  case "${LM_TUI_PREVIEW:-1}" in
    1|0|true|false|TRUE|FALSE|yes|no|YES|NO|on|off|ON|OFF) ;;
    *) LM_TUI_PREVIEW=1 ;;
  esac
  case "${LM_TUI_SHORTCUTS:-1}" in
    1|0|true|false|TRUE|FALSE|yes|no|YES|NO|on|off|ON|OFF) ;;
    *) LM_TUI_SHORTCUTS=1 ;;
  esac
  case "${LM_TUI_COMPACT:-0}" in
    1|0|true|false|TRUE|FALSE|yes|no|YES|NO|on|off|ON|OFF) ;;
    *) LM_TUI_COMPACT=0 ;;
  esac
  case "${LM_TUI_LOW_COLOR:-0}" in
    1|0|true|false|TRUE|FALSE|yes|no|YES|NO|on|off|ON|OFF) ;;
    *) LM_TUI_LOW_COLOR=0 ;;
  esac
  case "${LM_TUI_CONFIRM_RISKY:-1}" in
    1|0|true|false|TRUE|FALSE|yes|no|YES|NO|on|off|ON|OFF) ;;
    *) LM_TUI_CONFIRM_RISKY=1 ;;
  esac
  export LM_TUI_DASH_REFRESH LM_TUI_DEFAULT_PROBLEMS LM_TUI_DEFAULT_REASONS LM_TUI_DEFAULT_STATUS_VIEW LM_TUI_PREVIEW LM_TUI_SHORTCUTS LM_TUI_COMPACT LM_TUI_LOW_COLOR LM_TUI_CONFIRM_RISKY
}

load_menu_settings() {
  local f
  f="$(menu_settings_path)"
  [[ -f "$f" ]] || return 0
  while IFS='=' read -r k v; do
    [[ -n "$k" ]] || continue
    [[ "$k" =~ ^[A-Z0-9_]+$ ]] || continue
    case "$k" in
      LM_TUI_BACKEND|LM_TUI_DASH_REFRESH|LM_TUI_DEFAULT_STATUS_VIEW|LM_TUI_DEFAULT_PROBLEMS|LM_TUI_DEFAULT_REASONS|LM_TUI_PREVIEW|LM_TUI_SHORTCUTS|LM_TUI_COMPACT|LM_TUI_LOW_COLOR|LM_TUI_CONFIRM_RISKY)
        v="${v%\"}"
        v="${v#\"}"
        case "$v" in
          *$'\n'*|*$'\r'*) continue ;;
        esac
        export "$k=$v"
        ;;
    esac
  done < "$f"
  normalize_menu_settings
}

save_menu_settings() {
  normalize_menu_settings
  local f d
  f="$(menu_settings_path)"
  d="$(dirname "$f")"
  mkdir -p "$d" 2>/dev/null || return 1
  cat > "$f" <<EOF
LM_TUI_BACKEND=${LM_TUI_BACKEND:-}
LM_TUI_DASH_REFRESH=${LM_TUI_DASH_REFRESH:-0}
LM_TUI_DEFAULT_STATUS_VIEW=${LM_TUI_DEFAULT_STATUS_VIEW:-table}
LM_TUI_DEFAULT_PROBLEMS=${LM_TUI_DEFAULT_PROBLEMS:-20}
LM_TUI_DEFAULT_REASONS=${LM_TUI_DEFAULT_REASONS:-5}
LM_TUI_PREVIEW=${LM_TUI_PREVIEW:-1}
LM_TUI_SHORTCUTS=${LM_TUI_SHORTCUTS:-1}
LM_TUI_COMPACT=${LM_TUI_COMPACT:-0}
LM_TUI_LOW_COLOR=${LM_TUI_LOW_COLOR:-0}
LM_TUI_CONFIRM_RISKY=${LM_TUI_CONFIRM_RISKY:-1}
EOF
}

menu_settings_reset_defaults() {
  unset LM_TUI_BACKEND
  export LM_TUI_DASH_REFRESH=0
  export LM_TUI_DEFAULT_STATUS_VIEW=table
  export LM_TUI_DEFAULT_PROBLEMS=20
  export LM_TUI_DEFAULT_REASONS=5
  export LM_TUI_PREVIEW=1
  export LM_TUI_SHORTCUTS=1
  export LM_TUI_COMPACT=0
  export LM_TUI_LOW_COLOR=0
  export LM_TUI_CONFIRM_RISKY=1
}

tui_command_risk_level() {
  local argv0="${1:-}" sub="${2:-}" cmd_text="${3:-}"
  case "$sub" in
    run|doctor|pack-logs|init) printf 'changes' ;;
    baseline)
      if [[ "$cmd_text" == *"--update"* ]]; then
        printf 'changes'
      else
        printf 'read-only'
      fi
      ;;
    *) printf 'read-only' ;;
  esac
}

tui_command_risk_badge() {
  case "$1" in
    changes) printf 'Changes system' ;;
    read-only) printf 'Read-only' ;;
    *) printf 'Safe' ;;
  esac
}

tui_bool_enabled() {
  case "${1:-0}" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

tui_effective_cfg_dir() {
  linux_maint_effective_cfg_dir
}

tui_effective_log_dir() {
  linux_maint_effective_log_dir
}

tui_effective_summary_dir() {
  linux_maint_effective_summary_dir
}

tui_effective_state_dir() {
  linux_maint_effective_state_dir
}

tui_effective_serverlist_path() {
  local cfg_dir
  cfg_dir="$(tui_effective_cfg_dir)"
  printf '%s' "${LM_SERVERLIST:-$cfg_dir/servers.txt}"
}

tui_effective_hosts_dir() {
  local cfg_dir
  cfg_dir="$(tui_effective_cfg_dir)"
  printf '%s' "$cfg_dir/hosts.d"
}

tui_effective_history_db_path() {
  local state_dir
  state_dir="$(tui_effective_state_dir)"
  printf '%s' "${LM_HISTORY_DB:-$state_dir/run_index.sqlite}"
}

tui_effective_run_index_path() {
  local state_dir index_file alt
  state_dir="$(tui_effective_state_dir)"
  index_file="${LM_RUN_INDEX_FILE:-$state_dir/run_index.jsonl}"
  if [[ ! -f "$index_file" && -z "${LM_RUN_INDEX_FILE:-}" && -z "${LM_STATE_DIR:-}" ]]; then
    for alt in /var/tmp/run_index.jsonl /var/tmp/linux_maint/run_index.jsonl /tmp/linux_maint/run_index.jsonl; do
      if [[ -f "$alt" ]]; then
        index_file="$alt"
        break
      fi
    done
  fi
  printf '%s' "$index_file"
}

tui_latest_log_path() {
  linux_maint_effective_latest_log
}

tui_latest_summary_json_path() {
  linux_maint_effective_summary_json_latest
}

tui_status_snapshot_json() {
  local summary_json
  summary_json="$(tui_latest_summary_json_path)"
  if [[ -f "$summary_json" ]]; then
    cat "$summary_json" 2>/dev/null || true
  fi
}

tui_inventory_snapshot_json() {
  local cfg_dir meta_file servers_file hosts_dir
  cfg_dir="$(tui_effective_cfg_dir)"
  meta_file="${LM_INVENTORY_META:-$(linux_maint_effective_inventory_meta_file)}"
  servers_file="$(tui_effective_serverlist_path)"
  hosts_dir="$(tui_effective_hosts_dir)"
  linux_maint_inventory_snapshot_json "$cfg_dir" "$meta_file" "$servers_file" "$hosts_dir"
}

tui_has_inventory_config() {
  local serverlist hosts_dir
  serverlist="$(tui_effective_serverlist_path)"
  [[ -s "$serverlist" ]] && return 0
  hosts_dir="$(tui_effective_hosts_dir)"
  if [[ -d "$hosts_dir" ]] && compgen -G "$hosts_dir/*.txt" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

tui_has_summary_snapshot() {
  local summary_json
  summary_json="$(tui_latest_summary_json_path)"
  [[ -s "$summary_json" ]]
}

tui_has_latest_log() {
  local log_file
  log_file="$(tui_latest_log_path)"
  [[ -s "$log_file" ]]
}

tui_has_history_artifacts() {
  local index_file history_db
  index_file="$(tui_effective_run_index_path)"
  history_db="$(tui_effective_history_db_path)"
  [[ -s "$index_file" || -s "$history_db" ]]
}

tui_format_age_seconds() {
  local age="${1:-}"
  if [[ -z "$age" || "$age" == "-1" ]]; then
    printf 'missing'
    return 0
  fi
  if (( age < 60 )); then
    printf '%ss' "$age"
  elif (( age < 3600 )); then
    printf '%sm' $(( age / 60 ))
  elif (( age < 86400 )); then
    printf '%sh' $(( age / 3600 ))
  else
    printf '%sd' $(( age / 86400 ))
  fi
}

tui_context_snapshot() {
  local status_json="${1:-}"
  if [[ -z "$status_json" ]]; then
    status_json="$(tui_status_snapshot_json)"
  fi
  local inventory_json
  inventory_json="$(tui_inventory_snapshot_json)"
  local log_file cfg_dir log_dir state_dir config_dir_exists inventory_ready summary_ready log_ready history_ready
  log_file="$(tui_latest_log_path)"
  cfg_dir="$(tui_effective_cfg_dir)"
  log_dir="$(tui_effective_log_dir)"
  state_dir="$(tui_effective_state_dir)"
  config_dir_exists=0
  inventory_ready=0
  summary_ready=0
  log_ready=0
  history_ready=0
  [[ -d "$cfg_dir" ]] && config_dir_exists=1
  tui_has_inventory_config && inventory_ready=1
  tui_has_summary_snapshot && summary_ready=1
  tui_has_latest_log && log_ready=1
  tui_has_history_artifacts && history_ready=1
  STATUS_JSON="$status_json" INVENTORY_JSON="$inventory_json" MODE_LOCAL="$MODE" LOG_FILE="$log_file" CFG_DIR_LOCAL="$cfg_dir" LOG_DIR_LOCAL="$log_dir" STATE_DIR_LOCAL="$state_dir" \
    SHORTCUTS_LOCAL="${LM_TUI_SHORTCUTS:-1}" PREVIEW_LOCAL="${LM_TUI_PREVIEW:-1}" CONFIG_DIR_EXISTS_LOCAL="$config_dir_exists" \
    INVENTORY_READY_LOCAL="$inventory_ready" SUMMARY_READY_LOCAL="$summary_ready" LOG_READY_LOCAL="$log_ready" HISTORY_READY_LOCAL="$history_ready" python3 - <<'PY'
import json
import os
import time

raw = os.environ.get("STATUS_JSON", "")
overall = "UNKNOWN"
totals = {"OK": 0, "WARN": 0, "CRIT": 0, "UNKNOWN": 0, "SKIP": 0}
try:
    data = json.loads(raw) if raw else {}
except Exception:
    data = {}
try:
    inventory = json.loads(os.environ.get("INVENTORY_JSON", "") or "{}")
except Exception:
    inventory = {}
if not isinstance(inventory, dict):
    inventory = {}
totals_in = data.get("totals") or {}
if not totals_in and (data.get("rows") or []):
    for row in data.get("rows") or []:
        st = str((row or {}).get("status") or "")
        if st in totals:
            totals[st] += 1
for key in totals:
    if totals_in:
        try:
            totals[key] = int(totals_in.get(key, 0) or 0)
        except Exception:
            totals[key] = 0
overall = str(
    (data.get("last_status") or {}).get("overall")
    or (data.get("meta") or {}).get("overall")
    or overall
)
if not overall or overall == "UNKNOWN":
    if totals["CRIT"] > 0:
        overall = "CRIT"
    elif totals["WARN"] > 0:
        overall = "WARN"
    elif totals["UNKNOWN"] > 0:
        overall = "UNKNOWN"
    elif totals["OK"] > 0:
        overall = "OK"
    else:
        overall = "UNKNOWN"

log_file = os.environ.get("LOG_FILE", "")
age_sec = -1
if log_file:
    try:
        age_sec = max(0, int(time.time() - os.path.getmtime(log_file)))
    except Exception:
        age_sec = -1

print(f"mode={os.environ.get('MODE_LOCAL', '')}")
print(f"cfg_dir={os.environ.get('CFG_DIR_LOCAL', '')}")
print(f"log_dir={os.environ.get('LOG_DIR_LOCAL', '')}")
print(f"state_dir={os.environ.get('STATE_DIR_LOCAL', '')}")
print(f"overall={overall}")
print(f"ok={totals['OK']}")
print(f"warn={totals['WARN']}")
print(f"crit={totals['CRIT']}")
print(f"unknown={totals['UNKNOWN']}")
print(f"skip={totals['SKIP']}")
print(f"last_age={age_sec}")
print(f"shortcuts={os.environ.get('SHORTCUTS_LOCAL', '1')}")
print(f"preview={os.environ.get('PREVIEW_LOCAL', '1')}")
print(f"config_dir_exists={os.environ.get('CONFIG_DIR_EXISTS_LOCAL', '0')}")
print(f"inventory_ready={os.environ.get('INVENTORY_READY_LOCAL', '0')}")
print(f"summary_ready={os.environ.get('SUMMARY_READY_LOCAL', '0')}")
print(f"log_ready={os.environ.get('LOG_READY_LOCAL', '0')}")
print(f"history_ready={os.environ.get('HISTORY_READY_LOCAL', '0')}")
summary = inventory.get("summary") or {}
coverage = inventory.get("coverage") or {}
inventory_hosts = int(summary.get("inventory_hosts", 0) or 0)
metadata_hosts = int(summary.get("metadata_hosts", 0) or 0)
meta_present = bool(inventory.get("meta_present"))
result = str(inventory.get("result") or "WARN").lower()
if not inventory_hosts and not meta_present:
    inventory_state = "missing"
elif result == "error":
    inventory_state = "error"
elif result == "ok":
    inventory_state = "ok"
else:
    inventory_state = "warn"
print(f"inventory_meta_state={inventory_state}")
print(f"inventory_meta_present={1 if meta_present else 0}")
print(f"inventory_hosts={inventory_hosts}")
print(f"inventory_metadata_hosts={metadata_hosts}")
print(f"inventory_missing_hosts={int(summary.get('missing_metadata_hosts', 0) or 0)}")
print(f"inventory_coverage_percent={int(summary.get('coverage_percent', 0) or 0)}")
print(f"inventory_role_count={len(coverage.get('roles') or [])}")
print(f"inventory_env_count={len(coverage.get('envs') or [])}")
print(f"inventory_tag_count={len(coverage.get('tags') or [])}")
PY
}

tui_snapshot_value() {
  local snapshot="${1:-}" key="${2:-}"
  printf '%s\n' "$snapshot" | awk -F= -v key="$key" '$1 == key { sub(/^[^=]*=/, ""); print; exit }'
}

tui_bootstrap_state_snapshot() {
  local cfg_dir serverlist hosts_dir summary_json log_file index_file history_db inventory_json
  local config_dir_exists=0 inventory_ready=0 summary_ready=0 log_ready=0 history_ready=0 optional_skips_present=0
  cfg_dir="$(tui_effective_cfg_dir)"
  serverlist="$(tui_effective_serverlist_path)"
  hosts_dir="$(tui_effective_hosts_dir)"
  summary_json="$(tui_latest_summary_json_path)"
  log_file="$(tui_latest_log_path)"
  index_file="$(tui_effective_run_index_path)"
  history_db="$(tui_effective_history_db_path)"
  [[ -d "$cfg_dir" ]] && config_dir_exists=1
  tui_has_inventory_config && inventory_ready=1
  [[ -s "$summary_json" ]] && summary_ready=1
  [[ -s "$log_file" ]] && log_ready=1
  tui_has_history_artifacts && history_ready=1
  inventory_json="$(tui_inventory_snapshot_json)"
  if expected_skips_text "$cfg_dir" >/dev/null 2>&1; then
    optional_skips_present=1
  fi
  printf 'cfg_dir=%s\n' "$cfg_dir"
  printf 'serverlist=%s\n' "$serverlist"
  printf 'hosts_dir=%s\n' "$hosts_dir"
  printf 'summary_json=%s\n' "$summary_json"
  printf 'log_file=%s\n' "$log_file"
  printf 'run_index=%s\n' "$index_file"
  printf 'history_db=%s\n' "$history_db"
  printf 'config_dir_exists=%s\n' "$config_dir_exists"
  printf 'inventory_ready=%s\n' "$inventory_ready"
  printf 'summary_ready=%s\n' "$summary_ready"
  printf 'log_ready=%s\n' "$log_ready"
  printf 'history_ready=%s\n' "$history_ready"
  printf 'optional_skips_present=%s\n' "$optional_skips_present"
  INVENTORY_JSON="$inventory_json" python3 - <<'PY'
import json
import os
try:
    payload = json.loads(os.environ.get("INVENTORY_JSON", "") or "{}")
except Exception:
    payload = {}
summary = payload.get("summary") or {}
coverage = payload.get("coverage") or {}
inventory_hosts = int(summary.get("inventory_hosts", 0) or 0)
meta_present = bool(payload.get("meta_present"))
result = str(payload.get("result") or "WARN").lower()
if not inventory_hosts and not meta_present:
    state = "missing"
elif result == "error":
    state = "error"
elif result == "ok":
    state = "ok"
else:
    state = "warn"
print(f"inventory_meta_state={state}")
print(f"inventory_hosts={inventory_hosts}")
print(f"inventory_metadata_hosts={int(summary.get('metadata_hosts', 0) or 0)}")
print(f"inventory_missing_hosts={int(summary.get('missing_metadata_hosts', 0) or 0)}")
print(f"inventory_coverage_percent={int(summary.get('coverage_percent', 0) or 0)}")
print(f"inventory_role_count={len(coverage.get('roles') or [])}")
print(f"inventory_env_count={len(coverage.get('envs') or [])}")
print(f"inventory_tag_count={len(coverage.get('tags') or [])}")
PY
}

tui_optional_skip_lines() {
  local cfg_dir="${1:-$(tui_effective_cfg_dir)}" limit="${2:-4}"
  local out
  if ! out="$(expected_skips_text "$cfg_dir" 2>/dev/null)"; then
    printf '%s\n' "- none: optional monitor inputs are already present"
    return 0
  fi
  printf '%s\n' "$out" | awk 'NR>1 {print}' | head -n "$limit"
}

tui_bootstrap_missing_lines() {
  local snapshot="${1:-}"
  [[ -n "$snapshot" ]] || snapshot="$(tui_bootstrap_state_snapshot)"
  local cfg_dir serverlist hosts_dir summary_json log_file run_index config_dir_exists inventory_ready summary_ready log_ready history_ready optional_skips_present printed
  cfg_dir="$(tui_snapshot_value "$snapshot" cfg_dir)"
  serverlist="$(tui_snapshot_value "$snapshot" serverlist)"
  hosts_dir="$(tui_snapshot_value "$snapshot" hosts_dir)"
  summary_json="$(tui_snapshot_value "$snapshot" summary_json)"
  log_file="$(tui_snapshot_value "$snapshot" log_file)"
  run_index="$(tui_snapshot_value "$snapshot" run_index)"
  config_dir_exists="$(tui_snapshot_value "$snapshot" config_dir_exists)"
  inventory_ready="$(tui_snapshot_value "$snapshot" inventory_ready)"
  summary_ready="$(tui_snapshot_value "$snapshot" summary_ready)"
  log_ready="$(tui_snapshot_value "$snapshot" log_ready)"
  history_ready="$(tui_snapshot_value "$snapshot" history_ready)"
  optional_skips_present="$(tui_snapshot_value "$snapshot" optional_skips_present)"
  printed=0
  if [[ "$config_dir_exists" != "1" ]]; then
    printf '%s\n' "- config dir missing: $cfg_dir"
    printed=1
  fi
  if [[ "$inventory_ready" != "1" ]]; then
    printf '%s\n' "- inventory not configured: $serverlist or $hosts_dir/*.txt"
    printed=1
  fi
  if [[ "$summary_ready" != "1" ]]; then
    printf '%s\n' "- no summary snapshot yet: $summary_json"
    printed=1
  fi
  if [[ "$log_ready" != "1" ]]; then
    printf '%s\n' "- no wrapper log yet: $log_file"
    printed=1
  fi
  if [[ "$history_ready" != "1" ]]; then
    printf '%s\n' "- no history index yet: $run_index"
    printed=1
  fi
  if [[ "$optional_skips_present" == "1" ]]; then
    printf '%s\n' "- optional monitor inputs are still unset for some checks"
    printed=1
  fi
  if [[ "$printed" -eq 0 ]]; then
    printf '%s\n' "- ready: config, logs, summary, and history are present"
  fi
}

tui_bootstrap_next_steps_lines() {
  local snapshot="${1:-}"
  [[ -n "$snapshot" ]] || snapshot="$(tui_bootstrap_state_snapshot)"
  local serverlist hosts_dir config_dir_exists inventory_ready summary_ready history_ready
  serverlist="$(tui_snapshot_value "$snapshot" serverlist)"
  hosts_dir="$(tui_snapshot_value "$snapshot" hosts_dir)"
  config_dir_exists="$(tui_snapshot_value "$snapshot" config_dir_exists)"
  inventory_ready="$(tui_snapshot_value "$snapshot" inventory_ready)"
  summary_ready="$(tui_snapshot_value "$snapshot" summary_ready)"
  history_ready="$(tui_snapshot_value "$snapshot" history_ready)"
  if [[ "$config_dir_exists" != "1" || "$inventory_ready" != "1" ]]; then
    printf '%s\n' \
      "- Use Quickstart -> first setup to create starter config safely" \
      "- Add targets in $serverlist or create groups under $hosts_dir" \
      "- Run check, then run --plan before the first live execution"
    return 0
  fi
  if [[ "$summary_ready" != "1" ]]; then
    printf '%s\n' \
      "- Run check to validate config and readiness" \
      "- Run run --plan to confirm scope and expected skips" \
      "- Execute run when the preview looks right"
    return 0
  fi
  if [[ "$history_ready" != "1" ]]; then
    printf '%s\n' \
      "- Run again after the next change so history and trend can compare runs" \
      "- Use Overview for the current answer and Share for report or JSON output" \
      "- Capture starter baselines if you want cleaner drift monitoring"
    return 0
  fi
  printf '%s\n' \
    "- Use Overview for the current answer fast" \
    "- Use Triage for drilldown, logs, and guided recovery" \
    "- Use Share when you need a report, JSON, bundle, or docs"
}
