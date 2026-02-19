#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
MON="$ROOT_DIR/monitors/timer_monitor.sh"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

shim="$workdir/shim"
mkdir -p "$shim"

cat > "$shim/systemctl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
cmd="${1:-}"
unit="${@: -1}"

present="${LM_TIMER_PRESENT:-1}"
enabled="${LM_TIMER_ENABLED:-1}"
active="${LM_TIMER_ACTIVE:-1}"

case "$cmd" in
  list-unit-files)
    if [[ "$present" == "1" ]]; then
      echo "${unit} enabled"
    fi
    exit 0
    ;;
  is-enabled)
    if [[ "$present" == "1" && "$enabled" == "1" ]]; then
      echo "enabled"
      exit 0
    fi
    echo "disabled"
    exit 1
    ;;
  is-active)
    if [[ "$present" == "1" && "$active" == "1" ]]; then
      echo "active"
      exit 0
    fi
    echo "inactive"
    exit 3
    ;;
  *)
    exit 1
    ;;
esac
SH
chmod +x "$shim/systemctl"

run_case() {
  local label="$1"; shift
  local expect="$1"; shift
  local envs=("$@")
  out="$(env PATH="$shim:$PATH" LM_LOCKDIR="$workdir" LM_LOGFILE="$workdir/timer.log" "${envs[@]}" bash "$MON")"
  echo "$out" | grep -q "$expect" || { echo "FAIL: $label: $out" >&2; exit 1; }
}

run_case "missing timer" "reason=timer_missing" LM_TIMER_PRESENT=0
run_case "disabled timer" "reason=timer_disabled" LM_TIMER_PRESENT=1 LM_TIMER_ENABLED=0
run_case "inactive timer" "reason=timer_inactive" LM_TIMER_PRESENT=1 LM_TIMER_ENABLED=1 LM_TIMER_ACTIVE=0
run_case "active timer" "status=OK" LM_TIMER_PRESENT=1 LM_TIMER_ENABLED=1 LM_TIMER_ACTIVE=1

echo "timer monitor ok"
