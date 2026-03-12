#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

cfg="$workdir/etc_linux_maint"
summary_dir="$workdir/logs"
mkdir -p "$cfg/baselines/ports" "$cfg/baselines/configs" "$cfg/baselines/users" "$cfg/baselines/sudoers" "$summary_dir"

printf 'tcp|22|sshd\n' > "$cfg/baselines/ports/localhost.ports"
printf '/etc/ssh/sshd_config\n' > "$cfg/config_paths.txt"
touch -t 202401010101 "$cfg/baselines/ports/localhost.ports"

cat > "$summary_dir/full_health_monitor_summary_latest.log" <<'EOF'
monitor=ports_baseline_monitor host=localhost status=WARN reason=ports_baseline_changed new=1 removed=0
EOF

out="$(
  LM_CFG_DIR="$cfg" \
  SUMMARY_DIR="$summary_dir" \
  LOG_DIR="$summary_dir" \
  "$ROOT_DIR/bin/linux-maint" baseline status --stale-days 1
)"

printf '%s\n' "$out" | grep -q '^== Guidance ==$' || {
  echo "baseline status guidance header missing" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q '^== Summary ==$' || {
  echo "baseline status summary header missing" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q '^baseline status warn$' || {
  echo "baseline status final label missing" >&2
  echo "$out" >&2
  exit 1
}

echo "baseline status human ok"
