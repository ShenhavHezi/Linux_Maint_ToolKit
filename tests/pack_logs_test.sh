#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

logdir="$workdir/logs"
mkdir -p "$logdir"

echo "monitor=fake host=localhost status=OK node=test" > "$logdir/full_health_monitor_summary_latest.log"
echo '{"rows":[]}' > "$logdir/full_health_monitor_summary_latest.json"
echo "log" > "$logdir/full_health_monitor_latest.log"
echo "overall=OK" > "$logdir/last_status_full"

cfgdir="$workdir/etc_linux_maint"
mkdir -p "$cfgdir"
cat > "$cfgdir/servers.txt" <<'CFG'
localhost
password=hunter2
api_key = "ABCD-1234"
secret='topsecret'
Authorization: Bearer very-sensitive-token
LM_NOTIFY_TOKEN=abc123
CFG

bundle_path="$(OUTDIR="$workdir" LOG_DIR="$logdir" CFG_DIR="$cfgdir" REPO_ROOT="$ROOT_DIR" "$ROOT_DIR/tools/pack_logs.sh")"
[[ -f "$bundle_path" ]]

tar -tzf "$bundle_path" | grep -q '^\./logs/full_health_monitor_summary_latest\.log$'
tar -tzf "$bundle_path" | grep -q '^\./config/servers\.txt$'

extracted_cfg="$workdir/extracted_servers.txt"
tar -xOf "$bundle_path" ./config/servers.txt > "$extracted_cfg"

# Sensitive values must be redacted
grep -qi 'password=REDACTED' "$extracted_cfg"
grep -qi 'api_key="REDACTED"' "$extracted_cfg"
grep -qi "secret='REDACTED'" "$extracted_cfg"
grep -qi 'Authorization: REDACTED' "$extracted_cfg"
grep -qi 'token=REDACTED' "$extracted_cfg"

# Original secret values must not appear
assert_not_contains() {
  local needle="$1" file="$2"
  if grep -q -- "$needle" "$file"; then
    echo "unexpected secret found in redacted file: $needle" >&2
    exit 1
  fi
}

assert_not_contains 'hunter2' "$extracted_cfg"
assert_not_contains 'ABCD-1234' "$extracted_cfg"
assert_not_contains 'topsecret' "$extracted_cfg"
assert_not_contains 'very-sensitive-token' "$extracted_cfg"
assert_not_contains 'abc123' "$extracted_cfg"

# Non-secret useful line preserved
grep -q '^localhost$' "$extracted_cfg"

echo "ok: pack-logs"
