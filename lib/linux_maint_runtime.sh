#!/usr/bin/env bash
# Runtime/path setup helpers for linux-maint.

lm_init_runtime_context() {
  REPO_MONITORS="$REPO_ROOT/monitors"
  REPO_LIB="$REPO_ROOT/lib/linux_maint.sh"
  REPO_WRAPPER="$REPO_ROOT/run_full_health_monitor.sh"

  if [[ -n "${PREFIX:-}" ]]; then
    :
  elif [[ -d "$REPO_MONITORS" && -f "$REPO_LIB" ]]; then
    PREFIX="/usr/local"
  elif [[ "$SCRIPT_DIR" == */bin ]]; then
    PREFIX="$(cd -- "$SCRIPT_DIR/.." && pwd)"
  else
    PREFIX="/usr/local"
  fi

  SBIN="$PREFIX/sbin"
  LIBEXEC="$PREFIX/libexec/linux_maint"
  SHARE="$PREFIX/share/linux_maint"

  wrapper="$SBIN/run_full_health_monitor.sh"
  preflight="$LIBEXEC/preflight_check.sh"
  validate="$LIBEXEC/config_validate.sh"

  if [[ -d "$REPO_MONITORS" && -f "$REPO_LIB" ]]; then
    export LINUX_MAINT_LIB="${LINUX_MAINT_LIB:-$REPO_LIB}"
    export LM_LOCKDIR="${LM_LOCKDIR:-/tmp}"
    export LM_LOGFILE="${LM_LOGFILE:-/tmp/linux_maint.log}"
    wrapper="$REPO_WRAPPER"
    preflight="$REPO_MONITORS/preflight_check.sh"
    validate="$REPO_MONITORS/config_validate.sh"
  else
    export LINUX_MAINT_LIB="${LINUX_MAINT_LIB:-$PREFIX/lib/linux_maint.sh}"
  fi

  MODE="installed"
  [[ "$wrapper" == "$REPO_WRAPPER" ]] && MODE="repo"
  export LINUX_MAINT_LIB="$(lm_core_library_path)"
  REPO_LOG_DIR="${LOG_DIR:-$REPO_ROOT/.logs}"
  REPO_SUMMARY_DIR="${SUMMARY_DIR:-$REPO_LOG_DIR}"
  REPO_STATUS_FILE="$REPO_LOG_DIR/last_status_full"
  REPO_LATEST_LOG="$REPO_LOG_DIR/full_health_monitor_latest.log"
  REPO_SUMMARY_LATEST="$REPO_SUMMARY_DIR/full_health_monitor_summary_latest.log"
  REPO_SUMMARY_JSON_LATEST="$REPO_SUMMARY_DIR/full_health_monitor_summary_latest.json"
  INST_SUMMARY_LATEST="${SUMMARY_DIR:-${LOG_DIR:-/var/log/health}}/full_health_monitor_summary_latest.log"
}

linux_maint_mode_default() {
  local repo_default="$1"
  local installed_default="$2"
  if [[ "$MODE" == "repo" ]]; then
    printf '%s' "$repo_default"
  else
    printf '%s' "$installed_default"
  fi
}

linux_maint_env_or_mode_default() {
  local env_name="$1"
  local repo_default="$2"
  local installed_default="$3"
  if [[ -n "${!env_name:-}" ]]; then
    printf '%s' "${!env_name}"
  else
    linux_maint_mode_default "$repo_default" "$installed_default"
  fi
}

linux_maint_effective_cfg_dir() {
  linux_maint_env_or_mode_default LM_CFG_DIR "$REPO_ROOT/.etc_linux_maint" "/etc/linux_maint"
}

linux_maint_effective_inventory_meta_file() {
  printf '%s/inventory_meta.csv' "$(linux_maint_effective_cfg_dir)"
}

linux_maint_inventory_snapshot_json() {
  local cfg_dir="${1:-$(linux_maint_effective_cfg_dir)}"
  local meta_file="${2:-${LM_INVENTORY_META:-$(linux_maint_effective_inventory_meta_file)}}"
  local servers_file="${3:-${LM_SERVERLIST:-$cfg_dir/servers.txt}}"
  local hosts_dir="${4:-${LM_HOSTS_DIR:-$cfg_dir/hosts.d}}"
  META_FILE="$meta_file" CFG_DIR="$cfg_dir" SERVERS_FILE="$servers_file" HOSTS_DIR="$hosts_dir" python3 - <<'PY'
import csv
import json
import os
import re
from collections import Counter
from pathlib import Path

meta_file = Path(os.environ["META_FILE"])
cfg_dir = os.environ["CFG_DIR"]
servers_file = Path(os.environ["SERVERS_FILE"])
hosts_dir = Path(os.environ["HOSTS_DIR"])

expected_columns = ["host", "tags", "role", "env"]
warnings = []
next_steps = []
invalid_rows = []
duplicate_hosts = []
missing_metadata_hosts = []
extra_metadata_hosts = []
roles = Counter()
envs = Counter()
tags = Counter()
inventory_hosts = set()
metadata_hosts = []
metadata_hosts_set = set()
groups = set()

def add_warning(msg):
    if msg not in warnings:
        warnings.append(msg)

def add_next(msg):
    if msg not in next_steps:
        next_steps.append(msg)

def load_hosts_file(path):
    hosts = set()
    if not path.is_file():
        return hosts
    for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = raw.split("#", 1)[0].replace(",", " ").strip()
        if not line:
            continue
        for token in line.split():
            if token:
                hosts.add(token)
    return hosts

inventory_hosts.update(load_hosts_file(servers_file))
if hosts_dir.is_dir():
    for group_file in sorted(hosts_dir.glob("*.txt")):
        groups.add(group_file.stem)
        inventory_hosts.update(load_hosts_file(group_file))

if meta_file.exists() and not os.access(meta_file, os.R_OK):
    payload = {
        "schema_version": 1,
        "inventory_snapshot_version": 1,
        "inventory_lint_json_contract_version": 1,
        "meta_file": str(meta_file),
        "meta_present": True,
        "meta_readable": False,
        "cfg_dir": cfg_dir,
        "servers_file": str(servers_file),
        "hosts_dir": str(hosts_dir),
        "header_ok": False,
        "unknown_columns": [],
        "duplicate_hosts": [],
        "invalid_rows": [],
        "missing_metadata_hosts": [],
        "extra_metadata_hosts": [],
        "summary": {
            "inventory_hosts": len(inventory_hosts),
            "metadata_hosts": 0,
            "duplicate_hosts": 0,
            "missing_metadata_hosts": 0,
            "extra_metadata_hosts": 0,
            "invalid_rows": 0,
            "groups": len(groups),
            "roles": 0,
            "envs": 0,
            "tags": 0,
            "coverage_percent": 0,
        },
        "coverage": {"roles": [], "envs": [], "tags": []},
        "warnings": [],
        "next_steps": ["fix permissions on inventory_meta.csv and rerun inventory lint"],
        "error": "inventory metadata is unreadable",
        "result": "ERROR",
    }
    print(json.dumps(payload, indent=2, sort_keys=True))
    raise SystemExit(0)

header_ok = False
unknown_columns = []
if meta_file.is_file():
    rows = meta_file.read_text(encoding="utf-8", errors="ignore").splitlines()
    active_rows = []
    for raw in rows:
        stripped = raw.strip()
        if not stripped or stripped.startswith("#"):
            continue
        active_rows.append(raw)
    if active_rows:
        try:
            reader = csv.reader(active_rows)
            header = [cell.strip().lower() for cell in next(reader, [])]
        except Exception as exc:
            add_warning(f"inventory_meta.csv is not valid CSV: {exc}")
            add_next("fix CSV syntax in inventory_meta.csv")
            header = []
            reader = []
        if header:
            header_ok = header[:4] == expected_columns and len(header) == 4
            unknown_columns = [col for col in header if col not in expected_columns]
            if not header_ok:
                add_warning("inventory_meta.csv header should be exactly: host,tags,role,env")
                add_next("rewrite the header to host,tags,role,env")
            if unknown_columns:
                add_warning("inventory_meta.csv contains unknown columns: " + ",".join(unknown_columns))
                add_next("remove unknown columns from inventory_meta.csv")
            row_num = 1
            host_counts = Counter()
            for raw_row in reader:
                row_num += 1
                row = [cell.strip() for cell in raw_row]
                if not row or not any(row):
                    continue
                while len(row) < 4:
                    row.append("")
                host, tag_field, role, env = row[:4]
                if not host:
                    invalid_rows.append(f"line {row_num}: empty host")
                    continue
                if host.lower() == "host":
                    invalid_rows.append(f"line {row_num}: duplicate header row")
                    continue
                host_counts[host] += 1
                metadata_hosts.append(host)
                metadata_hosts_set.add(host)
                role_l = role.lower()
                env_l = env.lower()
                if role_l:
                    roles[role_l] += 1
                if env_l:
                    envs[env_l] += 1
                bad_tag_format = False
                normalized = tag_field.replace("|", ";")
                if " " in normalized:
                    bad_tag_format = True
                parts = [part.strip().lower() for part in normalized.split(";")]
                if any(part == "" for part in parts if normalized != ""):
                    bad_tag_format = True
                for part in parts:
                    if not part:
                        continue
                    if not re.match(r"^[A-Za-z0-9._-]+$", part):
                        bad_tag_format = True
                    tags[part] += 1
                if bad_tag_format:
                    invalid_rows.append(f"line {row_num}: invalid tag formatting for host {host}")
                if not role_l:
                    invalid_rows.append(f"line {row_num}: missing role for host {host}")
                if not env_l:
                    invalid_rows.append(f"line {row_num}: missing env for host {host}")
            duplicate_hosts = sorted(host for host, count in host_counts.items() if count > 1)
            if duplicate_hosts:
                add_warning("inventory_meta.csv contains duplicate hosts: " + ",".join(duplicate_hosts))
                add_next("deduplicate hosts in inventory_meta.csv")
    else:
        add_warning("inventory_meta.csv is empty")
        add_next("populate inventory_meta.csv with host,tags,role,env rows or remove it")
else:
    add_warning("inventory_meta.csv is missing")
    add_next("create inventory_meta.csv if you want role/env/tag targeting and coverage reporting")

if invalid_rows:
    add_warning(f"inventory_meta.csv has {len(invalid_rows)} invalid or incomplete rows")
    add_next("fix invalid rows in inventory_meta.csv")

if inventory_hosts:
    missing_metadata_hosts = sorted(inventory_hosts - metadata_hosts_set)
    extra_metadata_hosts = sorted(metadata_hosts_set - inventory_hosts)
    if missing_metadata_hosts:
        add_warning(f"{len(missing_metadata_hosts)} inventory hosts are missing metadata")
        add_next("add metadata rows for missing inventory hosts")
    if extra_metadata_hosts:
        add_warning(f"{len(extra_metadata_hosts)} metadata hosts are not present in servers.txt or hosts.d")
        add_next("remove stale metadata rows or add those hosts back to inventory")
else:
    add_warning("no inventory hosts were found in servers.txt or hosts.d")
    add_next("add hosts to servers.txt or hosts.d before relying on inventory targeting")

inventory_host_count = len(inventory_hosts)
metadata_host_count = len(metadata_hosts_set)
coverage_percent = 0
if inventory_host_count > 0:
    coverage_percent = int(round((metadata_host_count / inventory_host_count) * 100))

result = "OK" if not warnings else "WARN"
payload = {
    "schema_version": 1,
    "inventory_snapshot_version": 1,
    "inventory_lint_json_contract_version": 1,
    "meta_file": str(meta_file),
    "meta_present": meta_file.is_file(),
    "meta_readable": True,
    "cfg_dir": cfg_dir,
    "servers_file": str(servers_file),
    "hosts_dir": str(hosts_dir),
    "header_ok": header_ok,
    "unknown_columns": unknown_columns,
    "duplicate_hosts": duplicate_hosts,
    "invalid_rows": invalid_rows,
    "missing_metadata_hosts": missing_metadata_hosts,
    "extra_metadata_hosts": extra_metadata_hosts,
    "summary": {
        "inventory_hosts": inventory_host_count,
        "metadata_hosts": metadata_host_count,
        "duplicate_hosts": len(duplicate_hosts),
        "missing_metadata_hosts": len(missing_metadata_hosts),
        "extra_metadata_hosts": len(extra_metadata_hosts),
        "invalid_rows": len(invalid_rows),
        "groups": len(groups),
        "roles": len(roles),
        "envs": len(envs),
        "tags": len(tags),
        "coverage_percent": coverage_percent,
    },
    "coverage": {
        "roles": sorted(roles),
        "envs": sorted(envs),
        "tags": sorted(tags),
    },
    "warnings": warnings,
    "next_steps": next_steps,
    "result": result,
}
print(json.dumps(payload, indent=2, sort_keys=True))
PY
}

linux_maint_effective_log_dir() {
  linux_maint_env_or_mode_default LOG_DIR "$REPO_LOG_DIR" "/var/log/health"
}

linux_maint_effective_summary_dir() {
  if [[ -n "${SUMMARY_DIR:-}" ]]; then
    printf '%s' "$SUMMARY_DIR"
  else
    linux_maint_mode_default "$REPO_SUMMARY_DIR" "$(linux_maint_effective_log_dir)"
  fi
}

linux_maint_effective_state_dir() {
  local repo_default="${1:-$REPO_LOG_DIR}"
  local installed_default="${2:-/var/lib/linux_maint}"
  linux_maint_env_or_mode_default LM_STATE_DIR "$repo_default" "$installed_default"
}

linux_maint_effective_lock_dir() {
  local repo_default="${1:-/tmp}"
  local installed_default="${2:-/var/lock}"
  linux_maint_env_or_mode_default LM_LOCKDIR "$repo_default" "$installed_default"
}

linux_maint_effective_notify_state_dir() {
  local repo_default="${1:-$REPO_LOG_DIR}"
  local installed_default="${2:-/var/lib/linux_maint}"
  if [[ -n "${LM_NOTIFY_STATE_DIR:-}" ]]; then
    printf '%s' "$LM_NOTIFY_STATE_DIR"
  else
    linux_maint_effective_state_dir "$repo_default" "$installed_default"
  fi
}

linux_maint_effective_status_file() {
  printf '%s/last_status_full' "$(linux_maint_effective_log_dir)"
}

linux_maint_effective_latest_log() {
  printf '%s/full_health_monitor_latest.log' "$(linux_maint_effective_log_dir)"
}

linux_maint_effective_summary_latest() {
  printf '%s/full_health_monitor_summary_latest.log' "$(linux_maint_effective_summary_dir)"
}

linux_maint_effective_summary_json_latest() {
  printf '%s/full_health_monitor_summary_latest.json' "$(linux_maint_effective_summary_dir)"
}

linux_maint_effective_plugin_trust_policy_file() {
  printf '%s/plugin_trust_policy.json' "$(linux_maint_effective_cfg_dir)"
}

lm_core_library_path() {
  local installed_lib="$PREFIX/lib/linux_maint.sh"
  if [[ "$MODE" == "repo" ]]; then
    printf '%s' "${LINUX_MAINT_LIB:-$REPO_LIB}"
    return 0
  fi
  if [[ -f "$installed_lib" ]]; then
    printf '%s' "$installed_lib"
    return 0
  fi
  printf '%s' "${LINUX_MAINT_LIB:-$installed_lib}"
}

repo_tool_path() {
  printf '%s' "$REPO_ROOT/tools/$1"
}

installed_helper_path() {
  printf '%s' "$LIBEXEC/$1"
}

require_repo_tree_command() {
  local subcmd_label="$1"
  echo "ERROR: linux-maint $subcmd_label requires a repo checkout or extracted release tree." >&2
  echo "Run it from the project directory where install.sh/tools are present." >&2
  exit 1
}

need_root_for() {
  local req_cmd="$1"
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    if color_enabled; then
      echo "${C_RED}ERROR:${C_RESET} linux-maint $req_cmd requires root (installed mode)." >&2
    else
      echo "ERROR: linux-maint $req_cmd requires root (installed mode)." >&2
    fi
    case "$req_cmd" in
      run)
        hint_line "sudo linux-maint run" >&2
        echo "      (or run the wrapper directly: sudo /usr/local/sbin/run_full_health_monitor.sh)" >&2
        ;;
      status)
        hint_line "sudo linux-maint status" >&2
        ;;
      logs)
        hint_line "sudo linux-maint logs 200" >&2
        ;;
      preflight)
        hint_line "sudo linux-maint preflight" >&2
        ;;
      validate)
        hint_line "sudo linux-maint validate" >&2
        ;;
      check)
        hint_line "sudo linux-maint check" >&2
        ;;
      config)
        hint_line "sudo linux-maint config" >&2
        ;;
      doctor)
        hint_line "sudo linux-maint doctor" >&2
        ;;
      serve)
        hint_line "sudo linux-maint serve --host 127.0.0.1 --port 8080" >&2
        ;;
      agent)
        hint_line "sudo linux-maint agent --once" >&2
        ;;
      history)
        hint_line "sudo linux-maint history --last 10" >&2
        ;;
      run-index)
        hint_line "sudo linux-maint run-index --stats" >&2
        ;;
      summary)
        hint_line "sudo linux-maint summary" >&2
        ;;
      trend)
        hint_line "sudo linux-maint trend --last 10" >&2
        ;;
      runtimes)
        hint_line "sudo linux-maint runtimes --last 10" >&2
        ;;
      export)
        hint_line "sudo linux-maint export --json" >&2
        ;;
      metrics)
        hint_line "sudo linux-maint metrics --json" >&2
        ;;
      gate)
        hint_line "sudo linux-maint gate --policy /etc/linux_maint/policy.conf" >&2
        ;;
      plugin)
        hint_line "sudo linux-maint plugin <subcommand>" >&2
        ;;
      init)
        hint_line "sudo linux-maint init" >&2
        ;;
      tune)
        hint_line "sudo linux-maint tune dark-site" >&2
        ;;
      baseline)
        hint_line "sudo linux-maint baseline <kind> --update" >&2
        ;;
      *)
        hint_line "sudo linux-maint $req_cmd" >&2
        ;;
    esac
    exit 1
  fi
}
