#!/usr/bin/env bash
# Run command parsing and preflight helpers for linux-maint.

parse_run_args(){
  DRY_RUN=0
  DEBUG=0
  LIMIT=0
  SHUFFLE=0
  RUN_ONLY=""
  RUN_SKIP=""
  PLAN_ONLY=0
  RUN_JSON=0
  RUN_RESUME=""
  RUN_RESPECT_MAINT=0
  RUN_DRAIN_FILE=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --group)
        LM_GROUP="$2"; export LM_GROUP; shift 2;;
      --hosts)
        tmpf="$(make_list_tmpfile "$2" hosts)"; LM_SERVERLIST="$tmpf"; export LM_SERVERLIST; shift 2;;
      --exclude)
        tmpf="$(make_list_tmpfile "$2" excluded)"; LM_EXCLUDED="$tmpf"; export LM_EXCLUDED; shift 2;;
      --parallel)
        LM_MAX_PARALLEL="$2"; export LM_MAX_PARALLEL; shift 2;;
      --local-only)
        LM_LOCAL_ONLY="true"; export LM_LOCAL_ONLY; shift 1;;
      --ssh-opts)
        LM_SSH_OPTS="$2"; export LM_SSH_OPTS; shift 2;;
      --retry)
        LM_SSH_RETRY="$2"; export LM_SSH_RETRY; shift 2;;
      --host-timeout)
        LM_SSH_TIMEOUT="$2"; export LM_SSH_TIMEOUT; shift 2;;
      --strategy)
        LM_EXEC_STRATEGY="$2"; export LM_EXEC_STRATEGY; shift 2;;
      --quorum-percent)
        LM_EXEC_QUORUM_PERCENT="$2"; export LM_EXEC_QUORUM_PERCENT; shift 2;;
      --respect-maintenance)
        RUN_RESPECT_MAINT=1; shift 1;;
      --drain-file)
        RUN_DRAIN_FILE="$2"; shift 2;;
      --only)
        RUN_ONLY="$2"; shift 2;;
      --skip)
        RUN_SKIP="$2"; shift 2;;
      --plan)
        PLAN_ONLY=1; shift 1;;
      --json)
        RUN_JSON=1; shift 1;;
      --limit)
        LIMIT="$2"; shift 2;;
      --shuffle)
        SHUFFLE=1; shift 1;;
      --progress)
        LM_PROGRESS=1; export LM_PROGRESS; shift 1;;
      --no-progress)
        LM_PROGRESS=0; export LM_PROGRESS; shift 1;;
      --allow-concurrent)
        LM_ALLOW_CONCURRENT=1; export LM_ALLOW_CONCURRENT; shift 1;;
      --lock-timeout)
        LM_RUN_LOCK_TIMEOUT="$2"; export LM_RUN_LOCK_TIMEOUT; shift 2;;
      --debug|--print-env)
        DEBUG=1; shift 1;;
      --dry-run)
        DRY_RUN=1; PLAN_ONLY=1; shift 1;;
      --strict)
        LM_STRICT=1; export LM_STRICT; shift 1;;
      --resume)
        RUN_RESUME="$2"; shift 2;;
      -h|--help)
        command_usage run
        exit 0;;
      *)
        echo "Unknown run flag: $1" >&2
        exit 2;;
    esac
  done
}

resolve_resume_run_id(){
  local target="${1:-}"
  [[ -n "$target" ]] || return 1
  if [[ "$target" != "latest" ]]; then
    printf '%s' "$target"
    return 0
  fi

  local state_dir index_file
  if [[ "$MODE" == "repo" ]]; then
    state_dir="${LM_STATE_DIR:-$REPO_LOG_DIR}"
  else
    state_dir="${LM_STATE_DIR:-/var/lib/linux_maint}"
  fi
  index_file="${LM_RUN_INDEX_FILE:-$state_dir/run_index.jsonl}"
  if [[ ! -f "$index_file" && -z "${LM_RUN_INDEX_FILE:-}" && -z "${LM_STATE_DIR:-}" ]]; then
    for alt in /var/tmp/run_index.jsonl /var/tmp/linux_maint/run_index.jsonl /tmp/linux_maint/run_index.jsonl; do
      if [[ -f "$alt" ]]; then
        index_file="$alt"
        break
      fi
    done
  fi
  [[ -f "$index_file" ]] || return 1
  python3 - "$index_file" <<'PY'
import json, sys
path = sys.argv[1]
run_id = ""
invalid_lines = 0
with open(path, "r", encoding="utf-8", errors="ignore") as f:
    for raw in f:
        raw = raw.strip()
        if not raw:
            continue
        try:
            obj = json.loads(raw)
        except Exception:
            invalid_lines += 1
            continue
        rid = obj.get("run_id")
        if isinstance(rid, str) and rid:
            run_id = rid
if invalid_lines:
    print(
        f"ERROR: run --resume latest requires valid JSON lines in run index: {path} "
        f"(invalid_lines={invalid_lines})",
        file=sys.stderr,
    )
    raise SystemExit(2)
print(run_id)
PY
}

validate_resume_state_file(){
  local run_id="${1:-}"
  local state_dir resume_state_file resume_state_err resume_reason
  [[ -n "$run_id" ]] || return 1
  if [[ "$MODE" == "repo" ]]; then
    state_dir="${LM_STATE_DIR:-$REPO_LOG_DIR}"
  else
    state_dir="${LM_STATE_DIR:-/var/lib/linux_maint}"
  fi
  resume_state_file="${state_dir}/run_state_${run_id}.log"
  if [[ ! -f "$resume_state_file" ]]; then
    echo "ERROR: run --resume requires resume state file: $resume_state_file" >&2
    return 2
  fi
  resume_state_err="$(mktemp -p "${TMPDIR:-/tmp}" linux_maint_resume_state.XXXXXX 2>/dev/null || true)"
  if [[ -z "$resume_state_err" ]]; then
    echo "ERROR: run --resume could not allocate validation temp file" >&2
    return 2
  fi
  if python3 - "$resume_state_file" "$run_id" >/dev/null 2>"$resume_state_err" <<'PY'
import sys

path, expected = sys.argv[1:3]
run_id = None

try:
    fh = open(path, "r", encoding="utf-8", errors="ignore")
except OSError as exc:
    print(f"cannot read resume state: {exc}", file=sys.stderr)
    raise SystemExit(2)

with fh:
    for lineno, raw in enumerate(fh, 1):
        line = raw.strip()
        if not line:
            continue
        if line.startswith("run_id="):
            candidate = line.split("=", 1)[1].strip()
            if not candidate:
                print("empty run_id header", file=sys.stderr)
                raise SystemExit(2)
            if run_id is None:
                run_id = candidate
            elif run_id != candidate:
                print("conflicting run_id headers", file=sys.stderr)
                raise SystemExit(2)
            continue
        if not line.startswith("monitor="):
            continue
        monitor = status = rc = None
        for field in line.split():
            if field.startswith("monitor="):
                monitor = field.split("=", 1)[1]
            elif field.startswith("status="):
                status = field.split("=", 1)[1]
            elif field.startswith("rc="):
                rc = field.split("=", 1)[1]
        if not monitor or status is None or rc is None:
            print(f"invalid monitor line at line {lineno}", file=sys.stderr)
            raise SystemExit(2)

if run_id != expected:
    if run_id is None:
        print("missing run_id header", file=sys.stderr)
    else:
        print(f"run_id header mismatch ({run_id})", file=sys.stderr)
    raise SystemExit(2)
PY
  then
    rm -f "$resume_state_err" 2>/dev/null || true
    return 0
  fi
  resume_reason="$(head -n 1 "$resume_state_err" 2>/dev/null || true)"
  rm -f "$resume_state_err" 2>/dev/null || true
  [[ -n "$resume_reason" ]] || resume_reason="invalid resume state"
  echo "ERROR: run --resume requires valid resume state file: $resume_state_file ($resume_reason)" >&2
  return 2
}

within_maintenance_window(){
  local cfg_dir="$1"
  local mw_file="${LM_MAINTENANCE_FILE:-$cfg_dir/maintenance_windows.conf}"
  [[ -f "$mw_file" ]] || return 0
  python3 - "$mw_file" <<'PY'
import datetime, sys
path = sys.argv[1]
cfg = {}
with open(path, "r", encoding="utf-8", errors="ignore") as f:
    for raw in f:
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        cfg[k.strip().lower()] = v.strip()
enabled = cfg.get("enabled", "0").lower()
if enabled not in ("1", "true", "yes", "on"):
    raise SystemExit(0)
window = cfg.get("window", "")
if not window or "-" not in window:
    raise SystemExit(0)
start_s, end_s = [p.strip() for p in window.split("-", 1)]
def parse_hhmm(s):
    h, m = s.split(":", 1)
    return int(h), int(m)
try:
    sh, sm = parse_hhmm(start_s)
    eh, em = parse_hhmm(end_s)
except Exception:
    raise SystemExit(0)
now = datetime.datetime.now()
cur = now.hour * 60 + now.minute
start = sh * 60 + sm
end = eh * 60 + em
days = cfg.get("days", "").strip()
if days:
    valid = set()
    for d in days.split(","):
        d = d.strip().lower()
        if d:
            valid.add(d[:3])
    if valid and now.strftime("%a").lower()[:3] not in valid:
        raise SystemExit(2)
inside = (start <= cur <= end) if start <= end else (cur >= start or cur <= end)
raise SystemExit(0 if inside else 2)
PY
}

resolve_run_monitors_text(){
  local local_monitors=""
  if [[ -n "${LM_MONITORS:-}" ]]; then
    read -r -a _lm_list <<< "${LM_MONITORS}"
    local_monitors="$(printf '%s\n' "${_lm_list[@]}")"
  else
    local_monitors="$(get_default_monitors 2>/dev/null || true)"
    if [[ -z "$local_monitors" ]]; then
      local_monitors="$(available_monitors 2>/dev/null || true)"
    fi
  fi
  printf '%s\n' "$local_monitors" | sed '/^$/d'
}

enforce_monitor_privilege_policy(){
  local monitors_text="$1"
  local cfg_dir="$2"
  local policy_file="${LM_MONITOR_PRIV_POLICY_FILE:-$cfg_dir/monitor_privilege_policy.conf}"
  [[ -f "$policy_file" ]] || return 0
  MONITORS_TEXT="$monitors_text" POLICY_FILE="$policy_file" python3 - <<'PY'
import json, os, re, sys

policy_file = os.environ.get("POLICY_FILE", "")
monitors = [m.strip() for m in os.environ.get("MONITORS_TEXT", "").splitlines() if m.strip()]

policy = {}
errors = []
allowed = {"requires_root", "allow_sudo", "no_sudo"}
try:
    with open(policy_file, "r", encoding="utf-8", errors="ignore") as f:
        for ln, raw in enumerate(f, start=1):
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            if "=" not in line:
                errors.append(f"{policy_file}:{ln}: missing '='")
                continue
            k, v = line.split("=", 1)
            key = k.strip()
            key = key[:-3] if key.endswith(".sh") else key
            mode = v.strip()
            if mode not in allowed:
                errors.append(f"{policy_file}:{ln}: invalid mode '{mode}' for monitor '{key}'")
                continue
            policy[key] = mode
except FileNotFoundError:
    raise SystemExit(0)

if errors:
    for e in errors:
        print(f"ERROR: {e}", file=sys.stderr)
    raise SystemExit(2)

is_root = (os.geteuid() == 0)
violations = []
for m in monitors:
    key = m[:-3] if m.endswith(".sh") else m
    mode = policy.get(key)
    if not mode:
        continue
    if mode == "requires_root" and not is_root:
        violations.append(f"{key}: requires_root but current user is non-root")
    elif mode == "no_sudo" and is_root:
        violations.append(f"{key}: no_sudo but current user is root")

if violations:
    print(f"ERROR: monitor privilege policy violations ({policy_file}):", file=sys.stderr)
    for v in violations:
        print(f"- {v}", file=sys.stderr)
    raise SystemExit(2)
PY
}

resolve_run_cfg_dir(){
  if [[ "$MODE" == "repo" ]]; then
    printf '%s\n' "${LM_CFG_DIR:-$REPO_ROOT/.etc_linux_maint}"
  else
    printf '%s\n' "/etc/linux_maint"
  fi
}

run_apply_mode_defaults(){
  if [[ "$MODE" == "repo" ]]; then
    local repo_cfg_dir="${LM_CFG_DIR:-$REPO_ROOT/.etc_linux_maint}"
    export LM_CFG_DIR="${LM_CFG_DIR:-$repo_cfg_dir}"
    export LM_SERVERLIST="${LM_SERVERLIST:-$repo_cfg_dir/servers.txt}"
    export LM_EXCLUDED="${LM_EXCLUDED:-$repo_cfg_dir/excluded.txt}"
    export LM_HOSTS_DIR="${LM_HOSTS_DIR:-$repo_cfg_dir/hosts.d}"
  fi
}

run_validate_execution_args(){
  if [[ -n "${LM_SSH_RETRY:-}" ]] && [[ ! "${LM_SSH_RETRY}" =~ ^[0-9]+$ ]]; then
    echo "ERROR: --retry must be a non-negative integer" >&2
    exit 2
  fi
  if [[ -n "${LM_SSH_TIMEOUT:-}" ]] && [[ ! "${LM_SSH_TIMEOUT}" =~ ^[0-9]+$ ]]; then
    echo "ERROR: --host-timeout must be a non-negative integer" >&2
    exit 2
  fi
  case "${LM_EXEC_STRATEGY:-fail-soft}" in
    fail-soft|fail-fast|quorum) ;;
    *)
      echo "ERROR: --strategy must be one of fail-soft|fail-fast|quorum" >&2
      exit 2
      ;;
  esac
  if [[ "${LM_EXEC_STRATEGY:-fail-soft}" == "quorum" ]]; then
    if [[ ! "${LM_EXEC_QUORUM_PERCENT:-80}" =~ ^[0-9]+$ ]] || (( LM_EXEC_QUORUM_PERCENT < 1 || LM_EXEC_QUORUM_PERCENT > 100 )); then
      echo "ERROR: --quorum-percent must be an integer in range 1..100" >&2
      exit 2
    fi
  fi
}

run_prepare_resume_state(){
  local resume_id resume_rc
  if [[ -n "${RUN_RESUME:-}" ]]; then
    set +e
    resume_id="$(resolve_resume_run_id "$RUN_RESUME")"
    resume_rc=$?
    set -e
    if [[ "$resume_rc" -eq 2 ]]; then
      exit 2
    fi
    if [[ -z "${resume_id:-}" ]]; then
      echo "ERROR: unable to resolve --resume target '$RUN_RESUME'" >&2
      echo "Hint: pass an explicit run_id from linux-maint history --json" >&2
      exit 2
    fi
    if ! validate_resume_state_file "$resume_id"; then
      exit 2
    fi
    export LM_RESUME_RUN_ID="$resume_id"
    export LM_RUN_ID="$resume_id"
  fi
  if [[ -n "${RUN_DRAIN_FILE:-}" ]]; then
    export LM_DRAIN_MODE=1
    export LM_DRAIN_FILE="$RUN_DRAIN_FILE"
  fi
}

prepare_run_monitor_selection(){
  local cfg_dir="$1"
  local local_monitors

  if [[ -n "${RUN_ONLY:-}" ]]; then
    validate_monitor_list "$(normalize_monitor_list "$RUN_ONLY")" || exit $?
  fi
  if [[ -n "${RUN_SKIP:-}" ]]; then
    validate_monitor_list "$(normalize_monitor_list "$RUN_SKIP")" || exit $?
  fi

  if [[ -n "${RUN_ONLY:-}" || -n "${RUN_SKIP:-}" ]]; then
    mapfile -t _monitors < <(filter_monitors_only_skip "${RUN_ONLY:-}" "${RUN_SKIP:-}")
    if [[ "${#_monitors[@]}" -eq 0 ]]; then
      echo "ERROR: monitor filter produced empty list" >&2
      exit 2
    fi
    export LM_MONITORS="${_monitors[*]}"
  fi
  if [[ -n "${LM_MONITORS:-}" ]]; then
    read -r -a _lm_list <<< "${LM_MONITORS}"
    validate_monitor_list "$(printf '%s\n' "${_lm_list[@]}")" || exit $?
  fi

  local_monitors="$(resolve_run_monitors_text)"
  if [[ -z "$local_monitors" ]]; then
    echo "ERROR: no monitors resolved for run" >&2
    exit 2
  fi
  enforce_monitor_privilege_policy "$local_monitors" "$cfg_dir"
  RUN_LOCAL_MONITORS="$local_monitors"
  export RUN_LOCAL_MONITORS
}

run_debug_dump(){
  local wrapper="$1"
  [[ "${DEBUG:-0}" -eq 1 ]] || return 0
  echo "=== linux-maint run debug ==="
  echo "MODE=${MODE}"
  echo "wrapper=${wrapper}"
  echo "LM_GROUP=${LM_GROUP:-}"
  echo "LM_HOSTS_DIR=${LM_HOSTS_DIR:-}"
  echo "LM_SERVERLIST=${LM_SERVERLIST:-}"
  echo "LM_EXCLUDED=${LM_EXCLUDED:-}"
  echo "LM_MAX_PARALLEL=${LM_MAX_PARALLEL:-}"
  echo "LM_LOCAL_ONLY=${LM_LOCAL_ONLY:-}"
  echo "LM_MONITORS=${LM_MONITORS:-}"
  echo "LM_SSH_OPTS=${LM_SSH_OPTS:-}"
  echo "LM_SSH_RETRY=${LM_SSH_RETRY:-}"
  echo "LM_SSH_TIMEOUT=${LM_SSH_TIMEOUT:-}"
  echo "LM_EXEC_STRATEGY=${LM_EXEC_STRATEGY:-}"
  echo "LM_EXEC_QUORUM_PERCENT=${LM_EXEC_QUORUM_PERCENT:-}"
  echo "LM_DRAIN_FILE=${LM_DRAIN_FILE:-}"
  echo "LIMIT=${LIMIT:-0}"
  echo "SHUFFLE=${SHUFFLE:-0}"
  echo "PLAN_ONLY=${PLAN_ONLY:-0}"
  echo "DRY_RUN=${DRY_RUN:-0}"
  echo "RUN_JSON=${RUN_JSON:-0}"
  echo "RUN_RESUME=${RUN_RESUME:-}"
  echo "RUN_RESPECT_MAINT=${RUN_RESPECT_MAINT:-0}"
  echo "LM_RESUME_RUN_ID=${LM_RESUME_RUN_ID:-}"
  echo "============================="
}

emit_run_plan(){
  local local_monitors="$1"
  local gf first h m

  if [[ -n "${LM_GROUP:-}" ]]; then
    gf="${LM_HOSTS_DIR:-/etc/linux_maint/hosts.d}/${LM_GROUP}.txt"
    [[ -f "$gf" ]] || echo "NOTE: LM_GROUP=$LM_GROUP but group file not found: $gf (will fall back)" >&2
  fi

  mapfile -t _hosts < <(resolve_run_hosts)

  if [[ "${RUN_JSON:-0}" -eq 1 ]]; then
    printf '{'
    printf '"mode":"%s",' "$MODE"
    if [[ "${LM_LOCAL_ONLY:-false}" == "true" ]]; then
      printf '"local_only":true,'
    else
      printf '"local_only":false,'
    fi
    printf '"parallel":%s,' "${LM_MAX_PARALLEL:-0}"
    printf '"retry":%s,' "${LM_SSH_RETRY:-0}"
    printf '"host_timeout":%s,' "${LM_SSH_TIMEOUT:-0}"
    printf '"strategy":"%s",' "$(json_escape "${LM_EXEC_STRATEGY:-fail-soft}")"
    printf '"quorum_percent":%s,' "${LM_EXEC_QUORUM_PERCENT:-80}"
    if [[ -n "${LM_GROUP:-}" ]]; then
      printf '"group":"%s",' "$(json_escape "$LM_GROUP")"
    else
      printf '"group":null,'
    fi
    printf '"limit":%s,' "${LIMIT:-0}"
    printf '"shuffle":%s,' "$([[ "${SHUFFLE:-0}" -eq 1 ]] && echo true || echo false)"
    printf '"hosts":['
    first=1
    for h in "${_hosts[@]}"; do
      [[ "$first" -eq 0 ]] && printf ','
      first=0
      printf '"%s"' "$(json_escape "$h")"
    done
    printf '],"monitors":['
    first=1
    while IFS= read -r m; do
      [[ -z "$m" ]] && continue
      [[ "$first" -eq 0 ]] && printf ','
      first=0
      printf '"%s"' "$(json_escape "$m")"
    done <<< "$local_monitors"
    printf ']}\n'
    exit 0
  fi

  if [[ -t 1 ]]; then
    section "run plan"
    echo "mode=${MODE} local_only=${LM_LOCAL_ONLY:-false} parallel=${LM_MAX_PARALLEL:-0}"
    [[ -n "${LM_GROUP:-}" ]] && echo "group=${LM_GROUP}"
    echo ""
  fi
  echo "Resolved hosts (${#_hosts[@]}):"
  printf '%s\n' "${_hosts[@]}"
  if [[ -t 1 ]]; then
    echo ""
    echo "Monitors ($(printf '%s\n' "$local_monitors" | sed '/^$/d' | wc -l | tr -d ' ')):"
  fi
  if [[ -n "$local_monitors" ]]; then
    printf '%s\n' "$local_monitors"
  fi
  exit 0
}

run_enforce_maintenance_window(){
  local cfg_dir="$1"
  if [[ "${RUN_RESPECT_MAINT:-0}" -eq 1 ]]; then
    if ! within_maintenance_window "$cfg_dir"; then
      echo "Run skipped: outside configured maintenance window ($cfg_dir/maintenance_windows.conf)"
      exit 0
    fi
  fi
}

run_execute_wrapper(){
  local wrapper="$1"
  local rc

  audit_log_append "run" "start" "wrapper=$wrapper local_only=${LM_LOCAL_ONLY:-false} group=${LM_GROUP:-} strategy=${LM_EXEC_STRATEGY:-fail-soft}"
  set +e
  if [[ "$wrapper" == "$SBIN"/* ]]; then
    "$wrapper"
  else
    bash "$wrapper"
  fi
  rc=$?
  set -e
  audit_log_append "run" "$([[ "$rc" -eq 0 ]] && echo success || echo failure)" "rc=$rc wrapper=$wrapper"
  if [[ -t 1 ]]; then
    echo ""
    echo "Run complete (exit_code=$rc)"
    echo "Summary: $(linux_maint_reporting_summary_latest)"
    echo "Log: $(linux_maint_reporting_latest_log)"
    echo "Next: linux-maint report"
    echo "Tip: linux-maint status --reasons 5"
    echo "If WARN/CRIT: linux-maint doctor"
  fi
  RUN_EXEC_RC="$rc"
}
