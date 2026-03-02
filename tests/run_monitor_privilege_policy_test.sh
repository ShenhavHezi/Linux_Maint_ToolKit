#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"
TMPDIR="${TMPDIR:-/tmp}"
workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

cfg_dir="$workdir/etc"
mkdir -p "$cfg_dir"
printf 'localhost\n' > "$cfg_dir/servers.txt"

# Non-root should fail when monitor policy requires root.
cat > "$cfg_dir/monitor_privilege_policy.conf" <<'P'
health_monitor=requires_root
P
set +e
LM_CFG_DIR="$cfg_dir" bash "$LM" run --plan --local-only --only health_monitor >/dev/null 2>&1
rc_req_root=$?
set -e
[[ "$rc_req_root" -eq 2 ]] || {
  echo "expected requires_root policy failure rc=2, got rc=$rc_req_root" >&2
  exit 1
}

# Non-root should pass when policy forbids sudo/root usage.
cat > "$cfg_dir/monitor_privilege_policy.conf" <<'P'
health_monitor=no_sudo
P
LM_CFG_DIR="$cfg_dir" bash "$LM" run --plan --local-only --only health_monitor >/dev/null

# Invalid policy mode should fail with rc=2.
cat > "$cfg_dir/monitor_privilege_policy.conf" <<'P'
health_monitor=root_only
P
set +e
LM_CFG_DIR="$cfg_dir" bash "$LM" run --plan --local-only --only health_monitor >/dev/null 2>&1
rc_invalid=$?
set -e
[[ "$rc_invalid" -eq 2 ]] || {
  echo "expected invalid policy mode failure rc=2, got rc=$rc_invalid" >&2
  exit 1
}

echo "run monitor privilege policy ok"
