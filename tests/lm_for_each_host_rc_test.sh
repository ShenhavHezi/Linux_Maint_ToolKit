#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

# Run from repo root.
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

export LINUX_MAINT_LIB="$REPO_ROOT/lib/linux_maint.sh"
# shellcheck disable=SC1090
. "$LINUX_MAINT_LIB"

export LM_LOCKDIR="${TMPDIR}"
export LM_LOGFILE=${TMPDIR}/lm_for_each_host_rc_test.log

# Create a temporary host list. These are not real hosts; our function will ignore the name.
HOSTS_FILE="$(mktemp ${TMPDIR}/lm_hosts.XXXXXX)"
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

# IMPORTANT: With `set -e`, calling a function that returns non-zero
# can abort the script unless executed in a conditional context.

# Serial should yield worst=3
export LM_MAX_PARALLEL=0
rc=0
if lm_for_each_host_rc fn; then
  rc=$?
else
  rc=$?
fi
[ "$rc" -eq 3 ] || { echo "FAIL serial expected 3 got $rc"; exit 1; }

# Parallel should also yield worst=3
export LM_MAX_PARALLEL=4
rc=0
if lm_for_each_host_rc fn; then
  rc=$?
else
  rc=$?
fi
[ "$rc" -eq 3 ] || { echo "FAIL parallel expected 3 got $rc"; exit 1; }

echo "OK lm_for_each_host_rc"
