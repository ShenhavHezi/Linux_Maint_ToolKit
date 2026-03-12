#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

set +e
bash "$LM" notify --provider slack --dry-run >/dev/null 2>&1
rc_missing=$?
set -e
[[ "$rc_missing" -eq 2 ]] || {
  echo "expected missing url rc=2, got rc=$rc_missing" >&2
  exit 1
}

out1="$(bash "$LM" notify --provider slack --url https://example.invalid/webhook --message hello --dry-run 2>/dev/null || true)"
printf '%s\n' "$out1" | grep -q '^DRY_RUN provider=slack' || {
  echo "expected dry-run slack output" >&2
  echo "$out1" >&2
  exit 1
}

out2="$(bash "$LM" notify --provider email --to ops@example.com --subject test --message hi --dry-run 2>/dev/null || true)"
printf '%s\n' "$out2" | grep -q '^DRY_RUN provider=email' || {
  echo "expected dry-run email output" >&2
  echo "$out2" >&2
  exit 1
}

set +e
bash "$LM" notify --provider pagerduty --message test --dry-run >/dev/null 2>&1
rc_pd_missing=$?
set -e
[[ "$rc_pd_missing" -eq 2 ]] || {
  echo "expected missing routing-key rc=2 for pagerduty, got rc=$rc_pd_missing" >&2
  exit 1
}

out3="$(bash "$LM" notify --provider pagerduty --routing-key rk_test --severity warning --source linux-maint --message pd-test --dry-run 2>/dev/null || true)"
printf '%s\n' "$out3" | grep -q '^DRY_RUN provider=pagerduty' || {
  echo "expected dry-run pagerduty output" >&2
  echo "$out3" >&2
  exit 1
}
printf '%s\n' "$out3" | grep -q 'events.pagerduty.com/v2/enqueue' || {
  echo "expected pagerduty default URL in dry-run output" >&2
  echo "$out3" >&2
  exit 1
}

echo "notify command ok"
