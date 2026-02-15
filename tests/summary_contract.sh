#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Optional overrides for targeted tests/debugging.
SUMMARY_CONTRACT_MONITORS_DIR="${SUMMARY_CONTRACT_MONITORS_DIR:-$ROOT_DIR/monitors}"
SUMMARY_CONTRACT_MONITOR_TIMEOUT_SECS="${SUMMARY_CONTRACT_MONITOR_TIMEOUT_SECS:-45}"
SUMMARY_CONTRACT_MONITOR_LIST_FILE="${SUMMARY_CONTRACT_MONITOR_LIST_FILE:-$ROOT_DIR/tests/summary_contract.monitors}"

# Run a monitor in a minimal local environment and check it emits at least one summary line.
# Some monitors are intentionally SKIP depending on config; those should still not break.

load_monitor_list() {
  local src="$1"
  awk '
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*$/ { next }
    { gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0); print $0 }
  ' "$src"
}

monitors=()
if [[ -n "${SUMMARY_CONTRACT_MONITORS:-}" ]]; then
  # shellcheck disable=SC2206
  monitors=(${SUMMARY_CONTRACT_MONITORS})
elif [[ -f "$SUMMARY_CONTRACT_MONITOR_LIST_FILE" ]]; then
  while IFS= read -r monitor; do
    monitors+=("$monitor")
  done < <(load_monitor_list "$SUMMARY_CONTRACT_MONITOR_LIST_FILE")
else
  while IFS= read -r monitor; do
    monitors+=("$(basename "$monitor")")
  done < <(find "$SUMMARY_CONTRACT_MONITORS_DIR" -maxdepth 1 -type f -name '*.sh' | sort)
fi

if [[ "${#monitors[@]}" -eq 0 ]]; then
  echo "FAIL: no monitors selected for summary contract test" >&2
  exit 1
fi

export LINUX_MAINT_LIB="$ROOT_DIR/lib/linux_maint.sh"
export LM_LOCKDIR="/tmp"
export LM_LOGFILE="/tmp/linux_maint_contract_test.log"
export LM_EMAIL_ENABLED="false"
export LM_STATE_DIR="/tmp"
export LM_SSH_OPTS="-o BatchMode=yes -o ConnectTimeout=3"
# Force local-only during CI contract test to avoid SSH delays/hangs.
# Use a writable config dir with localhost so per-host monitors always execute
# and emit at least one monitor= summary line.
export LM_CFG_DIR="${LM_CFG_DIR:-/tmp/linux_maint_cfg_contract}"
export LM_SERVERLIST="$LM_CFG_DIR/servers.txt"
export LM_EXCLUDED="$LM_CFG_DIR/excluded.txt"
export LM_LOCAL_ONLY="true"
export LM_INVENTORY_OUTPUT_DIR="/tmp/linux_maint_inventory"
mkdir -p "$LM_INVENTORY_OUTPUT_DIR" "$LM_CFG_DIR" >/dev/null 2>&1 || true
printf 'localhost\n' > "$LM_SERVERLIST"
printf 'localhost
' > "$LM_SERVERLIST"
: > "$LM_EXCLUDED"

fail=0
for m in "${monitors[@]}"; do
  path="$SUMMARY_CONTRACT_MONITORS_DIR/$m"
  if [[ ! -f "$path" ]]; then
    echo "MISSING monitor file: $m" >&2
    fail=1
    continue
  fi

  out="$(mktemp)"
  # run best-effort; monitor may exit nonzero due to real system state
  set +e
  if command -v timeout >/dev/null 2>&1; then
    LM_LOGFILE="/tmp/${m%.sh}.log" timeout "${SUMMARY_CONTRACT_MONITOR_TIMEOUT_SECS}s" bash "$path" >"$out" 2>&1
    rc=$?
    if [[ "$rc" -eq 124 ]]; then
      echo "TIMEOUT: $m exceeded ${SUMMARY_CONTRACT_MONITOR_TIMEOUT_SECS}s" >&2
      echo "--- output ---" >&2
      tail -n 60 "$out" >&2 || true
      echo "-------------" >&2
      fail=1
      set -e
      rm -f "$out"
      continue
    fi
  else
    LM_LOGFILE="/tmp/${m%.sh}.log" bash "$path" >"$out" 2>&1
    rc=$?
  fi

  if [[ "$rc" -ne 0 && ! -s "$out" ]]; then
    echo "NOTE: $m exited rc=$rc with empty output" >&2
    echo "env: LINUX_MAINT_LIB=$LINUX_MAINT_LIB LM_LOCKDIR=$LM_LOCKDIR LM_STATE_DIR=$LM_STATE_DIR LM_LOGFILE=/tmp/${m%.sh}.log" >&2
  fi
  set -e

  # Contract: if it ran, it should emit at least one monitor= line OR explicitly SKIP inside output.
  if ! grep -q '^monitor=' "$out"; then
    if grep -q '^SKIP:' "$out"; then
      echo "OK (skipped): $m"
    else
      echo "FAIL: $m produced no '^monitor=' summary line (rc=$rc)" >&2
      echo "--- output ---" >&2
      tail -n 60 "$out" >&2 || true
      echo "-------------" >&2
      fail=1
    fi
  else
    # Warn if too many summary lines (helps keep standardization tight)
    c="$(grep -c '^monitor=' "$out" || true)"
    if [[ "$c" -gt 5 ]]; then
      echo "WARN: $m produced $c monitor= lines (expected usually 1 or per-host)." >&2
    else
      echo "OK: $m ($c summary lines, rc=$rc)"
    fi
  fi

  rm -f "$out"
done

exit "$fail"
