#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"
TMPDIR="${TMPDIR:-/tmp}"
workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

cfg_dir="$workdir/etc"
mkdir -p "$cfg_dir"
printf 'localhost\n' > "$cfg_dir/servers.txt"

# requires_root should fail for non-root and pass for root.
cat > "$cfg_dir/monitor_privilege_policy.conf" <<'P'
health_monitor=requires_root
P
set +e
LM_CFG_DIR="$cfg_dir" bash "$LM" run --plan --local-only --only health_monitor >/dev/null 2>&1
rc_req_root=$?
set -e
if [[ "$(id -u)" -eq 0 ]]; then
  [[ "$rc_req_root" -eq 0 ]] || {
    echo "expected requires_root policy success as root rc=0, got rc=$rc_req_root" >&2
    exit 1
  }
else
  [[ "$rc_req_root" -eq 2 ]] || {
    echo "expected requires_root policy failure rc=2, got rc=$rc_req_root" >&2
    exit 1
  }
fi

# no_sudo should pass for non-root and fail for root.
cat > "$cfg_dir/monitor_privilege_policy.conf" <<'P'
health_monitor=no_sudo
P
set +e
LM_CFG_DIR="$cfg_dir" bash "$LM" run --plan --local-only --only health_monitor >/dev/null 2>&1
rc_no_sudo=$?
set -e
if [[ "$(id -u)" -eq 0 ]]; then
  [[ "$rc_no_sudo" -eq 2 ]] || {
    echo "expected no_sudo policy failure as root rc=2, got rc=$rc_no_sudo" >&2
    exit 1
  }
else
  [[ "$rc_no_sudo" -eq 0 ]] || {
    echo "expected no_sudo policy success as non-root rc=0, got rc=$rc_no_sudo" >&2
    exit 1
  }
fi

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
