#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

# Minimal repo-mode env
export LM_MODE=repo
export LM_LOG_DIR="$ROOT_DIR/.logs"
mkdir -p "$LM_LOG_DIR"

# Enable the new behavior
export LM_SERVICE_CHECK_FAILED_UNITS=1

# Provide a minimal services file for localhost execution
cfg="$workdir/etc_linux_maint"
mkdir -p "$cfg"
printf '%s\n' sshd > "$cfg/services.txt"
export SERVICES="$cfg/services.txt"

# Shim systemctl so we can control `--failed` output
shim="$workdir/shim"
mkdir -p "$shim"
cat > "$shim/systemctl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

# Simulate: systemctl is-active/is-enabled for requested units
case "${1:-}" in
  is-active)
    echo "active"
    exit 0
    ;;
  is-enabled)
    echo "enabled"
    exit 0
    ;;
  --failed)
    # Two failed units (no-legend --plain output style)
    cat <<OUT
foo.service loaded failed failed Foo
bar.service loaded failed failed Bar
OUT
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
SH
chmod +x "$shim/systemctl"

out="$({
  PATH="$shim:$PATH" \
  LINUX_MAINT_LIB="$ROOT_DIR/lib/linux_maint.sh" \
  LM_LOCKDIR=/tmp \
  LM_LOGFILE="$workdir/service_monitor.log" \
  bash "$ROOT_DIR/monitors/service_monitor.sh"
} 2>/dev/null || true)"

# Must show CRIT with reason and failed_units count
printf '%s\n' "$out" | grep -q '^monitor=service_monitor '
printf '%s\n' "$out" | grep -q 'status=CRIT'
printf '%s\n' "$out" | grep -q 'reason=failed_units'
printf '%s\n' "$out" | grep -q 'failed_units=2'

echo "service monitor failed units ok"
