#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

set +e
bash "$LM" ticket --provider jira --title t --body b --dry-run >/dev/null 2>&1
rc_missing_url=$?
set -e
[[ "$rc_missing_url" -eq 2 ]] || {
  echo "expected missing URL rc=2, got rc=$rc_missing_url" >&2
  exit 1
}

out1="$(bash "$LM" ticket --provider jira --url https://example.invalid/jira --title "Title" --body "Body" --project OPS --issue-type Task --dry-run 2>/dev/null || true)"
printf '%s\n' "$out1" | grep -q '^DRY_RUN provider=jira' || {
  echo "expected jira dry-run output" >&2
  echo "$out1" >&2
  exit 1
}
printf '%s\n' "$out1" | grep -q '"issuetype"' || {
  echo "expected jira payload fields in dry-run output" >&2
  echo "$out1" >&2
  exit 1
}

out2="$(bash "$LM" ticket --provider servicenow --url https://example.invalid/snow --title "Title" --body "Body" --dry-run 2>/dev/null || true)"
printf '%s\n' "$out2" | grep -q '^DRY_RUN provider=servicenow' || {
  echo "expected servicenow dry-run output" >&2
  echo "$out2" >&2
  exit 1
}
printf '%s\n' "$out2" | grep -q '"short_description"' || {
  echo "expected servicenow payload fields in dry-run output" >&2
  echo "$out2" >&2
  exit 1
}

json_out="$(bash "$LM" ticket --provider jira --url https://example.invalid/jira --title "Title" --body "Body" --dry-run --json 2>/dev/null || true)"
JSON_OUT="$json_out" python3 - <<'PY'
import json, os
o = json.loads(os.environ["JSON_OUT"])
assert o["ticket_contract_version"] == 1
assert o["provider"] == "jira"
assert o["dry_run"] is True
assert o["submitted"] is False
assert isinstance(o.get("payload"), dict)
PY

echo "ticket command ok"
