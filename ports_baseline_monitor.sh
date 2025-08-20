#!/bin/bash
# ports_baseline_monitor.sh - Detect new/removed listening ports vs a baseline (distributed)
# Author: Shenhav_Hezi
# Version: 1.0
# Description:
#   Captures the current set of LISTEN sockets on one or many Linux servers
#   (tcp/udp, IPv4/IPv6), normalizes them to "proto|port|process", and compares
#   against a per-host baseline file. Reports NEW and REMOVED entries, supports
#   allowlisting, and can optionally initialize or update baselines.
#
#   Primary collector: `ss -H -tulpen` (process names if available)
#   Fallback collector: `ss -H -tuln` or `netstat -tulpen` / `netstat -tuln`
#
# Usage:
#   /usr/local/bin/ports_baseline_monitor.sh
#
# Baseline format (per host):
#   proto|port|process
#   e.g., tcp|22|sshd
#         udp|123|chronyd
#         tcp|5432|postgres
#
# Notes:
#   - Process name may be "-" if not visible; run as root for best detail.
#   - Allowlist supports "proto:port" or "proto:port:proc-substring".

# ========================
# Configuration Variables
# ========================
SERVERLIST="/etc/linux_maint/servers.txt"         # One host per line; if missing → local mode
EXCLUDED="/etc/linux_maint/excluded.txt"          # Optional: hosts to skip
BASELINE_DIR="/etc/linux_maint/baselines/ports"   # Per-host baselines live here
ALLOWLIST_FILE="/etc/linux_maint/ports_allowlist.txt"  # Optional allowlist
ALERT_EMAILS="/etc/linux_maint/emails.txt"        # Optional: recipients (one per line)

LOGFILE="/var/log/ports_baseline_monitor.log"     # Report log
SSH_OPTS="-o BatchMode=yes -o ConnectTimeout=7 -o StrictHostKeyChecking=no"

# Behavior flags
AUTO_BASELINE_INIT="true"      # If no baseline for a host, create it from current snapshot
BASELINE_UPDATE="false"        # If true, replace baseline with current snapshot after reporting
INCLUDE_PROCESS="true"         # Include process names in baseline when available

MAIL_SUBJECT_PREFIX='[Ports Baseline Monitor]'
EMAIL_ON_CHANGE="true"         # Send email when NEW/REMOVED entries are detected

# ========================
# Helpers
# ========================
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOGFILE"; }

is_excluded() {
  local host="$1"
  [ -f "$EXCLUDED" ] || return 1
  grep -Fxq "$host" "$EXCLUDED"
}

send_mail() {
  local subject="$1" body="$2"
  [ "$EMAIL_ON_CHANGE" = "true" ] || return 0
  [ -s "$ALERT_EMAILS" ] || return 0
  command -v mail >/dev/null || return 0
  while IFS= read -r to; do
    [ -n "$to" ] && printf "%s\n" "$body" | mail -s "$MAIL_SUBJECT_PREFIX $subject" "$to"
  done < "$ALERT_EMAILS"
}

ensure_dirs() {
  mkdir -p "$(dirname "$LOGFILE")" "$BASELINE_DIR"
}

# Run a command on a host; if host == localhost and SSH isn't wanted, run locally
run_cmd() {
  local host="$1"; shift
  if [ "$host" = "localhost" ]; then
    bash -lc "$*" 2>/dev/null
  else
    ssh $SSH_OPTS "$host" "$@" 2>/dev/null
  fi
}

# Normalize "ss" output to "proto|port|proc"
collect_with_ss() {
  local host="$1"
  local with_proc_flag=""
  [ "$INCLUDE_PROCESS" = "true" ] && with_proc_flag="-p" || with_proc_flag=""
  # Try with process info first (-p), then without
  local out
  out="$(run_cmd "$host" "ss -H -tulcen $with_proc_flag")"
  if [ -z "$out" ]; then
    out="$(run_cmd "$host" "ss -H -tuln")"
  fi
  [ -z "$out" ] && { echo ""; return; }
  printf "%s\n" "$out" | awk -v incp="$INCLUDE_PROCESS" '
    BEGIN{FS="[[:space:]]+"}
    {
      proto=$1; local=$5; proc="-";
      # Extract port from Local Address:Port (works for IPv6 too - last colon)
      port=local; sub(/^.*:/,"",port);
      # Extract process name from users:(("name",pid=..,fd=..))
      if (incp=="true") {
        match($0, /users:\(\(([^,"]+)/, m)
        if (m[1] != "") proc=m[1];
      }
      print proto "|" port "|" proc
    }
  ' | sort -u
}

# Fallback using netstat
collect_with_netstat() {
  local host="$1"
  local out
  out="$(run_cmd "$host" "netstat -tulpen 2>/dev/null || netstat -tuln 2>/dev/null")"
  [ -z "$out" ] && { echo ""; return; }
  printf "%s\n" "$out" | awk '
    BEGIN{IGNORECASE=1}
    /^Proto/ || /^Active/ {next}
    /^[tu]cp/ || /^[tu]dp/ {
      proto=$1; local=$4; state=$6; prog="-";
      # Some netstat variants shift cols; try to locate program column
      for(i=1;i<=NF;i++){
        if($i ~ /[0-9]+\/[[:graph:]]+/){split($i,a,"/"); if(a[2]!="") prog=a[2]}
      }
      port=local; sub(/^.*:/,"",port);
      print proto "|" port "|" prog
    }
  ' | sort -u
}

collect_current() {
  local host="$1"
  local lines
  lines="$(collect_with_ss "$host")"
  if [ -z "$lines" ]; then
    lines="$(collect_with_netstat "$host")"
  fi
  printf "%s\n" "$lines" | sed '/^$/d'
}

# Allowlist match: "proto:port" or "proto:port:proc-substring"
is_allowed() {
  local entry="$1"   # proto|port|proc
  local proto port proc
  proto="${entry%%|*}"
  rest="${entry#*|}"; port="${rest%%|*}"
  proc="${entry##*|}"

  [ -f "$ALLOWLIST_FILE" ] || return 1
  while IFS= read -r rule; do
    rule="$(echo "$rule" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [ -z "$rule" ] && continue
    [[ "$rule" =~ ^# ]] && continue
    IFS=':' read -r rp rport rproc <<<"$rule"
    [ "$rp" = "$proto" ] || continue
    [ "$rport" = "$port" ] || continue
    if [ -n "$rproc" ]; then
      # case-insensitive substring
      echo "$proc" | grep -iq -- "$rproc" || continue
    fi
    return 0
  done < "$ALLOWLIST_FILE"
  return 1
}

compare_and_report() {
  local host="$1" cur_file="$2" base_file="$3"
  local new_file removed_file
  new_file="$(mktemp)"; removed_file="$(mktemp)"

  comm -13 "$base_file" "$cur_file" > "$new_file"
  comm -23 "$base_file" "$cur_file" > "$removed_file"

  # Filter NEW entries through allowlist
  local new_filtered; new_filtered="$(mktemp)"
  if [ -s "$new_file" ]; then
    while IFS= read -r e; do
      is_allowed "$e" && continue
      echo "$e"
    done < "$new_file" > "$new_filtered"
  else
    : > "$new_filtered"
  fi

  local changes=0

  if [ -s "$new_filtered" ]; then
    changes=1
    log "[$host] NEW listening entries:"
    awk -F'|' '{printf "  + %s/%s (%s)\n",$1,$2,$3}' "$new_filtered" | tee -a "$LOGFILE" >/dev/null
  fi

  if [ -s "$removed_file" ]; then
    changes=1
    log "[$host] REMOVED listening entries:"
    awk -F'|' '{printf "  - %s/%s (%s)\n",$1,$2,$3}' "$removed_file" | tee -a "$LOGFILE" >/dev/null
  fi

  # Prepare email body if changes
  if [ "$changes" -eq 1 ]; then
    local subj="Port changes on $host"
    local body="Host: $host

New entries:
$( [ -s "$new_filtered" ] && awk -F'|' '{printf "  + %s/%s (%s)\n",$1,$2,$3}' "$new_filtered" || echo "  (none)")

Removed entries:
$( [ -s "$removed_file" ] && awk -F'|' '{printf "  - %s/%s (%s)\n",$1,$2,$3}' "$removed_file" || echo "  (none)")

Note: allowlist from $ALLOWLIST_FILE applied to NEW entries."

    send_mail "$subj" "$body"
  fi

  rm -f "$new_file" "$removed_file" "$new_filtered"

  return 0
}

check_host() {
  local host="$1"
  log "===== Checking ports on $host ====="

  # Reachability for remote hosts
  if [ "$host" != "localhost" ]; then
    if ! run_cmd "$host" "echo ok" | grep -q ok; then
      log "[$host] ERROR: SSH unreachable."
      return
    fi
  fi

  local cur_file; cur_file="$(mktemp)"
  collect_current "$host" | sort -u > "$cur_file"

  if [ ! -s "$cur_file" ]; then
    log "[$host] WARNING: No listening sockets detected."
  fi

  local base_file="$BASELINE_DIR/${host}.baseline"
  if [ ! -f "$base_file" ]; then
    if [ "$AUTO_BASELINE_INIT" = "true" ]; then
      cp -f "$cur_file" "$base_file"
      log "[$host] Baseline created at $base_file (initial snapshot)."
      rm -f "$cur_file"
      return
    else
      log "[$host] WARNING: Baseline missing ($base_file). Set AUTO_BASELINE_INIT=true or create it manually."
      rm -f "$cur_file"
      return
    fi
  fi

  # Compare and report
  compare_and_report "$host" "$cur_file" "$base_file"

  # Optionally update baseline after reporting
  if [ "$BASELINE_UPDATE" = "true" ]; then
    cp -f "$cur_file" "$base_file"
    log "[$host] Baseline updated."
  fi

  rm -f "$cur_file"
  log "===== Completed $host ====="
}

# ========================
# Main
# ========================
ensure_dirs
log "=== Ports Baseline Monitor Started ==="

if [ -f "$SERVERLIST" ]; then
  while IFS= read -r HOST; do
    [ -z "$HOST" ] && continue
    is_excluded "$HOST" && { log "Skipping $HOST (excluded)"; continue; }
    check_host "$HOST"
  done < "$SERVERLIST"
else
  # Local mode
  check_host "localhost"
fi

log "=== Ports Baseline Monitor Finished ==="
