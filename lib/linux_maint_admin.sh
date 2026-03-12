#!/usr/bin/env bash
# Install/release/admin command helpers for linux-maint.

linux_maint_cmd_version() {
  local mode="raw" build_info="$SHARE/BUILD_INFO"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --short) mode="short"; shift ;;
      --json) mode="json"; shift ;;
      -h|--help)
        command_usage version
        exit 0
        ;;
      *)
        echo "ERROR: unknown version flag: $1" >&2
        exit 2
        ;;
    esac
  done
  if [[ ! -f "$build_info" ]]; then
    echo "BUILD_INFO not found at $build_info" >&2
    exit 1
  fi
  case "$mode" in
    raw)
      cat "$build_info"
      ;;
    short)
      python3 - "$build_info" <<'PY'
import sys
from pathlib import Path

fields = {}
for line in Path(sys.argv[1]).read_text(encoding="utf-8", errors="ignore").splitlines():
    if "=" not in line:
        continue
    key, value = line.split("=", 1)
    fields[key] = value

version = fields.get("version", "unknown")
commit = fields.get("commit", "unknown")
built = fields.get("build_time_utc", "unknown")
print(f"linux-maint {version} (commit {commit}, built {built})")
PY
      ;;
    json)
      python3 - "$build_info" <<'PY'
import json
import sys
from pathlib import Path

fields = {}
for line in Path(sys.argv[1]).read_text(encoding="utf-8", errors="ignore").splitlines():
    if "=" not in line:
        continue
    key, value = line.split("=", 1)
    fields[key] = value

payload = {
    "schema_version": 1,
    "version_json_contract_version": 1,
    "build_info_file": sys.argv[1],
}
payload.update(fields)
print(json.dumps(payload, indent=2, sort_keys=True))
PY
      ;;
  esac
}

linux_maint_exec_repo_installer() {
  local script="$1"
  shift || true
  if [[ "$(id -u)" -eq 0 ]]; then
    exec "$script" "$@"
  fi
  if command -v sudo >/dev/null 2>&1; then
    exec sudo "$script" "$@"
  fi
  echo "ERROR: repo-mode install commands need root, and sudo is not available." >&2
  echo "Run as root or install sudo." >&2
  exit 1
}

linux_maint_cmd_install_passthrough() {
  local subcmd="$1"
  shift || true
  if [[ "${MODE:-}" != "repo" ]]; then
    require_repo_tree_command "$subcmd"
  fi
  case "$subcmd" in
    install)
      linux_maint_exec_repo_installer "$REPO_ROOT/install.sh" "$@"
      ;;
    uninstall)
      linux_maint_exec_repo_installer "$REPO_ROOT/install.sh" --uninstall "$@"
      ;;
    make-tarball)
      exec "$(repo_tool_path make_tarball.sh)" "$@"
      ;;
    *)
      echo "ERROR: unsupported install passthrough command: $subcmd" >&2
      exit 2
      ;;
  esac
}

linux_maint_cmd_verify_release() {
  local verify_tool=""
  if [[ "$MODE" == "repo" ]]; then
    verify_tool="$(repo_tool_path verify_release.sh)"
  else
    verify_tool="$(installed_helper_path verify_release.sh)"
  fi
  if [[ ! -x "$verify_tool" ]]; then
    echo "ERROR: verify-release helper not found: $verify_tool" >&2
    exit 1
  fi
  exec "$verify_tool" "$@"
}

linux_maint_cmd_upgrade() {
  local upgrade_tool="" upgrade_verify_tool=""
  if [[ "$MODE" == "repo" ]]; then
    upgrade_tool="$(repo_tool_path upgrade_release.sh)"
    upgrade_verify_tool="$(repo_tool_path verify_release.sh)"
  else
    upgrade_tool="$(installed_helper_path upgrade_release.sh)"
    upgrade_verify_tool="$(installed_helper_path verify_release.sh)"
  fi
  if [[ ! -x "$upgrade_tool" ]]; then
    echo "ERROR: upgrade helper not found: $upgrade_tool" >&2
    exit 1
  fi
  LINUX_MAINT_PREFIX="$PREFIX" \
  LINUX_MAINT_LIBEXEC="$LIBEXEC" \
  LINUX_MAINT_SHARE="$SHARE" \
  LINUX_MAINT_UPGRADE_VERIFY_TOOL="$upgrade_verify_tool" \
  exec "$upgrade_tool" "$@"
}

linux_maint_cmd_verify_install() {
  section "linux-maint verify-install"
  echo "mode=$MODE"
  echo "prefix=$PREFIX"
  # shellcheck disable=SC2154  # Populated by lm_init_runtime_context.
  echo "wrapper=$wrapper"
  echo "lib=${LINUX_MAINT_LIB:-$PREFIX/lib/linux_maint.sh}"

  local fail=0 fail_count=0 warn_count=0 ok_count=0
  local -a next_steps=()

  linux_maint_add_next_step() {
    local msg="$1"
    local existing=""
    for existing in "${next_steps[@]}"; do
      [[ "$existing" == "$msg" ]] && return 0
    done
    next_steps+=("$msg")
  }

  linux_maint_echo_ok() {
    ok_count=$((ok_count + 1))
    echo "${C_GREEN}OK${C_RESET}: $*"
  }

  linux_maint_echo_warn() {
    warn_count=$((warn_count + 1))
    echo "${C_YELLOW}WARN${C_RESET}: $*" >&2
  }

  linux_maint_echo_fail() {
    fail=1
    fail_count=$((fail_count + 1))
    echo "${C_RED}MISSING${C_RESET}: $*" >&2
  }

  linux_maint_check_file() {
    local label="$1" path="$2"
    if [[ -e "$path" ]]; then
      linux_maint_echo_ok "$label: $path"
    else
      linux_maint_echo_fail "$label: $path"
    fi
  }

  linux_maint_check_exec() {
    local label="$1" path="$2"
    if [[ -x "$path" ]]; then
      linux_maint_echo_ok "$label: $path"
    elif [[ -e "$path" ]]; then
      echo "${C_RED}NOT EXECUTABLE${C_RESET}: $label: $path" >&2
      fail=1
      fail_count=$((fail_count + 1))
    else
      linux_maint_echo_fail "$label: $path"
    fi
  }

  linux_maint_check_writable_dir() {
    local label="$1" path="$2"
    if [[ -d "$path" ]]; then
      if [[ -w "$path" ]]; then
        linux_maint_echo_ok "writable $label: $path"
      else
        linux_maint_echo_warn "not writable $label: $path"
        case "$label" in
          lockdir|state|logs)
            linux_maint_add_next_step "rerun with sudo if you want installed-mode writable path checks to pass"
            ;;
        esac
      fi
    else
      linux_maint_echo_warn "missing dir $label: $path"
      linux_maint_add_next_step "create or configure $label path: $path"
    fi
  }

  linux_maint_check_release_support_libs() {
    local manifest="$1" lib_name=""
    if [[ ! -f "$manifest" ]]; then
      linux_maint_echo_fail "support lib manifest: $manifest"
      return
    fi
    linux_maint_check_file "support lib manifest" "$manifest"
    while IFS= read -r lib_name; do
      [[ -n "$lib_name" ]] || continue
      linux_maint_check_file "support lib" "$PREFIX/lib/$lib_name"
    done < "$manifest"
  }

  if [[ "$MODE" == "installed" ]]; then
    linux_maint_check_exec "binary" "$PREFIX/bin/linux-maint"
  fi
  linux_maint_check_exec "wrapper" "$wrapper"
  linux_maint_check_file "library" "${LINUX_MAINT_LIB:-$PREFIX/lib/linux_maint.sh}"
  if [[ "$MODE" == "installed" ]]; then
    linux_maint_check_file "library config helper" "$PREFIX/lib/linux_maint_conf.sh"
    linux_maint_check_release_support_libs "$PREFIX/lib/RELEASE_LIBS.txt"
  fi

  if [[ "$MODE" == "repo" ]]; then
    linux_maint_check_file "monitors dir" "$REPO_MONITORS"
    linux_maint_check_file "tools dir" "$REPO_ROOT/tools"
  else
    linux_maint_check_file "libexec" "$LIBEXEC"
    linux_maint_check_exec "summary diff helper" "$LIBEXEC/summary_diff.py"
    linux_maint_check_exec "pack-logs helper" "$LIBEXEC/pack_logs.sh"
    linux_maint_check_exec "seed-known-hosts helper" "$LIBEXEC/seed_known_hosts.sh"
    linux_maint_check_exec "verify-release helper" "$LIBEXEC/verify_release.sh"
    linux_maint_check_exec "upgrade helper" "$LIBEXEC/upgrade_release.sh"
  fi

  echo "== Config =="
  local CFG_DIR VERIFY_LOCKDIR VERIFY_STATE_DIR VERIFY_LOG_DIR
  CFG_DIR="$(linux_maint_effective_cfg_dir)"
  VERIFY_LOCKDIR="$(linux_maint_effective_lock_dir)"
  VERIFY_STATE_DIR="$(linux_maint_effective_state_dir /tmp /var/lib/linux_maint)"
  VERIFY_LOG_DIR="$(linux_maint_effective_log_dir)"
  echo "cfg_dir=$CFG_DIR"
  if [[ -d "$CFG_DIR" ]]; then
    linux_maint_check_file "servers" "$CFG_DIR/servers.txt"
    linux_maint_check_file "excluded" "$CFG_DIR/excluded.txt"
    linux_maint_check_file "services" "$CFG_DIR/services.txt"
  else
    linux_maint_echo_warn "config dir missing: $CFG_DIR"
    linux_maint_add_next_step "run linux-maint init to create starter config files"
  fi

  echo "== Writable locations =="
  linux_maint_check_writable_dir "lockdir" "$VERIFY_LOCKDIR"
  linux_maint_check_writable_dir "state" "$VERIFY_STATE_DIR"
  linux_maint_check_writable_dir "logs" "$VERIFY_LOG_DIR"

  echo "== Version =="
  "$0" version --short || true
  echo "build_info_file=$SHARE/BUILD_INFO"

  echo "== systemd (best-effort) =="
  if command -v systemctl >/dev/null 2>&1; then
    local unit_dirs svc="" tmr=""
    unit_dirs="${LM_SYSTEMD_UNIT_DIRS:-/etc/systemd/system:/usr/lib/systemd/system:/lib/systemd/system}"
    while IFS=':' read -r -a unit_dir_list; do
      local unit_dir
      for unit_dir in "${unit_dir_list[@]}"; do
        if [[ -z "$svc" && -f "$unit_dir/linux-maint.service" ]]; then
          svc="$unit_dir/linux-maint.service"
        fi
        if [[ -z "$tmr" && -f "$unit_dir/linux-maint.timer" ]]; then
          tmr="$unit_dir/linux-maint.timer"
        fi
      done
    done <<< "$unit_dirs"
    if [[ -n "$svc" || -n "$tmr" ]]; then
      if [[ -n "$svc" ]]; then
        linux_maint_echo_ok "unit file: $svc"
      else
        linux_maint_echo_warn "missing unit file: linux-maint.service"
      fi
      if [[ -n "$tmr" ]]; then
        linux_maint_echo_ok "unit file: $tmr"
      else
        linux_maint_echo_warn "missing unit file: linux-maint.timer"
      fi
      if systemctl is-enabled linux-maint.timer >/dev/null 2>&1; then
        linux_maint_echo_ok "timer enabled"
      else
        echo "INFO: timer not enabled (or systemd unavailable)"
      fi
      if systemctl is-active linux-maint.timer >/dev/null 2>&1; then
        linux_maint_echo_ok "timer active"
      else
        echo "INFO: timer not active (or systemd unavailable)"
      fi
    else
      echo "INFO: systemd unit files not present (ok if not installed with --with-timer)"
    fi
  else
    echo "INFO: systemctl not found"
  fi

  if [[ "$warn_count" -gt 0 ]]; then
    echo "== Guidance =="
    echo "warnings=$warn_count"
    if [[ "${#next_steps[@]}" -gt 0 ]]; then
      printf 'next_step: %s\n' "${next_steps[@]}"
    fi
  fi

  echo "== Summary =="
  echo "checks_ok=$ok_count"
  echo "warnings=$warn_count"
  echo "failures=$fail_count"

  if [[ "$fail" -ne 0 ]]; then
    echo "verify-install FAIL" >&2
    exit 1
  fi
  echo "${C_GREEN}verify-install ok${C_RESET}"
}
