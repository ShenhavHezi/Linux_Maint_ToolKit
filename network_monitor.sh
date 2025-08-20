#!/bin/bash
# network_monitor.sh - Ping / TCP / HTTP checks from each host (distributed)
# Author: Shenhav_Hezi
# Version: 1.0
# Description:
#   Runs network reachability/latency checks from one or many Linux servers:
#     - ping: packet loss + avg RTT thresholds
#     - tcp: port reachability + connect latency
#     - http(s): status code + total latency (via curl)
#   Reads checks from /etc/linux_maint/network_targets.txt
#   Logs a concise report and can email alerts on WARN/CRIT.

# ========================
# Configuration Variables
# ========================
SERVERLIST="/etc/linux_maint/servers.txt"          # One host per line; if missing → local mode
EXCLUDED="/etc/linux_maint/excluded.txt"           # Optional: hosts to skip
TARGETS="/etc/linux_maint/network_targets.txt"     # CSV lines: host,check,target,key=val,...
ALERT_EMAILS="/etc/linux_maint/emails.txt"         # Optional: recipients (one per line)
LOGFILE="/var/log/network_monitor.log"             # Report log
SSH_OPTS="-o BatchMode=yes -o ConnectTimeout=7 -o StrictHostKeyChecking=no"

MAIL_SUBJECT_PREFIX='[Network Monitor]'
EMAIL_ON_ALERT="true"

# Defaults (can be overridden per check via key=val)
PING_COUNT=3
PING_TIMEOUT=3             # seconds (overall deadline)
PING_LOSS_WARN=20          # %
PING_LOSS_CRIT=50          # %
PING_RTT_WARN_MS=150       # ms (avg)
PING_RTT_CRIT_MS=500       # ms (avg)

TCP_TIMEOUT=3              # seconds
TCP_LAT_WARN_MS=300
TCP_LAT_CRIT_MS=1000

HTTP_TIMEOUT=5             # seconds
HTTP_LAT_WARN_MS=800
HTTP_LAT_CRIT_MS=2000
HTTP_EXPECT=""             # default: 200–399 if empty

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
  [ "$EMAIL_ON_ALERT" = "true" ] || return 0
  [ -s "$ALERT_EMAILS" ] || return 0
  command -v mail >/dev/null || return 0
  while IFS= read -r to; do
    [ -n "$to" ] && printf "%s\n" "$body" | mail -s "$MAIL_SUBJECT_PREFIX $subject" "$to"
  done < "$ALERT_EMAILS"
}

# ---- Expect matcher for HTTP codes ----
http_code_ok(){
  local code="$1" expect="$2"
  if [ -z "$expect" ]; then
    [ "$code" -ge 200 ] && [ "$code" -lt 400 ] && return 0 || return 1
  fi
  # 2xx style
  if [[ "$expect" =~ ^[1-5]xx$ ]]; then
    local p="${expect%xx}"
    [ "$code" -ge $((p*100)) ] && [ "$code" -lt $((p*100+100)) ] && return 0 || return 1
  fi
  # range 200-299
  if [[ "$expect" =~ ^[0-9]{3}-[0-9]{3}$ ]]; then
    local a="${expect%-*}" b="${expect#*-}"
    [ "$code" -ge "$a" ] && [ "$code" -le "$b" ] && return 0 || return 1
  fi
  # list 200,301,302
  if [[ "$expect" =~ , ]]; then
    IFS=',' read -r -a arr <<<"$expect"
    for x in "${arr[@]}"; do [ "$code" -eq "$x" ] && return 0; done
    return 1
  fi
  # exact 200
  [[ "$expect" =~ ^[0-9]{3}$ ]] && { [ "$code" -eq "$expect" ] && return 0 || return 1; }
  # fallback
  [ "$code" -ge 200 ] && [ "$code" -lt 400 ]
}

# ---- Param parsing: turn "k=v k2=v2" into assoc array P[...] ----
parse_params(){
  declare -n _dst="$1"; shift
  for pair in "$@"; do
    [ -z "$pair" ] && continue
    key="${pair%%=*}"
    val="${pair#*=}"
    _dst["$key"]="$val"
  done
}

# ========================
# Remote probes
# ========================

run_ping(){
  local onhost="$1" target="$2"; shift 2
  declare -A P=()
  parse_params P "$@"
  local cnt="${P[count]:-$PING_COUNT}"
  local to="${P[timeout]:-$PING_TIMEOUT}"
  local lw="${P[loss_warn]:-$PING_LOSS_WARN}"
  local lc="${P[loss_crit]:-$PING_LOSS_CRIT}"
  local rw="${P[rtt_warn_ms]:-$PING_RTT_WARN_MS}"
  local rc="${P[rtt_crit_ms]:-$PING_RTT_CRIT_MS}"

  local out
  out="$(ssh_do "$onhost" "ping -c $cnt -w $to '$target' 2>/dev/null || ping -n -c $cnt -w $to '$target' 2>/dev/null")"
  if [ -z "$out" ]; then
    log "[$onhost] [CRIT] ping $target tool/permission failure"
    echo "ALERT:$onhost:ping:$target:tool_failure"
    return
  fi

  local loss avg
  loss="$(printf "%s\n" "$out" | awk -F',' '/packet loss/ {for(i=1;i<=NF;i++) if($i ~ /packet loss/) {gsub(/[^0-9.]/,"",$i); print $i; exit}}')"
  avg="$(printf "%s\n" "$out" | awk -F'/' '/min\/avg\/|round-trip/ {print $5; exit}')"
  [ -z "$loss" ] && loss="100"
  local status="OK" note=""
  # loss gates
  awk -v L="$loss" -v LC="$lc" 'BEGIN{exit !(L >= LC)}' && { status="CRIT"; note="loss_ge_${lc}%"; }
  if [ "$status" = "OK" ]; then
    awk -v L="$loss" -v LW="$lw" 'BEGIN{exit !(L >= LW)}' && { status="WARN"; note="loss_ge_${lw}%"; }
  fi
  # rtt gates (if we have avg)
  if [ -n "$avg" ]; then
    local ams; ams=$(awk -v a="$avg" 'BEGIN{printf("%.0f", a)}')
    if [ "$ams" -ge "$rc" ]; then status="CRIT"; note="${note:+$note,}rtt_ge_${rc}ms"; fi
    if [ "$status" = "OK" ] && [ "$ams" -ge "$rw" ]; then status="WARN"; note="rtt_ge_${rw}ms"; fi
    log "[$onhost] [$status] ping $target loss=${loss}% avg=${ams}ms ${note:+note=$note}"
  else
    log "[$onhost] [$status] ping $target loss=${loss}% avg=? ${note:+note=$note}"
  fi

  [ "$status" != "OK" ] && echo "ALERT:$onhost:ping:$target:$note"
}

run_tcp(){
  local onhost="$1" hostport="$2"; shift 2
  declare -A P=()
  parse_params P "$@"
  local to="${P[timeout]:-$TCP_TIMEOUT}"
  local lw="${P[latency_warn_ms]:-$TCP_LAT_WARN_MS}"
  local lc="${P[latency_crit_ms]:-$TCP_LAT_CRIT_MS}"
  local host="${hostport%%:*}" port="${hostport##*:}"

  # Try /dev/tcp to capture latency; fallback to nc
  local out
  out="$(ssh_do "$onhost" "start=\$(date +%s%3N 2>/dev/null); exec 3<>/dev/tcp/$host/$port; rc=\$?; end=\$(date +%s%3N 2>/dev/null); [ \$rc -eq 0 ] && { exec 3>&-; echo OK \$((end-start)); } || echo FAIL" )"
  if echo "$out" | grep -q '^OK '; then
    local ms; ms="$(echo "$out" | awk '{print $2}')"
    local status="OK" note=""
    [ -z "$ms" ] && ms="?"
    if [ "$ms" != "?" ] && [ "$ms" -ge "$lc" ]; then status="CRIT"; note="lat_ge_${lc}ms"; fi
    if [ "$status" = "OK" ] && [ "$ms" != "?" ] && [ "$ms" -ge "$lw" ]; then status="WARN"; note="lat_ge_${lw}ms"; fi
    log "[$onhost] [$status] tcp ${host}:${port} conn_ms=${ms} ${note:+note=$note}"
    [ "$status" != "OK" ] && echo "ALERT:$onhost:tcp:${host}:${port}:${note}"
    return
  fi

  # Fallback to nc (no latency)
  if ssh_do "$onhost" "command -v nc >/dev/null"; then
    if ssh_do "$onhost" "nc -z -w $to '$host' '$port'"; then
      log "[$onhost] [OK] tcp ${host}:${port} reachable (nc)"
    else
      log "[$onhost] [CRIT] tcp ${host}:${port} unreachable (nc)"
      echo "ALERT:$onhost:tcp:${host}:${port}:unreachable"
    fi
  else
    log "[$onhost] [CRIT] tcp ${host}:${port} no /dev/tcp latency and nc missing"
    echo "ALERT:$onhost:tcp:${host}:${port}:tool_missing"
  fi
}

run_http(){
  local onhost="$1" url="$2"; shift 2
  declare -A P=()
  parse_params P "$@"
  local to="${P[timeout]:-$HTTP_TIMEOUT}"
  local lw="${P[latency_warn_ms]:-$HTTP_LAT_WARN_MS}"
  local lc="${P[latency_crit_ms]:-$HTTP_LAT_CRIT_MS}"
  local exp="${P[expect]:-$HTTP_EXPECT}"

  if ! ssh_do "$onhost" "command -v curl >/dev/null"; then
    log "[$onhost] [CRIT] http $url curl missing"
    echo "ALERT:$onhost:http:$url:curl_missing"
    return
  fi

  local line; line="$(ssh_do "$onhost" "curl -sS -o /dev/null -w '%{http_code} %{time_total}' --max-time $to '$url'")"
  local code time_s
  code="$(echo "$line" | awk '{print $1}')"
  time_s="$(echo "$line" | awk '{print $2}')"
  local ms="?"
  [ -n "$time_s" ] && ms="$(awk -v t="$time_s" 'BEGIN{printf("%.0f", t*1000)}')"

  local status="OK" note=""
  if ! http_code_ok "$code" "$exp"; then
    status="CRIT"; note="bad_status:$code"
  fi
  if [ "$ms" != "?" ] && [ "$ms" -ge "$lc" ]; then
    status="CRIT"; note="${note:+$note,}lat_ge_${lc}ms"
  elif [ "$status" = "OK" ] && [ "$ms" != "?" ] && [ "$ms" -ge "$lw" ]; then
    status="WARN"; note="lat_ge_${lw}ms"
  fi

  log "[$onhost] [$status] http $url code=$code ms=$ms ${note:+note=$note}"
  [ "$status" != "OK" ] && echo "ALERT:$onhost:http:$url:$note"
}

# ========================
# Per-host runner
# ========================
run_for_host(){
  local host="$1"
  log "===== Network checks from $host ====="

  # reachability (skip for localhost)
  if [ "$host" != "localhost" ]; then
    if ! ssh_do "$host" "echo ok" | grep -q ok; then
      log "[$host] ERROR: SSH unreachable."
      echo "ALERT:$host:ssh_unreachable"
      return
    fi
  fi

  [ -s "$TARGETS" ] || { log "[$host] ERROR: targets file $TARGETS missing/empty."; return; }

  # Select rows for this host (* or exact)
  awk -F',' -v H="$host" '
    /^[[:space:]]*#/ {next}
    NF>=3 {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $1);
      if($1==H || $1=="*"){print $0}
    }' "$TARGETS" |
  while IFS=',' read -r thost check target rest; do
    # Split the rest (k=v pairs) safely
    IFS=',' read -r -a kv <<<"${rest}"
    case "$check" in
      ping) run_ping "$host" "$target" "${kv[@]}" ;;
      tcp)  run_tcp  "$host" "$target" "${kv[@]}" ;;
      http|https) run_http "$host" "$target" "${kv[@]}" ;;
      *) log "[$host] WARNING: unknown check '$check' for target '$target'";;
    esac
  done

  log "===== Completed $host ====="
}

# ========================
# Main
# ========================
log "=== Network Monitor Started ==="

alerts=""
if [ -f "$SERVERLIST" ]; then
  while IFS= read -r HOST; do
    [ -z "$HOST" ] && continue
    is_excluded "$HOST" && { log "Skipping $HOST (excluded)"; continue; }
    out="$(run_for_host "$HOST")"
    case "$out" in
      *ALERT:*) alerts+=$(printf "%s\n" "$out" | sed 's/^.*ALERT://')$'\n' ;;
    esac
  done < "$SERVERLIST"
else
  out="$(run_for_host "localhost")"
  case "$out" in
    *ALERT:*) alerts+=$(printf "%s\n" "$out" | sed 's/^.*ALERT://')$'\n' ;;
  esac
fi

if [ -n "$alerts" ]; then
  subject="Network checks: WARN/CRIT detected"
  body="From network_monitor.sh:

Host | Check | Target | Note
----------------------------
$(echo "$alerts" | awk -F: 'NF>=4{printf "%s | %s | %s | %s\n",$1,$2,$3,$4}') 

Defaults: ping(count=$PING_COUNT,timeout=$PING_TIMEOUT,loss$PING_LOSS_WARN/$PING_LOSS_CRIT,rtt${PING_RTT_WARN_MS}/${PING_RTT_CRIT_MS}ms),
tcp(timeout=$TCP_TIMEOUT,lat${TCP_LAT_WARN_MS}/${TCP_LAT_CRIT_MS}ms),
http(timeout=$HTTP_TIMEOUT,lat${HTTP_LAT_WARN_MS}/${HTTP_LAT_CRIT_MS}ms,expect=${HTTP_EXPECT:-200-399}).
"
  send_mail "$subject" "$body"
fi

log "=== Network Monitor Finished ==="
