#!/usr/bin/env bash
set -euo pipefail

# Run from repo root.
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

export LINUX_MAINT_LIB="$REPO_ROOT/lib/linux_maint.sh"
# shellcheck disable=SC1090
. "$LINUX_MAINT_LIB"

export LM_LOCKDIR=/tmp
export LM_LOGFILE=/tmp/lm_for_each_host_rc_test.log

# Create a temporary host list. These are not real hosts; our function will ignore the name.
HOSTS_FILE="$(mktemp /tmp/lm_hosts.XXXXXX)"
trap 'rm -f "$HOSTS_FILE"' EXIT
printf '%s\n' h0 h1 h2 h3 h4 h5 h6 h7 h8 h9 > "$HOSTS_FILE"
export LM_SERVERLIST="$HOSTS_FILE"

# Function: returns different codes per host.
fn(){
  local host="$1"
  case "$host" in
    h0|h1|h2) return 0;;
    h3|h4)    return 1;;
    h5)       return 2;;
    h6)       return 3;;
    *)        return 0;;
  esac
}

# Serial should yield worst=3
export LM_MAX_PARALLEL=0
lm_for_each_host_rc fn
rc=$?
[ "$rc" -eq 3 ] || { echo "FAIL serial expected 3 got $rc"; exit 1; }

# Parallel should also yield worst=3
export LM_MAX_PARALLEL=4
lm_for_each_host_rc fn
rc=$?
[ "$rc" -eq 3 ] || { echo "FAIL parallel expected 3 got $rc"; exit 1; }

echo "OK lm_for_each_host_rc"
