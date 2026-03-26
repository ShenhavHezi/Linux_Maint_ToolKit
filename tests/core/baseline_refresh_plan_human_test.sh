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
touch -t 202401010101 "$cfg/baselines/ports/localhost.ports"

cat > "$summary_dir/full_health_monitor_summary_latest.log" <<'EOF'
monitor=ports_baseline_monitor host=localhost status=WARN reason=ports_baseline_changed new=1 removed=0
EOF

set +e
out="$(
  LM_CFG_DIR="$cfg" \
  SUMMARY_DIR="$summary_dir" \
  LOG_DIR="$summary_dir" \
  "$ROOT_DIR/bin/linux-maint" baseline refresh --plan --stale-days 1 --local-only 2>&1
)"
rc=$?
set -e
[[ "$rc" -eq 1 ]] || {
  echo "expected baseline refresh plan human rc=1, got $rc" >&2
  echo "$out" >&2
  exit 1
}

for required in \
  '^Refresh candidates:$' \
  '^== Guidance ==$' \
  '^== Summary ==$' \
  '^baseline refresh plan warn$'
do
  printf '%s\n' "$out" | grep -q "$required" || {
    echo "baseline refresh human output missing pattern: $required" >&2
    echo "$out" >&2
    exit 1
  }
done

printf '%s\n' "$out" | grep -q 'linux-maint baseline ports --update --local-only' || {
  echo "baseline refresh human output missing ports next step" >&2
  echo "$out" >&2
  exit 1
}

echo "baseline refresh plan human ok"
