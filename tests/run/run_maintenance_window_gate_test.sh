#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT
cfg_dir="$workdir/etc"
mkdir -p "$cfg_dir"
printf '%s\n' localhost > "$cfg_dir/servers.txt"
: > "$cfg_dir/excluded.txt"
: > "$cfg_dir/services.txt"

# impossible window for most runs with day mismatch
cat > "$cfg_dir/maintenance_windows.conf" <<'M'
enabled=1
days=Sun
window=00:00-00:01
M

out="$(LM_CFG_DIR="$cfg_dir" bash "$LM" run --respect-maintenance 2>&1 || true)"
printf '%s\n' "$out" | grep -q 'outside configured maintenance window' || {
  echo "expected maintenance gate message" >&2
  echo "$out" >&2
  exit 1
}

echo "run maintenance gate ok"
