#!/bin/bash
# log_growth_guard.sh - Detect oversized / fast-growing logs (distributed)
# Author: Shenhav_Hezi
# Version: 1.0
# Description:
#   Scans one or many Linux servers and checks configured log files/sets for:
#     - absolute size thresholds (WARN/CRIT)
#     - growth rate since last run (MB/hour; WARN/CRIT)
#   Keeps a per-host state file with previous sizes/timestamps,
#   logs a concise report, and can send email alerts.

# ========================
# Configuration Variables
# ========================
SERVERLIST="/etc/linux_maint/servers.txt"     # One host per line; if missing → local mode
EXCLUDED="/etc/linux_maint/excluded.txt"      # Optional: hosts to skip
LOG_PATHS="/etc/linux_maint/log_paths.txt"    # Targets (files/dirs/globs), see README
ALERT_EMAILS="/etc/linux_maint/emails.txt"    # Optional: recipients (one per line)
LOGFILE="/var/log/log_growth_guard.log"       # Report log
STATE_DIR="/var/tmp"                           # Per-host state files live here
SSH_OPTS="-o BatchMode=yes -o ConnectTimeout=7 -o StrictHostKeyChecking=no"

# Size thresholds (in MB)
SIZE_WARN_MB=1024
SIZE_CRIT_MB=2048

# Growth rate thresholds (in MB per hour)
RATE_WARN_MBPH=200
RATE_CRIT_MBPH=500

MAIL_SUBJECT_PREFIX='[Log Growth Guard]'
EMAIL_ON_ALERT="true"      # Send email on WARN/CRIT
AUTO_ROTATE="false"        # Very conservative: do not touch files unless you set true
ROTATE_CMD=""              # e.g., 'logrotate -f /etc/logrotate.d/myapp' OR 'cp /dev/null "$f"'

# ========================
# Helpers
# ========================
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOGFILE"; }

is_excluded() {
  local host="$1"
  [ -f "$EXCLUDED" ] || return 1
  grep -Fxq "$host" "$EXCLUDED"
}

ssh_do() {
  local host="$1"; shift
  ssh $SSH_OPTS "$host" "$@" 2>/dev/null
}

send_mail() {
  local subject="$1" body="$2"
  [ "$EMAIL_ON_ALERT" = "true" ] || return 0
  [ -s "$ALERT_EMAILS" ] || return 0
  command -v mail >/dev/null || return 0
  while IFS= read -r to; do
    [ -n "$to" ] && printf "%s\n" "$body" | mail -s "$MAIL_SUBJECT_PREFIX $subject" "$to"
  done < "$ALERT_EMAILS"
}

# Remote collector: prints "path|size_bytes|mtime_epoch" for a single pattern arg ($1)
remote_collect_cmd='
p="$1"
printf_collect() { f="$1"; [ -f "$f" ] || return; size=$(stat -c %s "$f" 2>/dev/null || echo 0); m=$(stat -c %Y "$f" 2>/dev/null || date +%s); printf "%s|%s|%s\n" "$f" "$size" "$m"; }
if [[ "$p" == */** ]]; then
  base="${p%/**}"; [ -d "$base" ] && find "$base" -type f -printf "%p|%s|%T@\n" | awk -F"|" "{printf(\"%s|%s|%d\n\",\$1,\$2,int(\$3))}"
elif [[ "$p" == */ ]]; then
  dir="${p%/}"; [ -d "$dir" ] && find "$dir" -maxdepth 1 -type f -printf "%p|%s|%T@\n" | awk -F\"|\" "{printf(\"%s|%s|%d\n\",\$1,\$2,int(\$3))}"
elif [[ "$p" == *"*"* || "$p" == *"?"* ]]; then
  shopt -s nullglob dotglob; for f in $p; do printf_collect "$f"; done
else
  printf_collect "$p"
fi
'

collect_for_host() {
  local host="$1"
  local lines=""
  [ -f "$LOG_PATHS" ] || { log "[$host] ERROR: log paths file $LOG_PATHS not found."; echo ""; return; }
  while IFS= read -r pat; do
    pat="$(echo "$pat" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [ -z "$pat" ] && continue
    [[ "$pat" =~ ^# ]] && continue
    # Pass pattern as $1 to remote bash -lc to avoid local globbing
    out=$(ssh_do "$host" bash -lc "'$remote_collect_cmd'" _ "$pat")
    [ -n "$out" ] && lines+="$out"$'\n'
  done < "$LOG_PATHS"
  printf "%s" "$lines"
}

rate_status() {
  local size_mb="$1" rate_mbph="$2"
  local st="OK"
  # Size gates
  if [ "$size_mb" -ge "$SIZE_CRIT_MB" ]; then st="CRIT"
  elif [ "$size_mb" -ge "$SIZE_WARN_MB" ]; then st="WARN"; fi
  # Rate gates (take worst)
  if [ "$rate_mbph" != "?" ]; then
    if awk "BEGIN{exit !($rate_mbph >= $RATE_CRIT_MBPH)}"; then st="CRIT"
    elif awk "BEGIN{exit !($rate_mbph >= $RATE_WARN_MBPH)}"; then [ "$st" = "OK" ] && st="WARN"; fi
  fi
  echo "$st"
}

check_host() {
  local host="$1"
  log "===== Checking log growth on $host ====="

  # Reachability
  if ! ssh_do "$host" "echo ok" | grep -q ok; then
    log "[$host] ERROR: SSH unreachable."; return
  fi

  local now=$(date +%s)
  local state="$STATE_DIR/log_growth_guard.${host}.state"
  [ -f "$state" ] || : > "$state"

  # Load previous state into awk map: path -> "bytes|ts"
  local prev="$STATE_DIR/log_growth_guard.${host}.prev"
  cp -f "$state" "$prev" 2>/dev/null || : 

  local current=$(collect_for_host "$host")
  [ -z "$current" ] && { log "[$host] WARNING: No matching files from $LOG_PATHS"; return; }

  # Rewrite state afresh
  : > "$state"

  # Build an index of previous values using awk on the fly
  while IFS='|' read -r path bytes mtime; do
    [ -z "$path" ] && continue
    # Current stats
    cur_b=$bytes
    cur_mb=$(( (cur_b + 1048575) / 1048576 ))
    # Find previous
    prev_b=$(awk -F'|' -v p="$path" '$1==p{print $2; exit}' "$prev")
    prev_ts=$(awk -F'|' -v p="$path" '$1==p{print $3; exit}' "$prev")

    rate="?"
    note=""
    if [ -n "$prev_b" ] && [ -n "$prev_ts" ]; then
      dt=$(( now - prev_ts ))
      if [ "$dt" -gt 0 ]; then
        delta=$(( cur_b - prev_b ))
        if [ "$delta" -lt 0 ]; then
          # rotated or truncated
          note="rotated_or_truncated"
          delta=0
        fi
        # MB per hour (rounded)
        rate=$(awk -v d="$delta" -v t="$dt" 'BEGIN{printf("%.1f", (d/1048576.0)/(t/3600.0))}')
      fi
    fi

    status=$(rate_status "$cur_mb" "$rate")

    log "[$status] $path size=${cur_mb}MB rate=${rate}MB/h ${note:+note=$note}"

    if [ "$status" != "OK" ] && [ "$AUTO_ROTATE" = "true" ] && [ -n "$ROTATE_CMD" ]; then
      ssh_do "$host" bash -lc "$ROTATE_CMD"
      log "[$host] rotate_cmd executed for $path"
    fi

    # Write state line
    printf "%s|%s|%s\n" "$path" "$cur_b" "$now" >> "$state"
  done <<< "$current"

  # Detect removed files (previously tracked but now gone → likely rotated)
  while IFS='|' read -r p_old _ _; do
    echo "$current" | grep -Fq "$p_old" || log "[INFO] $p_old no longer present (rotated/removed)"
  done < "$prev"

  rm -f "$prev" 2>/dev/null || :
  log "===== Completed $host ====="
}

# ========================
# Main
# ========================
log "=== Log Growth Guard Started (size warn=${SIZE_WARN_MB}MB crit=${SIZE_CRIT_MB}MB; rate warn=${RATE_WARN_MBPH}MB/h crit=${RATE_CRIT_MBPH}MB/h) ==="

alerts_for_mail=""
if [ -f "$SERVERLIST" ]; then
  while IFS= read -r HOST; do
    [ -z "$HOST" ] && continue
    is_excluded "$HOST" && { log "Skipping $HOST (excluded)"; continue; }
    check_host "$HOST"
  done < "$SERVERLIST"
else
  check_host "localhost"
fi

# Optional: email the whole log file tail if any WARN/CRIT lines exist
if grep -E "\[(WARN|CRIT)\]" "$LOGFILE" | tail -n 1 >/dev/null 2>&1; then
  if [ "$EMAIL_ON_ALERT" = "true" ] && [ -s "$ALERT_EMAILS" ] && command -v mail >/dev/null; then
    tail -n 200 "$LOGFILE" | send_mail "Log growth alerts" "$(cat)"
  fi
fi

log "=== Log Growth Guard Finished ==="
