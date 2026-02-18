#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

shim="$workdir/shim"
mkdir -p "$shim"

# Shim ssh to execute a controlled set of remote commands locally.
cat > "$shim/ssh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

# Expect: ssh host <cmd...>
host="$1"; shift || true
cmd="$*"

case "$cmd" in
  *"command -v chronyc"*)
    exit 0
    ;;
  *"chronyc tracking"*)
    # default fixture output

    cat <<'OUT'
Reference ID    : 7F7F0101 (localhost)
Stratum         : 3
Ref time (UTC)  : Thu Feb 13 10:00:00 2026
System time     : -0.000123456 seconds slow of NTP time
Last offset     : -0.000120000 seconds
RMS offset      : 0.000200000 seconds
Frequency       : 10.000 ppm fast
Residual freq   : 0.000 ppm
Skew            : 0.001 ppm
Root delay      : 0.000001 seconds
Root dispersion : 0.000100 seconds
Update interval : 64.0 seconds
Leap status     : Normal
OUT
    exit 0
    ;;
  *)
    # default: no output
    exit 1
    ;;
esac
SH
chmod +x "$shim/ssh"

out="$({
  PATH="$shim:$PATH" \
  LINUX_MAINT_LIB="$ROOT_DIR/lib/linux_maint.sh" \
  LM_LOCKDIR="${TMPDIR}" \
  LM_LOGFILE="$workdir/ntp.log" \
  bash "$ROOT_DIR/monitors/ntp_drift_monitor.sh"
} 2>/dev/null || true)"

printf '%s\n' "$out" | grep -q '^monitor=ntp_drift_monitor '
# Should not be UNKNOWN due to parsing
printf '%s\n' "$out" | grep -q 'status=OK\|status=WARN\|status=CRIT'

echo "ntp chrony parsing ok"
