#!/usr/bin/env bash
# linux_maint.sh - Shared helpers for Linux_Maint_Scripts
# Author: Shenhav_Hezi
# Version: 1.0
# Usage:
#   . /usr/local/lib/linux_maint.sh   # source at the top of your script
# Quick integration recipe:
# Install the lib (Require only once)
# sudo mkdir -p /usr/local/lib
# sudo cp lib/linux_maint.sh /usr/local/lib/linux_maint.sh
# sudo chmod 0644 /usr/local/lib/linux_maint.sh

# ========= Strict mode (safe defaults) =========
set -o pipefail

# ========= Defaults (overridable via env from the caller script) =========
: "${LM_LOGFILE:=/var/log/linux_maint.log}"
: "${LM_EMAILS:=/etc/linux_maint/emails.txt}"
: "${LM_EXCLUDED:=/etc/linux_maint/excluded.txt}"
: "${LM_SERVERLIST:=/etc/linux_maint/servers.txt}"
: "${LM_HOSTS_DIR:=/etc/linux_maint/hosts.d}"   # optional host groups directory
: "${LM_GROUP:=}"                          # optional group name (maps to $LM_HOSTS_DIR/<group>.txt)
: "${LM_LOCKDIR:=/var/lock}"
if [[ -z "${LM_STATE_DIR:-}" ]]; then
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    LM_STATE_DIR="/var/lib/linux_maint"
  else
    LM_STATE_DIR="/var/tmp/linux_maint"
  fi
fi

: "${LM_SSH_OPTS:=-o BatchMode=yes -o ConnectTimeout=7 -o ServerAliveInterval=10 -o ServerAliveCountMax=2 -o ForwardAgent=no -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/var/lib/linux_maint/known_hosts -o GlobalKnownHostsFile=/dev/null}"

: "${LM_EMAIL_ENABLED:=true}"      # scripts can set LM_EMAIL_ENABLED=false to suppress email
: "${LM_MAX_PARALLEL:=0}"          # 0 = sequential
: "${LM_PREFIX:=}"                 # optional log prefix (script can set)

# ========= SSH opts validation =========
# Reject obviously dangerous shell metacharacters in LM_SSH_OPTS.
lm_validate_ssh_opts() {
  local s="${LM_SSH_OPTS:-}"
  [[ -z "$s" ]] && return 0
  if printf '%s' "$s" | grep -Eq '[;&|`<>]|\$\(|\$\{'; then
    echo "ERROR: unsafe characters detected in LM_SSH_OPTS" >&2
    echo "LM_SSH_OPTS=$s" >&2
    return 2
  fi
  case "$s" in
    *$'\n'*|*$'\r'*)
      echo "ERROR: unsafe characters detected in LM_SSH_OPTS" >&2
      echo "LM_SSH_OPTS=$s" >&2
      return 2
      ;;
  esac
  return 0
}

# ========= Pretty timestamps =========
lm_ts() { date '+%Y-%m-%d %H:%M:%S'; }

# ========= Logging =========
# lm_log LEVEL MSG...
lm_log() {
  local lvl="$1"; shift
  local line
  if [[ "${LM_LOG_FORMAT:-text}" == "json" ]]; then
    local msg ts esc_msg esc_prefix
    ts="$(lm_ts)"
    msg="$(lm_redact_line "$*")"
    esc_msg="$(lm_json_escape "$msg")"
    esc_prefix="$(lm_json_escape "${LM_PREFIX}")"
    line="{\"ts\":\"${ts}\",\"level\":\"${lvl}\",\"prefix\":\"${esc_prefix}\",\"msg\":\"${esc_msg}\"}"
  else
    line="$(lm_ts) - ${LM_PREFIX}${lvl} - $(lm_redact_line "$*")"
  fi
  # print to stdout and append to LM_LOGFILE (create parent dir if needed)
  mkdir -p "$(dirname "$LM_LOGFILE")" 2>/dev/null || true
  echo "$line" | tee -a "$LM_LOGFILE" >/dev/null
}
lm_info(){ lm_log INFO "$@"; }
lm_warn(){ lm_log WARN "$@"; }
lm_err(){  lm_log ERROR "$@"; }
lm_die(){  lm_err "$@"; exit 1; }

# ========= Progress (TTY stderr, best-effort) =========
lm_progress_enabled() {
  [[ -t 2 ]] || return 1
  case "${LM_PROGRESS:-1}" in
    0|false|no|off) return 1 ;;
  esac
  return 0
}

lm_progress_begin() {
  _LM_P_ENABLED=0
  if lm_progress_enabled; then
    _LM_P_ENABLED=1
  fi
  _LM_P_TOTAL="${1:-0}"
  _LM_P_IDX=0
  _LM_P_WIDTH="${LM_PROGRESS_WIDTH:-24}"
}

lm_progress_render() {
  [[ "${_LM_P_ENABLED:-0}" -eq 1 ]] || return 0
  local idx="$1" total="$2" label="${3:-}"
  [[ "$total" -gt 0 ]] || return 0
  local filled=$(( idx * _LM_P_WIDTH / total ))
  local rest=$(( _LM_P_WIDTH - filled ))
  local bar
  bar="$(printf '%*s' "$filled" '' | tr ' ' '#')"
  bar="${bar}$(printf '%*s' "$rest" '' | tr ' ' '-')"
  printf '\r[%s] %d/%d %s' "$bar" "$idx" "$total" "$label" >&2
}

lm_progress_step() {
  [[ "${_LM_P_ENABLED:-0}" -eq 1 ]] || return 0
  _LM_P_IDX=$((_LM_P_IDX+1))
  lm_progress_render "$_LM_P_IDX" "$_LM_P_TOTAL" "${1:-}"
}

lm_progress_done() {
  [[ "${_LM_P_ENABLED:-0}" -eq 1 ]] || return 0
  printf '\n' >&2
}

lm_json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

# ========= Writable dir selection (fallback chain) =========
# lm_pick_writable_dir <label> <primary> [fallback1 ...]
# - Ensures the chosen directory exists and is writable.
# - Returns chosen dir on stdout; non-zero if none are writable.
lm_dir_writable() {
  local d="$1"
  [ -n "$d" ] || return 1
  mkdir -p "$d" 2>/dev/null || return 1
  local probe="$d/.linux_maint_write_test.$$"
  ( : > "$probe" ) 2>/dev/null || return 1
  rm -f "$probe" 2>/dev/null || true
  return 0
}

lm_pick_writable_dir() {
  local label="$1"; shift
  local d
  for d in "$@"; do
    [ -n "$d" ] || continue
    if lm_dir_writable "$d"; then
      printf '%s' "$d"
      return 0
    fi
  done
  return 1
}

# ========= Temp helpers =========
# lm_pick_tmpdir: choose a writable temp directory with a safe fallback chain.
lm_pick_tmpdir() {
  local req="${LM_STATE_DIR:-${TMPDIR:-/var/tmp}}"
  if command -v lm_pick_writable_dir >/dev/null 2>&1; then
    lm_pick_writable_dir "tmp" "$req" "${TMPDIR:-}" "/var/tmp" "/tmp"
  else
    printf '%s' "${TMPDIR:-/tmp}"
  fi
}

# lm_mktemp [template]
# Uses lm_pick_tmpdir to create a temp file in a writable directory.
lm_mktemp() {
  local tmpl="${1:-linux_maint.XXXXXX}"
  local dir
  dir="$(lm_pick_tmpdir 2>/dev/null)" || dir="${TMPDIR:-/tmp}"
  mktemp -p "$dir" "$tmpl"
}

# ========= Timing helper =========
# lm_time <monitor> <step> <command...>
# Emits: RUNTIME_STEP monitor=<name> step=<label> ms=<duration> rc=<rc>
lm_now_ms() {
  local ms
  ms="$(date +%s%3N 2>/dev/null || true)"
  if [[ "$ms" =~ ^[0-9]+$ ]]; then
    printf '%s' "$ms"
    return 0
  fi
  python3 - <<'PY'
import time
print(int(time.time()*1000))
PY
}

lm_time() {
  local monitor="$1" step="$2"; shift 2
  local start end rc
  start="$(lm_now_ms)"
  "$@"
  rc=$?
  end="$(lm_now_ms)"
  if [[ "$start" =~ ^[0-9]+$ && "$end" =~ ^[0-9]+$ ]]; then
    echo "RUNTIME_STEP monitor=$monitor step=$step ms=$((end-start)) rc=$rc"
  fi
  return "$rc"
}

# ========= Optional log redaction =========
# If LM_REDACT_LOGS=1|true, redact common secret patterns from log lines.
# This is best-effort and intentionally conservative.
# Default: off (no behavior change).
lm_redact_line() {
  local s="$1"

  case "${LM_REDACT_LOGS:-0}" in
    1|true|TRUE|yes|YES)
      ;;
    *)
      printf '%s' "$s"
      return 0
      ;;
  esac

  # Best-effort secret redaction in free-form logs
  # - key=value forms (password/token/session/auth variants)
  # - auth headers / bearer credentials
  # - JWT-like blobs (three base64url-ish dot-separated segments)
  s="$(printf '%s' "$s" | sed -E \
    -e 's/\b([[:alnum:]_]*(password|passwd|token|api[_-]?key|secret|access[_-]?key|private[_-]?key|session([_-]?id)?|id[_-]?token|refresh[_-]?token|x[_-]?auth[_-]?token)[[:alnum:]_]*)=([^[:space:]]+)/\1=REDACTED/Ig' \
    -e 's/\b(Authorization:|X-Auth-Token:)[[:space:]]+[^[:space:]]+/\1 REDACTED/Ig' \
    -e 's/\b(Bearer)[[:space:]]+[[:alnum:]_.~+\/-]+=*/\1 REDACTED/Ig' \
    -e 's/\b[[:alnum:]_-]{12,}\.[[:alnum:]_-]{12,}\.[[:alnum:]_-]{12,}\b/REDACTED_JWT/g' \
  )"

  printf '%s' "$s"
}

# Redact key=value tokens without introducing spaces (safe for summary lines).
lm_redact_kv_line() {
  local s="$1"
  case "${LM_REDACT_LOGS:-0}" in
    1|true|TRUE|yes|YES) ;;
    *) printf '%s' "$s"; return 0 ;;
  esac
  s="$(printf '%s' "$s" | sed -E \
    -e 's/\b([[:alnum:]_]*(password|passwd|token|api[_-]?key|secret|access[_-]?key|private[_-]?key|session([_-]?id)?|id[_-]?token|refresh[_-]?token|x[_-]?auth[_-]?token)[[:alnum:]_]*)=([^[:space:]]+)/\1=REDACTED/Ig' \
    -e 's/\b[[:alnum:]_-]{12,}\.[[:alnum:]_-]{12,}\.[[:alnum:]_-]{12,}\b/REDACTED_JWT/g' \
  )"
  printf '%s' "$s"
}


# ========= Locking (prevent overlapping runs) =========
# Usage: lm_require_singleton myscript      → exits if already running
lm_require_singleton() {
  local name="$1"
  mkdir -p "$LM_LOCKDIR" 2>/dev/null || true
  exec {__lm_lock_fd}>"$LM_LOCKDIR/${name}.lock" || lm_die "Cannot open lock file"
  if ! flock -n "$__lm_lock_fd"; then
    lm_warn "Another ${name} is already running; exiting."
    exit 0
  fi
}

# ========= Email =========
lm_mail() {
  local subject="$1" body="$2"
  [ "$LM_EMAIL_ENABLED" = "true" ] || return 0
  [ -s "$LM_EMAILS" ] || { lm_warn "Email list $LM_EMAILS missing/empty; skipping email"; return 0; }
  command -v mail >/dev/null || { lm_warn "mail command not found; skipping email"; return 0; }
  while IFS= read -r to; do
    [ -n "$to" ] && printf "%s\n" "$body" | mail -s "$subject" "$to"
  done < "$LM_EMAILS"
}

# ========= Wrapper-level notification (single email summary per run) =========
# Optional; designed to be called by the wrapper script (run_full_health_monitor.sh).
#
# Config precedence:
#   1) environment variables (LM_NOTIFY, LM_NOTIFY_TO, etc)
#   2) /etc/linux_maint/notify.conf (simple KEY=VALUE lines)
#
# Supported keys:
#   LM_NOTIFY=0|1
#   LM_NOTIFY_TO="a@b,c@d"   (comma/space separated)
#   LM_NOTIFY_ONLY_ON_CHANGE=0|1
#   LM_NOTIFY_SUBJECT_PREFIX="[linux_maint]"
#   LM_NOTIFY_STATE_DIR="/var/lib/linux_maint"
#
lm_load_notify_conf() {
  local conf="${LM_NOTIFY_CONF:-/etc/linux_maint/notify.conf}"
  [ -f "$conf" ] || return 0
  # shellcheck disable=SC1090
  set -a
  # shellcheck disable=SC1090
  . "$conf" || true
  set +a
}

lm_notify_should_send() {
  local summary_text="$1"

  local enabled="${LM_NOTIFY:-0}"
  [ "$enabled" = "1" ] || [ "$enabled" = "true" ] || return 1

  local to="${LM_NOTIFY_TO:-}"
  [ -n "$to" ] || { lm_warn "LM_NOTIFY enabled but LM_NOTIFY_TO is empty; skipping notify"; return 1; }

  local only_change="${LM_NOTIFY_ONLY_ON_CHANGE:-0}"
  if [ "$only_change" = "1" ] || [ "$only_change" = "true" ]; then
    local state_dir="${LM_NOTIFY_STATE_DIR:-${LM_STATE_DIR:-/var/lib/linux_maint}}"
    mkdir -p "$state_dir" 2>/dev/null || true
    local state_file="$state_dir/last_summary.sha256"
    local cur
    cur="$(printf "%s" "$summary_text" | sha256sum | awk '{print $1}')"
    if [ -f "$state_file" ]; then
      local prev
      prev="$(cat "$state_file" 2>/dev/null || true)"
      if [ "$cur" = "$prev" ]; then
        return 1
      fi
    fi
    printf "%s\n" "$cur" > "$state_file" 2>/dev/null || true
  fi

  return 0
}

lm_notify_send() {
  local subject="$1" body="$2"

  local to="${LM_NOTIFY_TO:-}"
  local prefix="${LM_NOTIFY_SUBJECT_PREFIX:-[linux_maint]}"

  # Choose a transport; try common options.
  if command -v mail >/dev/null 2>&1; then
    # shellcheck disable=SC2086
    # shellcheck disable=SC2086
    # shellcheck disable=SC2046
    set -- $(echo "$to" | tr "," " ")
    printf "%s\n" "$body" | mail -s "${prefix} ${subject}" "$@"
    return 0
  fi

  if command -v sendmail >/dev/null 2>&1; then
    local from="${LM_NOTIFY_FROM:-linux_maint@$(hostname -f 2>/dev/null || hostname)}"
    {
      echo "From: $from"
      echo "To: $to"
      echo "Subject: ${prefix} ${subject}"
      echo ""
      echo "$body"
    } | sendmail -t
    return 0
  fi

  lm_warn "No supported mail transport found (mail/sendmail); skipping notify"
  return 0
}

# ========= SSH helpers =========
# lm_ssh HOST CMD...
lm_ssh() {
  local host="$1"; shift
  if ! lm_validate_ssh_opts; then
    return 2
  fi
  if [[ -n "${LM_SSH_ALLOWLIST:-}" ]]; then
    local cmdline="$*"
    if ! lm_ssh_allowed_cmd "$cmdline"; then
      lm_warn "SSH command blocked by LM_SSH_ALLOWLIST"
      return 2
    fi
  fi
  if [ "$host" = "localhost" ] || [ "$host" = "127.0.0.1" ]; then
    # Preserve caller PATH for localhost runs so test shims and local tools are respected.
    if [[ "$#" -ge 2 && "$1" == "bash" && "$2" == "-lc" ]]; then
      PATH="$PATH" "$@" 2>/dev/null
    elif [[ "$#" -eq 1 ]]; then
      PATH="$PATH" bash -lc "$1" 2>/dev/null
    else
      PATH="$PATH" "$@" 2>/dev/null
    fi
  else
    # LM_SSH_OPTS may contain multiple ssh arguments. Split intentionally into an array.
    local -a _ssh_opts=()
    # shellcheck disable=SC2206
    _ssh_opts=(${LM_SSH_OPTS:-})
    # shellcheck disable=SC2029
    ssh "${_ssh_opts[@]}" "$host" "$@" 2>/dev/null
  fi
}
# quick reachability probe (0=ok)
lm_reachable() { lm_ssh "$1" "echo ok" | grep -q ok; }

# LM_SSH_ALLOWLIST: comma/space-separated regex patterns.
# Returns 0 if the command line matches any pattern.
lm_ssh_allowed_cmd() {
  local cmdline="$1"
  [[ -z "${LM_SSH_ALLOWLIST:-}" ]] && return 0
  local allow
  local pat
  allow="$(printf '%s' "$LM_SSH_ALLOWLIST" | tr ', ' '\n' | awk 'NF{print $1}')"
  while IFS= read -r pat; do
    [[ -z "$pat" ]] && continue
    if [[ "$cmdline" =~ $pat ]]; then
      return 0
    fi
  done <<< "$allow"
  return 1
}

# ========= Exclusions & host list =========
lm_is_excluded() { [ -f "$LM_EXCLUDED" ] && grep -Fxq "$1" "$LM_EXCLUDED"; }
# yields hosts to stdout (one per line)
lm_hosts() {
  # Host selection precedence:
  #  1) LM_GROUP=<name> and $LM_HOSTS_DIR/<name>.txt exists
  #  2) LM_SERVERLIST (default /etc/linux_maint/servers.txt)
  #  3) fallback: localhost

  local group_file=""
  if [ -n "${LM_GROUP:-}" ]; then
    group_file="${LM_HOSTS_DIR:-/etc/linux_maint/hosts.d}/${LM_GROUP}.txt"
    if [ -f "$group_file" ]; then
      grep -vE '^[[:space:]]*($|#)' "$group_file"
      return 0
    else
      lm_warn "LM_GROUP set to '${LM_GROUP}' but group file not found: $group_file"
    fi
  fi

  if [ -f "$LM_SERVERLIST" ]; then
    grep -vE '^[[:space:]]*($|#)' "$LM_SERVERLIST"
  else
    echo "localhost"
  fi
}



# ========= Timeout wrapper =========
# Usage: lm_timeout 5s bash -lc 'df -h'
lm_timeout() {
  if command -v timeout >/dev/null 2>&1; then
    timeout "$@"
  else
    bash -lc "${*:2}"
  fi
}

# ========= CSV row selector (common pattern) =========
# Prints rows from CSV where column1 matches $2 or "*" and has at least $3 columns.
lm_csv_rows_for_host() {
  local file="$1" host="$2" mincols="${3:-1}"
  [ -s "$file" ] || return 0
  awk -F',' -v H="$host" -v N="$mincols" '
    /^[[:space:]]*#/ {next}
    NF>=N {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $1)
      if($1==H || $1=="*") print $0
    }' "$file"
}

# ========= Platform detection =========
lm_platform() {
  case "$(uname -s 2>/dev/null)" in
    Linux) echo linux;;
    AIX)   echo aix;;
    *)     echo unknown;;
  esac
}

# ========= Small job-pool for per-host parallelism =========
# Usage: lm_for_each_host my_function   (function will be called with $host)
lm_for_each_host() {
  local fn="$1"
  local -a PIDS=()
  local running=0
  local use_progress=0

  if [[ "${LM_HOST_PROGRESS:-0}" -eq 1 ]] && lm_progress_enabled; then
    use_progress=1
  fi

  if [ "$use_progress" -eq 1 ]; then
    local -a HOSTS=()
    local total=0
    mapfile -t HOSTS < <(lm_hosts)
    for HOST in "${HOSTS[@]}"; do
      [ -z "$HOST" ] && continue
      lm_is_excluded "$HOST" && continue
      total=$((total+1))
    done
    lm_progress_begin "$total"

    for HOST in "${HOSTS[@]}"; do
      [ -z "$HOST" ] && continue
      if lm_is_excluded "$HOST"; then
        lm_info "Skipping $HOST (excluded)"
        continue
      fi
      lm_progress_step "$HOST"
      if [ "${LM_MAX_PARALLEL:-0}" -gt 0 ]; then
        "$fn" "$HOST" &
        PIDS+=($!)
        running=$((running+1))
        if [ "$running" -ge "$LM_MAX_PARALLEL" ]; then
          wait -n
          running=$((running-1))
        fi
      else
        "$fn" "$HOST"
      fi
    done
  else
    while read -r HOST; do
      [ -z "$HOST" ] && continue
      lm_is_excluded "$HOST" && { lm_info "Skipping $HOST (excluded)"; continue; }

      if [ "${LM_MAX_PARALLEL:-0}" -gt 0 ]; then
        # background with simple pool
        "$fn" "$HOST" &
        PIDS+=($!)
        running=$((running+1))
        if [ "$running" -ge "$LM_MAX_PARALLEL" ]; then
          wait -n
          running=$((running-1))
        fi
      else
        "$fn" "$HOST"
      fi
    done < <(lm_hosts)
  fi

  # wait remaining
  if [ "${#PIDS[@]}" -gt 0 ]; then
    wait "${PIDS[@]}" 2>/dev/null || true
  fi
  if [ "$use_progress" -eq 1 ]; then
    lm_progress_done
  fi
}


# ========= Small job-pool for per-host parallelism (with worst-rc aggregation) =========
# Usage: lm_for_each_host_rc my_function
# - Calls: my_function <host>
# - Returns: worst exit code across hosts (0/1/2/3)
# Notes:
# - In parallel mode, collects each background job rc via wait on recorded PIDs.
# - In serial mode, updates worst rc inline.
lm_for_each_host_rc() {
  local fn="$1"
  local -a PIDS=()
  local running=0
  local worst=0
  local use_progress=0

  wait_one_oldest(){
    local pid rc
    pid="${PIDS[0]}"
    if [ -n "$pid" ]; then
      wait "$pid" 2>/dev/null
      rc=$?
      [ "$rc" -gt "$worst" ] && worst="$rc"
      # pop front
      PIDS=("${PIDS[@]:1}")
      running=$((running-1))
    fi
  }

  if [[ "${LM_HOST_PROGRESS:-0}" -eq 1 ]] && lm_progress_enabled; then
    use_progress=1
  fi

  if [ "$use_progress" -eq 1 ]; then
    local -a HOSTS=()
    local total=0
    mapfile -t HOSTS < <(lm_hosts)
    for HOST in "${HOSTS[@]}"; do
      [ -z "$HOST" ] && continue
      lm_is_excluded "$HOST" && continue
      total=$((total+1))
    done
    lm_progress_begin "$total"

    for HOST in "${HOSTS[@]}"; do
      [ -z "$HOST" ] && continue
      if lm_is_excluded "$HOST"; then
        lm_info "Skipping $HOST (excluded)"
        continue
      fi
      lm_progress_step "$HOST"
      if [ "${LM_MAX_PARALLEL:-0}" -gt 0 ]; then
        "$fn" "$HOST" &
        PIDS+=($!)
        running=$((running+1))

        # throttle
        while [ "$running" -ge "$LM_MAX_PARALLEL" ]; do
          wait_one_oldest
        done
      else
        "$fn" "$HOST"
        rc=$?
        [ "$rc" -gt "$worst" ] && worst="$rc"
      fi
    done
  else
    while read -r HOST; do
      [ -z "$HOST" ] && continue
      lm_is_excluded "$HOST" && { lm_info "Skipping $HOST (excluded)"; continue; }

      if [ "${LM_MAX_PARALLEL:-0}" -gt 0 ]; then
        "$fn" "$HOST" &
        PIDS+=($!)
        running=$((running+1))

        # throttle
        while [ "$running" -ge "$LM_MAX_PARALLEL" ]; do
          wait_one_oldest
        done
      else
        "$fn" "$HOST"
        rc=$?
        [ "$rc" -gt "$worst" ] && worst="$rc"
      fi
    done < <(lm_hosts)
  fi

  # wait remaining
  while [ "$running" -gt 0 ]; do
    wait_one_oldest
  done
  if [ "$use_progress" -eq 1 ]; then
    lm_progress_done
  fi

  return "$worst"
}

# ========= Standard summary line =========
# Host semantics:
# - host=<target> is the target being checked (usually one of lm_hosts output).
# - Special reserved values:
#     host=localhost  -> explicit local checks
#     host=runner     -> checks that run only on the runner and summarize fleet-wide results
# - Avoid host=all (deprecated); use host=runner instead.
# Usage: lm_summary <monitor_name> <status> [key=value ...]
# Prints a single machine-parseable line.
# Example:
#   lm_summary "patch_monitor" "WARN" total=5 security=2 reboot_required=unknown
# ========= Standard summary line =========
# Usage: lm_summary <monitor_name> <target_host> <status> [key=value ...]
# Prints a single machine-parseable line.
# Example:
#   lm_summary "patch_monitor" "$host" "WARN" total=5 security=2 reboot_required=unknown
lm_summary() {
  local monitor="$1" target_host="$2" status="$3"; shift 3
  local node
  node="$(hostname -f 2>/dev/null || hostname)"
  if [[ "${LM_SUMMARY_STRICT:-0}" == "1" || "${LM_SUMMARY_STRICT:-}" == "true" ]]; then
    if [[ -z "${monitor}" || -z "${target_host}" || -z "${status}" ]]; then
      echo "ERROR: lm_summary missing required fields (monitor/host/status)" >&2
      return 2
    fi
    case "$status" in
      OK|WARN|CRIT|UNKNOWN|SKIP) ;;
      *)
        echo "ERROR: lm_summary invalid status '${status}'" >&2
        return 2
        ;;
    esac
  fi
  # shellcheck disable=SC2086
  local line
  local args=("$@")
  if [[ -n "${LM_SUMMARY_ALLOWLIST:-}" ]]; then
    local allowlist
    allowlist="$(printf '%s' "${LM_SUMMARY_ALLOWLIST}" | tr ', ' '\n' | awk 'NF{print $1}' | paste -sd '|' -)"
    local filtered=()
    local dropped=0
    local tok key
    for tok in "${args[@]}"; do
      if [[ "$tok" == *=* ]]; then
        key="${tok%%=*}"
        if [[ -n "$allowlist" && "$key" =~ ^(${allowlist})$ ]]; then
          filtered+=("$tok")
        else
          dropped=$((dropped+1))
        fi
      else
        dropped=$((dropped+1))
      fi
    done
    if [[ "$dropped" -gt 0 ]]; then
      echo "WARN: lm_summary dropped ${dropped} key(s) not in LM_SUMMARY_ALLOWLIST" >&2
    fi
    args=("${filtered[@]}")
  fi

  line="monitor=${monitor} host=${target_host} status=${status} node=${node} ${args[*]}"
  line="$(printf '%s' "$line" | sed "s/[[:space:]]\\+/ /g; s/[[:space:]]$//")"
  line="$(lm_redact_kv_line "$line")"
  printf '%s\n' "$line"
}

# ========= Dependency helpers =========
# lm_has_cmd <cmd>
lm_has_cmd(){
  local cmd="$1"
  if lm_force_missing_dep "$cmd"; then
    return 1
  fi
  command -v "$cmd" >/dev/null 2>&1
}

# Allow tests to force specific deps to appear missing (comma-separated list)
lm_force_missing_dep(){
  local cmd="$1"
  [[ -z "${LM_FORCE_MISSING_DEPS:-}" ]] && return 1
  echo ",${LM_FORCE_MISSING_DEPS}," | grep -q ",${cmd},"
}


# lm_require_cmd <monitor> <host> <cmd> [--optional]
# If missing required cmd: prints standardized summary line and returns 3.
# If missing optional cmd: prints standardized summary line and returns 0.
lm_require_cmd(){
  local monitor="$1" host="$2" cmd="$3" opt="${4:-}"
  if lm_has_cmd "$cmd"; then
    return 0
  fi

  if [[ "$opt" == "--optional" ]]; then
    lm_summary "$monitor" "$host" "SKIP" reason=missing_optional_cmd dep="$cmd"
    return 0
  fi

  lm_summary "$monitor" "$host" "UNKNOWN" reason=missing_dependency dep="$cmd"
  return 3
}
