#!/bin/bash
# shellcheck disable=SC1090
# cert_monitor.sh - Monitor TLS certificate expiry and validity for endpoints
# Author: Shenhav_Hezi
# Version: 2.0 (refactored to use linux_maint.sh)
# Description:
#   Checks TLS certificates for a list of endpoints and optional SNI/STARTTLS.
#   Reports days-until-expiry, issuer/subject, and OpenSSL verify status.
#   Logs concise lines and emails a single aggregated alert.

# ===== Shared helpers =====

set -euo pipefail

# Defaults for standalone runs (wrapper sets these)
: "${LM_LOCKDIR:=/tmp}"
: "${LM_LOG_DIR:=.logs}"

. "${LINUX_MAINT_LIB:-/usr/local/lib/linux_maint.sh}" || { echo "Missing ${LINUX_MAINT_LIB:-/usr/local/lib/linux_maint.sh}"; exit 1; }
LM_PREFIX="[cert_monitor] "
LM_LOGFILE="${LM_LOGFILE:-/var/log/cert_monitor.log}"
: "${LM_EMAIL_ENABLED:=true}"
lm_require_singleton "cert_monitor"

# Dependency checks (local runner)
lm_require_cmd "cert_monitor" "localhost" awk || exit $?
lm_require_cmd "cert_monitor" "localhost" date || exit $?
lm_require_cmd "cert_monitor" "localhost" grep || exit $?
lm_require_cmd "cert_monitor" "localhost" openssl || exit $?
lm_require_cmd "cert_monitor" "localhost" sed || exit $?
lm_require_cmd "cert_monitor" "localhost" timeout --optional || true


_summary_emitted=0
emit_summary(){ _summary_emitted=1; lm_summary "cert_monitor" "$@"; }
trap 'rc=$?; if [ "${_summary_emitted:-0}" -eq 0 ]; then lm_summary "cert_monitor" "localhost" "UNKNOWN" reason=early_exit rc="$?"; fi' EXIT
mkdir -p "$(dirname "$LM_LOGFILE")"

MAIL_SUBJECT_PREFIX='[Cert Monitor]'

# ========================
# Configuration
# ========================
TARGETS_FILE="/etc/linux_maint/certs.txt"   # Formats (one per line):
CERTS_SCAN_DIR="${CERTS_SCAN_DIR:-}"
CERTS_SCAN_IGNORE_FILE="${CERTS_SCAN_IGNORE_FILE:-/etc/linux_maint/certs_scan_ignore.txt}"
CERTS_SCAN_EXTS="${CERTS_SCAN_EXTS:-crt,cer,pem}"

#  host[:port]                               # default port 443
#  [ipv6]:port
#  host:port,sni=example.com
#  host:port,starttls=smtp
#  host:port,sni=example.com,starttls=imap
THRESHOLD_WARN_DAYS="${LM_CERT_WARN_DAYS:-30}"
THRESHOLD_CRIT_DAYS="${LM_CERT_CRIT_DAYS:-7}"
TIMEOUT_SECS="${LM_CERT_TIMEOUT_SECS:-10}"
EMAIL_ON_WARN="true"

# ========================
# Helpers (script-local)
# ========================
mail_if_enabled(){ [ "$EMAIL_ON_WARN" = "true" ] || return 0; lm_mail "$1" "$2"; }

load_ignore_patterns() {
  # Outputs ignore patterns, one per line. Blank and # comments ignored.
  local f="$CERTS_SCAN_IGNORE_FILE"
  [ -r "$f" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [ -z "$line" ] && continue
    [[ "$line" =~ ^# ]] && continue
    printf '%s\n' "$line"
  done < "$f"
}

is_ignored_path() {
  local path="$1" pat
  while IFS= read -r pat; do
    [ -z "$pat" ] && continue
    case "$path" in
      *$pat*) return 0 ;;
    esac
  done < <(load_ignore_patterns)
  return 1
}

scan_cert_files() {
  local dir="$1" exts_csv="$2"
  [ -n "$dir" ] || return 0
  [ -d "$dir" ] || return 0

  local find_expr=""
  IFS=',' read -r -a exts <<< "$exts_csv"
  for e in "${exts[@]}"; do
    e="$(printf '%s' "$e" | tr -d '[:space:]')"
    [ -z "$e" ] && continue
    if [ -n "$find_expr" ]; then
      find_expr+=" -o "
    fi
    find_expr+=" -iname *.$e "
  done

  # shellcheck disable=SC2086
  while IFS= read -r p; do
    is_ignored_path "$p" && continue
    printf '%s\n' "$p"
  done < <(find "$dir" -type f \( $find_expr \) 2>/dev/null)
}

check_cert_file() {
  local path="$1"

  # Extract enddate/subject/issuer from file. If unreadable/invalid, report UNKNOWN.
  if [ ! -r "$path" ]; then
    echo "status=UNKNOWN file=\"$path\" days=? subject=? issuer=? note=unreadable"
    return
  fi

  local enddate subject issuer days_left
  enddate="$(openssl x509 -in "$path" -noout -enddate 2>/dev/null | cut -d= -f2)" || enddate=""
  subject="$(openssl x509 -in "$path" -noout -subject 2>/dev/null | sed 's/^subject= *//')" || subject=""
  issuer="$(openssl x509 -in "$path" -noout -issuer 2>/dev/null | sed 's/^issuer= *//')" || issuer=""

  if [ -z "$enddate" ]; then
    echo "status=UNKNOWN file=\"$path\" days=? subject=\"$subject\" issuer=\"$issuer\" note=invalid_cert"
    return
  fi

  local exp_epoch now_epoch
  exp_epoch=$(date -u -d "$enddate" +%s 2>/dev/null) || exp_epoch=0
  now_epoch=$(date -u +%s)
  if [ "$exp_epoch" -eq 0 ]; then
    days_left="?"
  else
    days_left=$(( (exp_epoch - now_epoch) / 86400 ))
  fi
  days_left=${days_left:-?}

  local status="OK" note=""
  if [ "$days_left" = "?" ]; then
    status="UNKNOWN"; note="parse_failed"
  else
    if [ "$days_left" -le 0 ]; then
      status="CRIT"; note="expired"
    elif [ "$days_left" -le "$THRESHOLD_CRIT_DAYS" ]; then
      status="CRIT"; note="<=${THRESHOLD_CRIT_DAYS}d"
    elif [ "$days_left" -le "$THRESHOLD_WARN_DAYS" ]; then
      status="WARN"; note="<=${THRESHOLD_WARN_DAYS}d"
    fi
  fi

  # shell-quote minimally (avoid breaking logs)
  subject="${subject//\"/\\\"}"
  issuer="${issuer//\"/\\\"}"

  echo "status=$status file=\"$path\" days=$days_left subject=\"$subject\" issuer=\"$issuer\" note=$note"
}

parse_target_line() {
  # Input line -> HOST|PORT|SNI|STARTTLS
  local line="$1" hostport sni starttls host port extra token
  sni=""; starttls=""; host=""; port="443"

  # split head (host[:port] / [ipv6]:port) from extras
  hostport="${line%%,*}"
  extra="${line#"$hostport"}"
  extra="${extra#,}"  # remove leading comma if present

  # host/port parsing
  if [[ "$hostport" =~ ^\[.*\]:[0-9]+$ ]]; then
    host="${hostport%\]*}"; host="${host#[}"; port="${hostport##*:}"
  else
    # if exactly one colon and digits after it -> treat as host:port; else default 443
    if [[ "$hostport" == *:* ]] && [ "$(printf "%s" "$hostport" | grep -o ":" | wc -l)" -eq 1 ] && [[ "${hostport##*:}" =~ ^[0-9]+$ ]]; then
      host="${hostport%%:*}"; port="${hostport##*:}"
    else
      host="$hostport"; port="443"
    fi
  fi

  # parse extras (order-independent)
  IFS=',' read -r -a arr <<< "$extra"
  for token in "${arr[@]}"; do
    [ -z "$token" ] && continue
    case "$token" in
      sni=*)       sni="${token#sni=}" ;;
      starttls=*)  starttls="${token#starttls=}" ;;
      *)           [ -z "$sni" ] && sni="$token" ;;  # bare token treated as SNI
    esac
  done
  [ -z "$sni" ] && sni="$host"
  printf "%s|%s|%s|%s\n" "$host" "$port" "$sni" "$starttls"
}

extract_leaf_cert() {
  # Reads s_client output on stdin, prints the first cert PEM block
  awk '
    /-----BEGIN CERTIFICATE-----/ {inblk=1}
    inblk {print}
    /-----END CERTIFICATE-----/ {exit}
  '
}

check_one() {
  local host="$1" port="$2" sni="$3" starttls="$4"
  local cmd="openssl s_client -servername \"$sni\" -connect \"$host:$port\" -showcerts"
  [ -n "$starttls" ] && cmd="$cmd -starttls $starttls"

  local out
  out=$(timeout "${TIMEOUT_SECS}s" bash -lc "$cmd < /dev/null 2>/dev/null") || out=""

  if [ -z "$out" ]; then
    echo "status=CRIT host=$host port=$port sni=$sni days=? verify=? subject=? issuer=? note=connection_failed"
    return
  fi

  # Verify return code
  local verify_line verify_code verify_desc
  verify_line=$(printf "%s\n" "$out" | awk '/Verify return code:/ {line=$0} END{print line}')
  verify_code=$(printf "%s\n" "$verify_line" | sed -n 's/.*Verify return code: \([0-9]\+\).*/\1/p')
  verify_desc=$(printf "%s\n" "$verify_line" | sed -n 's/.*Verify return code: [0-9]\+ (\(.*\)).*/\1/p')
  [ -z "$verify_code" ] && verify_code="?"

  # Leaf certificate fields
  local leaf subject issuer enddate
  leaf="$(printf "%s\n" "$out" | extract_leaf_cert)"
  if [ -z "$leaf" ]; then
    echo "status=CRIT host=$host port=$port sni=$sni days=? verify=$verify_code/$verify_desc subject=? issuer=? note=no_leaf_cert"
    return
  fi

  subject="$(printf "%s" "$leaf" | openssl x509 -noout -subject 2>/dev/null | sed 's/^subject= *//')"
  issuer="$(printf "%s" "$leaf" | openssl x509 -noout -issuer 2>/dev/null | sed 's/^issuer= *//')"
  enddate="$(printf "%s" "$leaf" | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)"

  local exp_epoch now_epoch days_left
  exp_epoch=$(date -u -d "$enddate" +%s 2>/dev/null) || exp_epoch=0
  now_epoch=$(date -u +%s)
  if [ "$exp_epoch" -eq 0 ]; then
    days_left="?"
  else
    days_left=$(( (exp_epoch - now_epoch) / 86400 ))
  fi

  # Status
  local status="OK" note=""
  if [ "$days_left" = "?" ]; then
    status="WARN"; note="date_parse_error"
  elif [ "$days_left" -lt 0 ]; then
    status="CRIT"; note="expired"
  elif [ "$days_left" -le "$THRESHOLD_CRIT_DAYS" ]; then
    status="CRIT"; note="<=${THRESHOLD_CRIT_DAYS}d"
  elif [ "$days_left" -le "$THRESHOLD_WARN_DAYS" ]; then
    status="WARN"; note="<=${THRESHOLD_WARN_DAYS}d"
  fi
  if [ "$verify_code" != "0" ] && [ "$verify_code" != "?" ] && [ "$status" = "OK" ]; then
    status="WARN"; note="verify:$verify_desc"
  fi

  # shell-quote subject/issuer minimally (avoid breaking logs)
  subject="${subject//\"/\\\"}"
  issuer="${issuer//\"/\\\"}"

  echo "status=$status host=$host port=$port sni=$sni days=$days_left verify=$verify_code/$verify_desc subject=\"$subject\" issuer=\"$issuer\" note=$note"
}

# ========================
# Main
# ========================
lm_info "=== Cert Monitor Started (warn=${THRESHOLD_WARN_DAYS}d crit=${THRESHOLD_CRIT_DAYS}d timeout=${TIMEOUT_SECS}s) ==="

# Targets list is required unless scanning a cert directory is enabled.
if [ -z "$CERTS_SCAN_DIR" ]; then
  [ -s "$TARGETS_FILE" ] || { lm_err "Targets file not found/empty: $TARGETS_FILE"; exit 1; }
fi


ALERTS_FILE="$(lm_mktemp cert_monitor.alerts.XXXXXX)"
checked=0
warn=0
crit=0
while IFS= read -r raw; do
  raw="$(echo "$raw" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  [ -z "$raw" ] && continue
  [[ "$raw" =~ ^# ]] && continue

  IFS='|' read -r HOST PORT SNI STARTTLS <<<"$(parse_target_line "$raw")"
  checked=$((checked+1))
  res="$(check_one "$HOST" "$PORT" "$SNI" "$STARTTLS")"

  status="$(printf "%s\n" "$res" | awk '{for(i=1;i<=NF;i++) if($i ~ /^status=/){print substr($i,8)}}')"
  days="$(  printf "%s\n" "$res" | awk '{for(i=1;i<=NF;i++) if($i ~ /^days=/){print substr($i,6)}}')"
  verify="$(printf "%s\n" "$res" | awk '{for(i=1;i<=NF;i++) if($i ~ /^verify=/){print substr($i,8)}}')"
  note="$(  printf "%s\n" "$res" | awk '{for(i=1;i<=NF;i++) if($i ~ /^note=/){print substr($i,6)}}')"

  lm_info "[$status] $HOST:$PORT (SNI=$SNI) days_left=${days:-?} verify=$verify ${note:+note=$note}"

  [ "$status" = "WARN" ] && warn=$((warn+1))
  [ "$status" = "CRIT" ] && crit=$((crit+1))

  if [ "$status" = "WARN" ] || [ "$status" = "CRIT" ]; then
    printf "%s|%s|%s|%s|%s|%s\n" "$HOST:$PORT" "$SNI" "${days:-?}" "$verify" "$status" "$note" >> "$ALERTS_FILE"
  fi
done < "$TARGETS_FILE"

# Optional: scan a directory for cert files and evaluate their expiration (offline).
if [ -n "$CERTS_SCAN_DIR" ]; then
  while IFS= read -r cert_path; do
    [ -n "$cert_path" ] || continue
    checked=$((checked+1))
    res="$(check_cert_file "$cert_path")"
    status="$(printf "%s\n" "$res" | awk "{for(i=1;i<=NF;i++) if(\$i ~ /^status=/){print substr(\$i,8)}}")"
    days="$(printf "%s\n" "$res" | awk "{for(i=1;i<=NF;i++) if(\$i ~ /^days=/){print substr(\$i,6)}}")"
    note="$(printf "%s\n" "$res" | awk "{for(i=1;i<=NF;i++) if(\$i ~ /^note=/){print substr(\$i,6)}}")"
    lm_info "[$status] file=$cert_path days_left=${days:-?} ${note:+note=$note}"
    [ "$status" = "WARN" ] && warn=$((warn+1))
    [ "$status" = "CRIT" ] && crit=$((crit+1))
    if [ "$status" = "WARN" ] || [ "$status" = "CRIT" ]; then
      printf "%s|%s|%s|%s|%s|%s\n" "$cert_path" "-" "${days:-?}" "file" "$status" "$note" >> "$ALERTS_FILE"
    fi
  done < <(scan_cert_files "$CERTS_SCAN_DIR" "$CERTS_SCAN_EXTS")
fi

overall="OK"
if [ ${crit:-0} -gt 0 ]; then overall="CRIT"; elif [ ${warn:-0} -gt 0 ]; then overall="WARN"; fi
emit_summary "all" "$overall" checked=${checked:-0} warn=${warn:-0} crit=${crit:-0}
# legacy:
# echo "cert_monitor summary status=$overall checked=${checked:-0} warn=${warn:-0} crit=${crit:-0}"

alerts="$(cat "$ALERTS_FILE" 2>/dev/null)"
rm -f "$ALERTS_FILE" 2>/dev/null || true

if [ -n "$alerts" ]; then
  subject="Certificates require attention"
  body="Thresholds: WARN<=${THRESHOLD_WARN_DAYS}d, CRIT<=${THRESHOLD_CRIT_DAYS}d (or expired)

Endpoint | SNI | Days Left | Verify | Status | Note
---------|-----|-----------|--------|--------|-----
$(echo "$alerts" | awk -F'|' '{printf "%s | %s | %s | %s | %s | %s\n",$1,$2,$3,$4,$5,(NF>=6?$6:"")}')

This is an automated message from cert_monitor.sh."
  mail_if_enabled "$MAIL_SUBJECT_PREFIX $subject" "$body"
fi

lm_info "=== Cert Monitor Finished ==="

# cert_monitor summary (end)
