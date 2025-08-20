#!/bin/bash
# cert_monitor.sh - Monitor TLS certificate expiry and validity for endpoints
# Author: Shenhav_Hezi
# Version: 1.0
# Description:
#   Checks TLS certificates for a list of endpoints (host:port) and optional SNI/STARTTLS.
#   Reports days-until-expiry, issuer/subject, and OpenSSL verify status.
#   Logs a concise report and can email alerts when certificates are near expiry or invalid.

# ========================
# Configuration Variables
# ========================
TARGETS_FILE="/etc/linux_maint/certs.txt"     # Lines: host[:port][,sni][,starttls=proto]
ALERT_EMAILS="/etc/linux_maint/emails.txt"    # Optional: recipients (one per line)
LOGFILE="/var/log/cert_monitor.log"           # Log file
THRESHOLD_DAYS=30                              # Warn when <= this many days remain
TIMEOUT_SECS=10                                # Per-connection timeout for openssl
MAIL_SUBJECT_PREFIX='[Cert Monitor]'
EMAIL_ON_WARN="true"                           # Send email when warn/crit occurs

# ========================
# Helper functions
# ========================
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOGFILE"; }

send_mail() {
  local subject="$1" body="$2"
  [ "$EMAIL_ON_WARN" = "true" ] || return 0
  [ -s "$ALERT_EMAILS" ] || return 0
  command -v mail >/dev/null || return 0
  while IFS= read -r to; do
    [ -n "$to" ] && printf "%s\n" "$body" | mail -s "$MAIL_SUBJECT_PREFIX $subject" "$to"
  done < "$ALERT_EMAILS"
}

parse_target_line() {
  # Input line → outputs: HOST PORT SNI STARTTLS
  local line="$1"
  local host sni port starttls
  host="${line%%,*}"           # up to first comma
  sni=""
  port=""
  starttls=""

  # If extras exist after comma(s)
  local rest="${line#*,}"
  if [ "$rest" != "$line" ]; then
    # We may have "sni" and/or "starttls=proto" separated by commas
    IFS=',' read -r a b <<<"$rest"
    for token in "$a" "$b"; do
      [ -z "$token" ] && continue
      case "$token" in
        starttls=*) starttls="${token#starttls=}";;
        *) sni="$token";;
      esac
    done
  fi

  # Extract :port (if present) from host
  if [[ "$host" == *:* ]]; then
    port="${host##*:}"
    host="${host%%:*}"
  else
    port="443"
  fi

  [ -z "$sni" ] && sni="$host"

  printf "%s|%s|%s|%s\n" "$host" "$port" "$sni" "$starttls"
}

check_one() {
  local host="$1" port="$2" sni="$3" starttls="$4"

  local cmd="openssl s_client -servername \"$sni\" -connect \"$host:$port\" -showcerts"
  [ -n "$starttls" ] && cmd="$cmd -starttls $starttls"

  # Capture output once; parse both verify status and cert fields from it
  local out
  out=$(timeout "${TIMEOUT_SECS}s" bash -c "$cmd < /dev/null 2>/dev/null") || out=""

  if [ -z "$out" ]; then
    echo "status=CRIT host=$host port=$port sni=$sni days=? verify=? subject=? issuer=? note=connection_failed"
    return
  fi

  # Verify return code line e.g. "Verify return code: 0 (ok)"
  local verify_line verify_code verify_desc
  verify_line=$(printf "%s\n" "$out" | awk '/Verify return code:/ {line=$0} END{print line}')
  verify_code=$(printf "%s\n" "$verify_line" | sed -n 's/.*Verify return code: \([0-9]\+\).*/\1/p')
  verify_desc=$(printf "%s\n" "$verify_line" | sed -n 's/.*Verify return code: [0-9]\+ (\(.*\)).*/\1/p')
  [ -z "$verify_code" ] && verify_code="?"

  # Extract leaf cert details
  local enddate subject issuer
  enddate=$(printf "%s" "$out" | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
  subject=$(printf "%s" "$out" | openssl x509 -noout -subject 2>/dev/null | sed 's/^subject= *//')
  issuer=$(printf "%s" "$out" | openssl x509 -noout -issuer 2>/dev/null | sed 's/^issuer= *//')

  if [ -z "$enddate" ]; then
    echo "status=CRIT host=$host port=$port sni=$sni days=? verify=$verify_code/$verify_desc subject=? issuer=? note=no_leaf_cert"
    return
  fi

  # Compute days remaining
  local exp_epoch now_epoch days_left
  exp_epoch=$(date -d "$enddate" +%s 2>/dev/null) || exp_epoch=0
  now_epoch=$(date +%s)
  if [ "$exp_epoch" -eq 0 ]; then
    days_left="?"
  else
    days_left=$(( (exp_epoch - now_epoch) / 86400 ))
  fi

  # Decide status
  local status="OK" note=""
  if [ "$days_left" = "?" ]; then
    status="WARN"; note="date_parse_error"
  elif [ "$days_left" -lt 0 ]; then
    status="CRIT"; note="expired"
  elif [ "$days_left" -le "$THRESHOLD_DAYS" ]; then
    status="WARN"; note="near_expiry"
  fi

  # If verification failed and not already CRIT due to expiry, raise WARN/CRIT
  if [ "$verify_code" != "0" ] && [ "$status" = "OK" ]; then
    status="WARN"
    note="verify:$verify_desc"
  fi

  echo "status=$status host=$host port=$port sni=$sni days=$days_left verify=$verify_code/$verify_desc subject=\"$subject\" issuer=\"$issuer\" note=$note"
}

# ========================
# Main
# ========================
log "=== Cert Monitor Started (threshold ${THRESHOLD_DAYS}d) ==="

[ -f "$TARGETS_FILE" ] || { log "ERROR: Targets file $TARGETS_FILE not found."; exit 1; }

alerts=""
while IFS= read -r line; do
  # Skip blanks and comments
  line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  [ -z "$line" ] && continue
  [[ "$line" =~ ^# ]] && continue

  IFS='|' read -r HOST PORT SNI STARTTLS <<<"$(parse_target_line "$line")"
  result=$(check_one "$HOST" "$PORT" "$SNI" "$STARTTLS")

  # Log a concise line
  status=$(echo "$result" | awk '{for(i=1;i<=NF;i++) if($i ~ /^status=/){print substr($i,8)}}')
  days=$(echo "$result" | awk '{for(i=1;i<=NF;i++) if($i ~ /^days=/){print substr($i,6)}}')
  verify=$(echo "$result" | awk '{for(i=1;i<=NF;i++) if($i ~ /^verify=/){print substr($i,8)}}')
  note=$(echo "$result" | awk '{for(i=1;i<=NF;i++) if($i ~ /^note=/){print substr($i,6)}}')

  log "[$status] $HOST:$PORT (SNI=$SNI) days_left=${days:-?} verify=$verify ${note:+note=$note}"

  # Collect alerts
  if [ "$status" = "WARN" ] || [ "$status" = "CRIT" ]; then
    alerts+="$HOST:$PORT (SNI=$SNI): status=$status days_left=${days:-?} verify=$verify ${note:+note=$note}
"
  fi
done < "$TARGETS_FILE"

if [ -n "$alerts" ]; then
  subject="Certificates require attention"
  body="The following endpoints have certificate issues (threshold: ${THRESHOLD_DAYS}d):

$alerts

This is an automated message from cert_monitor.sh."
  send_mail "$subject" "$body"
fi

log "=== Cert Monitor Finished ==="
