#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REAL_LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

policy_file="$workdir/policy.conf"
cat > "$policy_file" <<'P'
max_crit=999999
max_warn=999999
max_unknown=999999
max_skip=999999
require_overall=
P

mkdir -p "$workdir/bin"
ln -s "$ROOT_DIR/monitors" "$workdir/monitors"
mkdir -p "$workdir/lib"
ln -s "$ROOT_DIR/lib/linux_maint.sh" "$workdir/lib/linux_maint.sh"
for support_lib in linux_maint_runtime.sh linux_maint_admin.sh linux_maint_help.sh linux_maint_tui.sh linux_maint_reporting.sh linux_maint_advanced.sh; do
  ln -s "$ROOT_DIR/lib/$support_lib" "$workdir/lib/$support_lib"
done
ln -s "$ROOT_DIR/run_full_health_monitor.sh" "$workdir/run_full_health_monitor.sh"
fake_lm="$workdir/bin/linux-maint"
cp "$REAL_LM" "$fake_lm"
perl -0pi -e 's@status_json="\$\(NO_COLOR=1 \"\$0\" status --json 2>/dev/null\)"@status_json="$(printf '\''%s\\n'\'' '\''{not-json'\'')"\ngate_status_rc=0@' "$fake_lm"
chmod +x "$fake_lm"

set +e
out="$(bash "$fake_lm" gate --policy "$policy_file" --json 2>&1)"
rc=$?
set -e

if [[ "$rc" -ne 2 ]]; then
  echo "expected gate invalid status rc=2, got rc=$rc" >&2
  echo "$out" >&2
  exit 1
fi

printf '%s\n' "$out" | grep -q '^ERROR: gate requires valid JSON from status --json$' || {
  echo "unexpected gate invalid status output" >&2
  echo "$out" >&2
  exit 1
}

echo "gate invalid status ok"
