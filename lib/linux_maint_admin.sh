#!/usr/bin/env bash
# Install/release/admin command helpers for linux-maint.

linux_maint_cmd_version() {
  if [[ -f "$SHARE/BUILD_INFO" ]]; then
    cat "$SHARE/BUILD_INFO"
  else
    echo "BUILD_INFO not found at $SHARE/BUILD_INFO"
    exit 1
  fi
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
  if [[ "$MODE" != "repo" ]]; then
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
  echo "lib=${LINUX_MAINT_LIB:-/usr/local/lib/linux_maint.sh}"

  local fail=0

  linux_maint_check_file() {
    local label="$1" path="$2"
    if [[ -e "$path" ]]; then
      echo "${C_GREEN}OK${C_RESET}: $label: $path"
    else
      echo "${C_RED}MISSING${C_RESET}: $label: $path" >&2
      fail=1
    fi
  }

  linux_maint_check_exec() {
    local label="$1" path="$2"
    if [[ -x "$path" ]]; then
      echo "${C_GREEN}OK${C_RESET}: $label: $path"
    elif [[ -e "$path" ]]; then
      echo "${C_RED}NOT EXECUTABLE${C_RESET}: $label: $path" >&2
      fail=1
    else
      echo "${C_RED}MISSING${C_RESET}: $label: $path" >&2
      fail=1
    fi
  }

  linux_maint_check_writable_dir() {
    local label="$1" path="$2"
    if [[ -d "$path" ]]; then
      if [[ -w "$path" ]]; then
        echo "${C_GREEN}OK${C_RESET}: writable $label: $path"
      else
        echo "${C_YELLOW}WARN${C_RESET}: not writable $label: $path" >&2
      fi
    else
      echo "${C_YELLOW}WARN${C_RESET}: missing dir $label: $path" >&2
    fi
  }

  if [[ "$MODE" == "installed" ]]; then
    linux_maint_check_exec "binary" "$PREFIX/bin/linux-maint"
  fi
  linux_maint_check_exec "wrapper" "$wrapper"
  linux_maint_check_file "library" "${LINUX_MAINT_LIB:-/usr/local/lib/linux_maint.sh}"
  if [[ "$MODE" == "installed" ]]; then
    linux_maint_check_file "library config helper" "$PREFIX/lib/linux_maint_conf.sh"
    linux_maint_check_file "runtime support lib" "$PREFIX/lib/linux_maint_runtime.sh"
    linux_maint_check_file "admin support lib" "$PREFIX/lib/linux_maint_admin.sh"
    linux_maint_check_file "help support lib" "$PREFIX/lib/linux_maint_help.sh"
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
  if [[ "$MODE" == "repo" ]]; then
    CFG_DIR="${LM_CFG_DIR:-$REPO_ROOT/.etc_linux_maint}"
    VERIFY_LOCKDIR="${LM_LOCKDIR:-/tmp}"
    VERIFY_STATE_DIR="${LM_STATE_DIR:-/tmp}"
    VERIFY_LOG_DIR="${LOG_DIR:-$REPO_LOG_DIR}"
  else
    CFG_DIR="${LM_CFG_DIR:-/etc/linux_maint}"
    VERIFY_LOCKDIR="${LM_LOCKDIR:-/var/lock}"
    VERIFY_STATE_DIR="${LM_STATE_DIR:-/var/lib/linux_maint}"
    VERIFY_LOG_DIR="${LOG_DIR:-/var/log/health}"
  fi
  echo "cfg_dir=$CFG_DIR"
  if [[ -d "$CFG_DIR" ]]; then
    linux_maint_check_file "servers" "$CFG_DIR/servers.txt"
    linux_maint_check_file "excluded" "$CFG_DIR/excluded.txt"
    linux_maint_check_file "services" "$CFG_DIR/services.txt"
  else
    echo "WARN: config dir missing: $CFG_DIR" >&2
  fi

  echo "== Writable locations =="
  linux_maint_check_writable_dir "lockdir" "$VERIFY_LOCKDIR"
  linux_maint_check_writable_dir "state" "$VERIFY_STATE_DIR"
  linux_maint_check_writable_dir "logs" "$VERIFY_LOG_DIR"

  echo "== Version =="
  "$0" version || true

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
      [[ -n "$svc" ]] && echo "OK: unit file: $svc" || echo "WARN: missing unit file: linux-maint.service" >&2
      [[ -n "$tmr" ]] && echo "OK: unit file: $tmr" || echo "WARN: missing unit file: linux-maint.timer" >&2
      systemctl is-enabled linux-maint.timer >/dev/null 2>&1 && echo "OK: timer enabled" || echo "INFO: timer not enabled (or systemd unavailable)"
      systemctl is-active linux-maint.timer >/dev/null 2>&1 && echo "OK: timer active" || echo "INFO: timer not active (or systemd unavailable)"
    else
      echo "INFO: systemd unit files not present (ok if not installed with --with-timer)"
    fi
  else
    echo "INFO: systemctl not found"
  fi

  if [[ "$fail" -ne 0 ]]; then
    echo "verify-install FAIL" >&2
    exit 1
  fi
  echo "${C_GREEN}verify-install ok${C_RESET}"
}
