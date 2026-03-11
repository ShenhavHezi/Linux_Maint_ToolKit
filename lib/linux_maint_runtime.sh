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
  REPO_LOG_DIR="${LOG_DIR:-$REPO_ROOT/.logs}"
  REPO_STATUS_FILE="$REPO_LOG_DIR/last_status_full"
  REPO_LATEST_LOG="$REPO_LOG_DIR/full_health_monitor_latest.log"
  REPO_SUMMARY_LATEST="$REPO_LOG_DIR/full_health_monitor_summary_latest.log"
  INST_SUMMARY_LATEST="/var/log/health/full_health_monitor_summary_latest.log"
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
        hint_line "sudo linux-maint gate --policy /etc/linux_maint/policy.json" >&2
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
