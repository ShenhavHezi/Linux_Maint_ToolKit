#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

run_case(){
  local case_name="$1"
  local tracking_out="$2"

  local workdir
  workdir="$(mktemp -d)"
  trap 'rm -rf "$workdir"' RETURN

  local shim="$workdir/shim"
  mkdir -p "$shim"

  cat > "$shim/ssh" <<SH
#!/usr/bin/env bash
set -euo pipefail
host="\$1"; shift || true
cmd="\$*"
case "\$cmd" in
  *"command -v chronyc"*) exit 0;;
  *"chronyc tracking"*)
$(printf '%s' "$tracking_out" | sed 's/^/    /')
    exit 0
    ;;
  *) exit 1;;
esac
SH
  chmod +x "$shim/ssh"

  out="$({
    PATH="$shim:$PATH" \
    LINUX_MAINT_LIB="$ROOT_DIR/lib/linux_maint.sh" \
    LM_LOCKDIR=/tmp \
    LM_LOGFILE="$workdir/ntp.log" \
    bash "$ROOT_DIR/monitors/ntp_drift_monitor.sh"
  } 2>/dev/null || true)"

  if ! printf '%s\n' "$out" | grep -q '^monitor=ntp_drift_monitor '; then
    echo "[$case_name] expected monitor summary" >&2
    echo "$out" >&2
    exit 1
  fi

  # Must not degrade to WARN just because parsing couldn't find System time; we want a numeric offset
  if printf '%s\n' "$out" | grep -q 'status=WARN'; then
    # Allow WARN only if thresholds are met; but our test offsets are tiny.
    echo "[$case_name] unexpected WARN" >&2
    echo "$out" >&2
    exit 1
  fi

  echo "[$case_name] ok"
}

# Variant 1: System time line missing; Last offset present
run_case "no_system_time" "cat <<'OUT'
Reference ID    : 7F7F0101 (localhost)
Stratum         : 3
Last offset     : 0.000210000 seconds
Leap status     : Normal
OUT"

# Variant 2: System time present but wording differs (fast/slow may be absent); still starts with number
run_case "system_time_simple" "cat <<'OUT'
Reference ID    : 7F7F0101 (localhost)
Stratum         : 3
System time     : 0.001000000 seconds
Leap status     : Normal
OUT"

echo "ntp chrony parsing variants ok"
