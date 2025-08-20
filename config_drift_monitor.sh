#!/bin/bash
# config_drift_monitor.sh - Detect drift in critical config files vs baseline (distributed)
# Author: Shenhav_Hezi
# Version: 1.0
# Description:
#   Hashes a configured set of config files (supports files, globs, directories, recursive),
#   compares against a per-host baseline, and reports:
#     - MODIFIED files (hash changed)
#     - NEW files (present now, absent in baseline)
#     - REMOVED files (present in baseline, missing now)
#   Supports an allowlist, optional baseline auto-init/update, and email alerts.

# ========================
# Configuration Variables
# ========================
SERVERLIST="/etc/linux_maint/servers.txt"              # One host per line; if missing → local mode
EXCLUDED="/etc/linux_maint/excluded.txt"               # Optional: hosts to skip
CONFIG_PATHS="/etc/linux_maint/config_paths.txt"       # Targets (files/dirs/globs); see README
ALLOWLIST_FILE="/etc/linux_maint/config_allowlist.txt" # Optional: paths to ignore (exact or substring)
BASELINE_DIR="/etc/linux_maint/baselines/configs"      # Per-host baselines live here
ALERT_EMAILS="/etc/linux_maint/emails.txt"             # Optional: recipients (one per line)

LOGFILE="/var/log/config_drift_monitor.log"            # Report log
SSH_OPTS="-o BatchMode=yes -o ConnectTimeout=7 -o StrictHostKeyChecking=no"

# Behavior
AUTO_BASELINE_INIT="true"     # If baseline missing for a host, create it from current snapshot
BASELINE_UPDATE="false"       # After reporting, accept current as new baseline
EMAIL_ON_DRIFT="true"         # Send email when drift detected

MAIL_SUBJECT_PREFIX='[Config Drift Monitor]'

# ========================
# Helpers
# ========================
log(){ echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOGFILE"; }

is_excluded(){
  local host="$1"
  [ -f "$EXCLUDED" ] || return 1
  grep -Fxq "$host" "$EXCLUDED"
}

ssh_do(){
  local host="$1"; shift
  if [ "$host" = "localhost" ]; then
    bash -lc "$*" 2>/dev/null
  else
    ssh $SSH_OPTS "$host" "$@" 2>/dev/null
  fi
}

send_mail(){
  local subject="$1" body="$2"
  [ "$EMAIL_ON_DRIFT" = "true" ] || return 0
  [ -s "$ALERT_EMAILS" ] || return 0
  command -v mail >/dev/null || return 0
  while IFS= read -r to; do
    [ -n "$to" ] && printf "%s\n" "$body" | mail -s "$MAIL_SUBJECT_PREFIX $subject" "$to"
  done < "$ALERT_EMAILS"
}

# Return 0 if path is allowlisted (skip drift for this path)
is_allowed_path(){
  local path="$1"
  [ -f "$ALLOWLIST_FILE" ] || return 1
  # Allow either exact match or substring (case-insensitive)
  if grep -Fxq "$path" "$ALLOWLIST_FILE"; then return 0; fi
  if grep -iFq -- "$path" "$ALLOWLIST_FILE"; then return 0; fi
  return 1
}

ensure_dirs(){ mkdir -p "$(dirname "$LOGFILE")" "$BASELINE_DIR"; }

# Remote hasher for a single pattern ($1). Emits lines: "algo|hash|/absolute/path"
# Supports:
#  - file path            -> hash it
#  - glob "*.conf"        -> expand and hash each file
#  - "/dir/"              -> hash all files at depth 1
#  - "/dir/**"            -> recursively hash all files
remote_hash_cmd='
p="$1"
hashbin="$(command -v sha256sum || command -v md5sum)"
algo="$( [ "${hashbin##*/}" = "sha256sum" ] && echo sha256 || echo md5 )"

emit_file(){
  f="$1"
  [ -f "$f" ] || return
  h="$($hashbin "$f" 2>/dev/null | awk "{print \$1}")"
  [ -n "$h" ] && printf "%s|%s|%s\n" "$algo" "$h" "$(readlink -f "$f" 2>/dev/null || echo "$f")"
}

if [[ "$p" == */** ]]; then
  base="${p%/**}"
  [ -d "$base" ] && find "$base" -type f -print0 2>/dev/null | xargs -0r "$hashbin" 2>/dev/null | awk -v a="$algo" "{printf \"%s|%s|%s\\n\", a, \$1, \$2}"
elif [[ "$p" == */ ]]; then
  dir="${p%/}"
  [ -d "$dir" ] && find "$dir" -maxdepth 1 -type f -print0 2>/dev/null | xargs -0r "$hashbin" 2>/dev/null | awk -v a="$algo" "{printf \"%s|%s|%s\\n\", a, \$1, \$2}"
elif [[ "$p" == *\"* ]]; then
  : # ignore bad quotes
elif [[ "$p" == *"*"* || "$p" == *"?"* ]]; then
  shopt -s nullglob dotglob
  for f in $p; do emit_file "$f"; done
else
  emit_file "$p"
fi
'

collect_current(){
  local host="$1"
  local lines=""
  [ -f "$CONFIG_PATHS" ] || { log "[$host] ERROR: config paths file $CONFIG_PATHS not found."; echo ""; return; }
  while IFS= read -r pat; do
    pat="$(echo "$pat" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [ -z "$pat" ] && continue
    [[ "$pat" =~ ^# ]] && continue
    out=$(ssh_do "$host" bash -lc "'$remote_hash_cmd'" _ "$pat")
    [ -n "$out" ] && lines+="$out"$'\n'
  done < "$CONFIG_PATHS"
  # normalize + sort unique
  printf "%s" "$lines" | sed '/^$/d' | sort -u
}

# Compare baseline vs current. Expect lines "algo|hash|path"
compare_and_report(){
  local host="$1" cur_file="$2" base_file="$3"

  # Build path lists
  local cur_paths base_paths
  cur_paths="$(awk -F'|' '{print $3}' "$cur_file" | sort -u)"
  base_paths="$(awk -F'|' '{print $3}' "$base_file" | sort -u)"

  # NEW and REMOVED by set difference
  local new_file removed_file
  new_file="$(mktemp)"; removed_file="$(mktemp)"
  comm -13 <(printf "%s\n" "$base_paths") <(printf "%s\n" "$cur_paths") > "$new_file"
  comm -23 <(printf "%s\n" "$base_paths") <(printf "%s\n" "$cur_paths") > "$removed_file"

  # MODIFIED: paths in intersection where hash differs
  local modified_file
  modified_file="$(mktemp)"
  awk -F'|' 'NR==FNR{b[$3]=$1"|" $2; next} {c[$3]=$1"|" $2} END{for(p in b){if(p in c && b[p]!=c[p]) print p "|" b[p] "|" c[p]}}' \
      "$base_file" "$cur_file" > "$modified_file"

  # Apply allowlist to NEW and MODIFIED (path-based)
  local new_filtered modified_filtered
  new_filtered="$(mktemp)"; modified_filtered="$(mktemp)"

  if [ -s "$new_file" ]; then
    while IFS= read -r p; do
      is_allowed_path "$p" && continue
      echo "$p"
    done < "$new_file" > "$new_filtered"
  else : > "$new_filtered"; fi

  if [ -s "$modified_file" ]; then
    while IFS= read -r line; do
      p="${line%%|*}"
      is_allowed_path "$p" && continue
      echo "$line"
    done < "$modified_file" > "$modified_filtered"
  else : > "$modified_filtered"; fi

  local changes=0

  if [ -s "$modified_filtered" ]; then
    changes=1
    log "[$host] MODIFIED files:"
    awk -F'|' '{printf "  * %s (old:%s new:%s)\n",$1,$2,$3}' "$modified_filtered" | tee -a "$LOGFILE" >/dev/null
  fi

  if [ -s "$new_filtered" ]; then
    changes=1
    log "[$host] NEW files:"
    awk '{printf "  + %s\n",$0}' "$new_filtered" | tee -a "$LOGFILE" >/dev/null
  fi

  if [ -s "$removed_file" ]; then
    changes=1
    log "[$host] REMOVED files:"
    awk '{printf "  - %s\n",$0}' "$removed_file" | tee -a "$LOGFILE" >/dev/null
  fi

  # Email summary if there were changes
  if [ "$changes" -eq 1 ]; then
    local subj="Config drift detected on $host"
    local body="Host: $host

MODIFIED:
$( [ -s "$modified_filtered" ] && awk -F'|' '{printf "  * %s (old:%s new:%s)\n",$1,$2,$3}' "$modified_filtered" || echo "  (none)")

NEW:
$( [ -s "$new_filtered" ] && awk '{printf "  + %s\n",$0}' "$new_filtered" || echo "  (none)")

REMOVED:
$( [ -s "$removed_file" ] && awk '{printf "  - %s\n",$0}' "$removed_file" || echo "  (none)")

Allowlist: $ALLOWLIST_FILE
"
    send_mail "$subj" "$body"
  fi

  rm -f "$new_file" "$removed_file" "$modified_file" "$new_filtered" "$modified_filtered"
  return 0
}

check_host(){
  local host="$1"
  log "===== Checking config drift on $host ====="

  # reachability
  if [ "$host" != "localhost" ]; then
    if ! ssh_do "$host" "echo ok" | grep -q ok; then
      log "[$host] ERROR: SSH unreachable."
      return
    fi
  fi

  local cur_file; cur_file="$(mktemp)"
  collect_current "$host" > "$cur_file"

  if [ ! -s "$cur_file" ]; then
    log "[$host] WARNING: No files matched from $CONFIG_PATHS"
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

  compare_and_report "$host" "$cur_file" "$base_file"

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
log "=== Config Drift Monitor Started ==="

if [ -f "$SERVERLIST" ]; then
  while IFS= read -r HOST; do
    [ -z "$HOST" ] && continue
    is_excluded "$HOST" && { log "Skipping $HOST (excluded)"; continue; }
    check_host "$HOST"
  done < "$SERVERLIST"
else
  check_host "localhost"
fi

log "=== Config Drift Monitor Finished ==="
