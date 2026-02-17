#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

summary_ok="$(mktemp)"
summary_bad_keys="$(mktemp)"
summary_bad_len="$(mktemp)"
trap 'rm -f "$summary_ok" "$summary_bad_keys" "$summary_bad_len"' EXIT

cat > "$summary_ok" <<'S'
monitor=health_monitor host=localhost status=OK node=localhost
monitor=disk_trend_monitor host=localhost status=WARN node=localhost reason=disk_growth mounts=2 warn=1 crit=0 inode_mounts=2 inode_warn=1 inode_crit=0
monitor=inventory_export host=localhost status=SKIP node=localhost reason=missing_inventory_targets_file targets=0
S

python3 "$ROOT_DIR/tests/summary_parse_safety_lint.py" "$summary_ok" >/dev/null
LM_SUMMARY_MAX_LEN=180 bash "$ROOT_DIR/tests/summary_noise_lint.sh" "$summary_ok" >/dev/null

cat > "$summary_bad_keys" <<'S'
monitor=health_monitor host=localhost status=WARN node=localhost reason=too_many a=1 b=2 c=3 d=4 e=5 f=6 g=7 h=8 i=9 j=10 k=11 l=12 m=13 n=14
S

set +e
python3 "$ROOT_DIR/tests/summary_parse_safety_lint.py" "$summary_bad_keys" >/tmp/summary_bad_keys.out 2>&1
rc_keys=$?
set -e
if [[ "$rc_keys" -eq 0 ]]; then
  echo "expected key-budget lint to fail" >&2
  cat /tmp/summary_bad_keys.out >&2 || true
  exit 1
fi
grep -q 'summary key budget exceeded' /tmp/summary_bad_keys.out

cat > "$summary_bad_len" <<'S'
monitor=health_monitor host=localhost status=WARN node=localhost reason=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
S

set +e
LM_SUMMARY_MAX_LEN=120 bash "$ROOT_DIR/tests/summary_noise_lint.sh" "$summary_bad_len" >/tmp/summary_bad_len.out 2>&1
rc_len=$?
set -e
if [[ "$rc_len" -eq 0 ]]; then
  echo "expected length lint to fail" >&2
  cat /tmp/summary_bad_len.out >&2 || true
  exit 1
fi
grep -q 'summary line too long' /tmp/summary_bad_len.out

echo "summary budget lint fixtures ok"
