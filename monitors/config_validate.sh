#!/usr/bin/env bash
# shellcheck disable=SC1090
# config_validate.sh - Validate /etc/linux_maint configuration files (best-effort)
# Author: Shenhav_Hezi
# Version: 1.0

set -euo pipefail

# Defaults for standalone runs (wrapper sets these)
: "${LM_LOCKDIR:=/tmp}"
: "${LM_LOG_DIR:=.logs}"


. "${LINUX_MAINT_LIB:-/usr/local/lib/linux_maint.sh}" || { echo "Missing ${LINUX_MAINT_LIB:-/usr/local/lib/linux_maint.sh}" >&2; exit 1; }
LM_PREFIX="[config_validate] "
LM_LOGFILE="${LM_LOGFILE:-/var/log/config_validate.log}"

lm_require_singleton "config_validate"

# Dependency checks (local runner)
lm_require_cmd "config_validate" "localhost" awk || exit $?
lm_require_cmd "config_validate" "localhost" find || exit $?
lm_require_cmd "config_validate" "localhost" grep || exit $?
lm_require_cmd "config_validate" "localhost" head || exit $?
lm_require_cmd "config_validate" "localhost" mkdir || exit $?
lm_require_cmd "config_validate" "localhost" paste || exit $?
lm_require_cmd "config_validate" "localhost" sort || exit $?
lm_require_cmd "config_validate" "localhost" tee || exit $?


CFG_DIR="${LM_CFG_DIR:-/etc/linux_maint}"

warn=0
crit=0

ok(){ lm_info "OK  $*"; }
wa(){ lm_warn "WARN $*"; warn=$((warn+1)); }
cr(){ lm_err  "CRIT $*"; crit=$((crit+1)); }

check_csv_cols(){
  local file="$1" mincols="$2" name="$3"
  [ -s "$file" ] || { wa "$name missing/empty: $file"; return; }
  local bad
  bad=$(awk -F',' -v N="$mincols" '
    /^[[:space:]]*#/ {next}
    NF==0 {next}
    NF<N {print NR":"$0}
  ' "$file" | head -n 5)
  if [ -n "$bad" ]; then
    cr "$name has rows with <${mincols} columns: $file (examples: $bad)"
  else
    ok "$name format looks OK: $file"
  fi
}

check_list(){
  local file="$1" name="$2"
  [ -s "$file" ] || { wa "$name missing/empty: $file"; return; }
  ok "$name present: $file"
}

# Validate network_targets.txt
validate_network(){
  local f="$CFG_DIR/network_targets.txt"
  [ -s "$f" ] || { wa "network_targets missing/empty: $f"; return; }
  local bad
  bad=$(awk -F',' '
    /^[[:space:]]*#/ {next}
    NF==0 {next}
    NF<3 {print NR":"$0; next}
    {c=$2; gsub(/^[[:space:]]+|[[:space:]]+$/, "", c);
     if(c!="ping" && c!="tcp" && c!="http") print NR":"$0}
  ' "$f" | head -n 5)
  if [ -n "$bad" ]; then
    cr "network_targets invalid rows (need >=3 cols and check in ping|tcp|http): $bad"
  else
    ok "network_targets format looks OK: $f"
  fi
}

# Validate backup_targets.csv (host,pattern,max_age_hours,min_size_mb,verify) or similar
validate_backup(){
  local f="$CFG_DIR/backup_targets.csv"
  [ -s "$f" ] || { wa "backup_targets missing/empty: $f"; return; }
  local bad
  bad=$(awk -F',' '
    /^[[:space:]]*#/ {next}
    NF==0 {next}
    NF<5 {print NR":"$0}
  ' "$f" | head -n 5)
  if [ -n "$bad" ]; then
    cr "backup_targets rows with <5 columns: $bad"
  else
    ok "backup_targets format looks OK: $f"
  fi
}

validate_certs(){
  local f="$CFG_DIR/certs.txt"
  [ -s "$f" ] || { wa "certs missing/empty (cert monitor will check 0): $f"; return; }
  ok "certs file present: $f"
}

validate(){
  mkdir -p "$(dirname "$LM_LOGFILE")" || true

  # Check for duplicate and unknown config keys across linux-maint.conf + conf.d
  local conf_files=()
  [ -f "$CFG_DIR/linux-maint.conf" ] && conf_files+=("$CFG_DIR/linux-maint.conf")
  if [ -d "$CFG_DIR/conf.d" ]; then
    while IFS= read -r f; do
      conf_files+=("$f")
    done < <(find "$CFG_DIR/conf.d" -maxdepth 1 -type f -name '*.conf' 2>/dev/null | sort)
  fi

  if [ "${#conf_files[@]}" -gt 0 ]; then
    local template=""
    if [ -f "$CFG_DIR/linux-maint.conf.example" ]; then
      template="$CFG_DIR/linux-maint.conf.example"
    elif [ -f "/usr/local/share/linux_maint/templates/linux_maint/linux-maint.conf.example" ]; then
      template="/usr/local/share/linux_maint/templates/linux_maint/linux-maint.conf.example"
    elif [ -f "/usr/share/linux_maint/templates/linux_maint/linux-maint.conf.example" ]; then
      template="/usr/share/linux_maint/templates/linux_maint/linux-maint.conf.example"
    fi

    local allowed_tmp=""
    if [ -n "$template" ]; then
      allowed_tmp="$(awk -F= '
        /^[[:space:]]*#/ {next}
        /^[[:space:]]*$/ {next}
        /^[A-Za-z0-9_]+=/ {print $1}
      ' "$template" | sort -u)"
    fi

    local -A seen=()
    local dup_keys=()
    local unknown_keys=()
    local key
    local line
    for f in "${conf_files[@]}"; do
      while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
          ''|'#'*) continue;;
        esac
        if [[ "$line" =~ ^([A-Za-z0-9_]+)= ]]; then
          key="${BASH_REMATCH[1]}"
          if [[ -n "${seen[$key]+x}" ]]; then
            dup_keys+=("$key")
          else
            seen["$key"]=1
          fi
          if [ -n "$allowed_tmp" ]; then
            if ! printf '%s\n' "$allowed_tmp" | grep -qx "$key"; then
              unknown_keys+=("$key")
            fi
          fi
        fi
      done < "$f"
    done

    if [ "${#dup_keys[@]}" -gt 0 ]; then
      cr "config has duplicate keys: $(printf '%s\n' "${dup_keys[@]}" | sort -u | paste -sd ',' -)"
    fi
    if [ "${#unknown_keys[@]}" -gt 0 ]; then
      wa "config has unknown keys (not in template): $(printf '%s\n' "${unknown_keys[@]}" | sort -u | paste -sd ',' -)"
    fi
  fi

  check_list "$CFG_DIR/servers.txt" "servers"
  check_list "$CFG_DIR/services.txt" "services"

  validate_network
  validate_backup
  validate_certs

  check_list "$CFG_DIR/config_paths.txt" "config_paths"

  # gates
  if [ -s "$CFG_DIR/ports_baseline.txt" ]; then
    ok "ports_baseline gate present"
  else
    wa "ports_baseline gate missing: $CFG_DIR/ports_baseline.txt"
  fi

  if [ "$crit" -gt 0 ]; then
    lm_summary "config_validate" "localhost" "CRIT" warn="$warn" crit="$crit" reason=config_validate_crit
    # legacy:
    # echo "config_validate status=CRIT warn="$warn" crit="$crit""
    exit 2
  fi
  if [ "$warn" -gt 0 ]; then
    lm_summary "config_validate" "localhost" "WARN" warn="$warn" crit="$crit" reason=config_validate_warn
    # legacy:
    # echo "config_validate status=WARN warn="$warn" crit="$crit""
    exit 1
  fi
  lm_summary "config_validate" "localhost" "OK" warn="$warn" crit="$crit"
  # legacy:
  # echo "config_validate status=OK warn="$warn" crit="$crit""
  exit 0
}

validate "$@" | tee -a "$LM_LOGFILE"
