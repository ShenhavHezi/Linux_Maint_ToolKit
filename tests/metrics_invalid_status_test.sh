#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REAL_LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

mkdir -p "$workdir/bin"
ln -s "$ROOT_DIR/monitors" "$workdir/monitors"
mkdir -p "$workdir/lib"
ln -s "$ROOT_DIR/lib/linux_maint.sh" "$workdir/lib/linux_maint.sh"
for support_lib in linux_maint_runtime.sh linux_maint_admin.sh linux_maint_help.sh; do
  ln -s "$ROOT_DIR/lib/$support_lib" "$workdir/lib/$support_lib"
done
ln -s "$ROOT_DIR/run_full_health_monitor.sh" "$workdir/run_full_health_monitor.sh"
fake_lm="$workdir/bin/linux-maint"
cp "$REAL_LM" "$fake_lm"
perl -0pi -e 's@METRICS_STATUS_RC="\$status_rc" python3 - "\$tmp_status" "\$tmp_trend" "\$tmp_runtimes" <<'\''PY'\''@printf '\''%s\\n'\'' '\''{not-json'\'' >"\$tmp_status"\n    METRICS_STATUS_RC="0" python3 - "\$tmp_status" "\$tmp_trend" "\$tmp_runtimes" <<'\''PY'\''@' "$fake_lm"
chmod +x "$fake_lm"

set +e
out="$(bash "$fake_lm" metrics --json 2>&1)"
rc=$?
set -e

if [[ "$rc" -ne 2 ]]; then
  echo "expected metrics invalid status rc=2, got rc=$rc" >&2
  echo "$out" >&2
  exit 1
fi

grep -q '^ERROR: metrics requires valid JSON from status --json$' <<<"$out" || {
  echo "unexpected metrics invalid status output" >&2
  echo "$out" >&2
  exit 1
}

echo "metrics invalid status ok"
