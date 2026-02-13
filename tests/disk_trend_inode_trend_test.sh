#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

export LM_MODE=repo
export LM_DISK_TREND_INODES=1
export LM_STATE_DIR="$workdir/state"
export LM_LOG_DIR="$workdir/logs"
mkdir -p "$LM_STATE_DIR" "$LM_LOG_DIR"

# Shim ssh so remote collection runs locally
shim="$workdir/shim"
mkdir -p "$shim"
cat > "$shim/ssh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

# linux_maint lm_ssh uses: ssh <host> bash -lc "<cmd>"
# We ignore the host and execute the command locally.
if [[ "$#" -ge 4 && "$2" == "bash" && "$3" == "-lc" ]]; then
  bash -lc "$4"
  exit $?
fi

# fallback: execute last arg
bash -lc "${@: -1}"
SH
chmod +x "$shim/ssh"

# Shim df for both space and inode calls
cat > "$shim/df" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$*" == *"-PTi"* ]]; then
  cat <<OUT
Filesystem Type Inodes IUsed IFree IUse% Mounted on
/dev/sda1 ext4 100 10 90 10% /
OUT
  exit 0
fi

if [[ "$*" == *"-Pi"* ]]; then
  cat <<OUT
Filesystem Inodes IUsed IFree IUse% Mounted on
/dev/sda1 100 10 90 10% /
OUT
  exit 0
fi

# default: df -PT -k
cat <<OUT
Filesystem Type 1024-blocks Used Available Capacity Mounted on
/dev/sda1 ext4 1000 100 900 10% /
OUT
SH
chmod +x "$shim/df"

# Run monitor
out="$({
  PATH="$shim:$PATH" \
  LINUX_MAINT_LIB="$ROOT_DIR/lib/linux_maint.sh" \
  LM_LOCKDIR=/tmp \
  LM_LOGFILE="$workdir/disk_trend.log" \
  bash "$ROOT_DIR/monitors/disk_trend_monitor.sh"
} 2>/dev/null || true)"

# Ensure monitor emits summary
printf '%s\n' "$out" | grep -q '^monitor=disk_trend_monitor '

# Ensure inode state file created
inode_state="$LM_STATE_DIR/linux_maint/disk_trend/localhost.inodes.csv"
if [ ! -f "$inode_state" ]; then
  echo "Expected inode state file: $inode_state" >&2
  ls -la "$LM_STATE_DIR" >&2 || true
  exit 1
fi

# Ensure it contains our mount
grep -q ',/,10,10$' "$inode_state"

echo "disk trend inode trend ok"
