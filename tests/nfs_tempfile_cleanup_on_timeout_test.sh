#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

state_dir="$workdir/state"
cfg_dir="$workdir/cfg"
shim="$workdir/shim"
mkdir -p "$state_dir" "$cfg_dir" "$shim"

printf 'slow-host\n' > "$cfg_dir/servers.txt"
: > "$cfg_dir/excluded.txt"

cat > "$shim/ssh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
sleep 5
exit 1
SH
chmod +x "$shim/ssh"

set +e
PATH="$shim:$PATH" \
LINUX_MAINT_LIB="$ROOT_DIR/lib/linux_maint.sh" \
LM_MODE=repo \
LM_CFG_DIR="$cfg_dir" \
LM_SERVERLIST="$cfg_dir/servers.txt" \
LM_EXCLUDED="$cfg_dir/excluded.txt" \
LM_STATE_DIR="$state_dir" \
LM_LOGFILE="$workdir/nfs.log" \
timeout 1s "$ROOT_DIR/monitors/nfs_mount_monitor.sh" >/dev/null 2>&1
rc=$?
set -e

# timed out as intended
[ "$rc" -eq 124 ]

# Ensure no temp alert file leaked after forced timeout/termination.
if find "$state_dir" -maxdepth 1 -type f -name 'nfs_mount_monitor.alerts.*' | grep -q .; then
  echo "leaked nfs temp alert files:" >&2
  find "$state_dir" -maxdepth 1 -type f -name 'nfs_mount_monitor.alerts.*' -print >&2
  exit 1
fi

echo "nfs tempfile cleanup on timeout ok"
