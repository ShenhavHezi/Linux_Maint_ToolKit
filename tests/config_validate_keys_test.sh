#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

export LINUX_MAINT_LIB="$ROOT_DIR/lib/linux_maint.sh"
export LM_MODE=repo
export LM_LOG_DIR="$ROOT_DIR/.logs"
mkdir -p "$LM_LOG_DIR"

cfg_dir="$(mktemp -d)"
trap 'rm -rf "$cfg_dir"' EXIT

mkdir -p "$cfg_dir/conf.d"

cat > "$cfg_dir/linux-maint.conf" <<'CONF'
LM_OK=1
LM_DUP=from_root
CONF

cat > "$cfg_dir/conf.d/override.conf" <<'CONF'
LM_DUP=from_override
LM_UNKNOWN=1
CONF

cat > "$cfg_dir/linux-maint.conf.example" <<'CONF'
LM_OK=1
LM_DUP=1
CONF

cat > "$cfg_dir/servers.txt" <<'EOF_S'
localhost
EOF_S

cat > "$cfg_dir/services.txt" <<'EOF_S'
sshd
EOF_S

cat > "$cfg_dir/network_targets.txt" <<'EOF_N'
localhost,ping,1
EOF_N

cat > "$cfg_dir/backup_targets.csv" <<'EOF_B'
localhost,/var/log,24,1,true
EOF_B

cat > "$cfg_dir/certs.txt" <<'EOF_C'
/etc/ssl/certs/ca-bundle.crt
EOF_C

cat > "$cfg_dir/config_paths.txt" <<'EOF_P'
/etc/hosts
EOF_P

cat > "$cfg_dir/ports_baseline.txt" <<'EOF_PB'
# baseline
EOF_PB

set +e
out="$(LM_CFG_DIR="$cfg_dir" LM_LOGFILE="$LM_LOG_DIR/config_validate_keys.log" bash "$ROOT_DIR/monitors/config_validate.sh" 2>&1)"
rc=$?
set -e

printf '%s\n' "$out" | grep -q "status=CRIT" || {
  echo "expected CRIT status" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q "reason=config_validate_crit" || {
  echo "expected config_validate_crit reason" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q "duplicate keys" || {
  echo "expected duplicate keys warning" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q "unknown keys" || {
  echo "expected unknown keys warning" >&2
  echo "$out" >&2
  exit 1
}
[ "$rc" -eq 2 ] || {
  echo "expected exit code 2, got $rc" >&2
  exit 1
}

echo "config validate duplicate/unknown keys ok"
