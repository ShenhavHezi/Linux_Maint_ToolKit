#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

logdir="$workdir/logs"
mkdir -p "$logdir"

echo "monitor=fake host=localhost status=OK node=test" > "$logdir/full_health_monitor_summary_latest.log"
echo '{"rows":[]}' > "$logdir/full_health_monitor_summary_latest.json"
echo "token=rawsecret" > "$logdir/full_health_monitor_latest.log"
echo "overall=OK" > "$logdir/last_status_full"

cfgdir="$workdir/etc_linux_maint"
mkdir -p "$cfgdir"
statedir="$workdir/state"
mkdir -p "$statedir"
cat > "$cfgdir/servers.txt" <<'CFG'
localhost
password=hunter2
api_key = "ABCD-1234"
secret='topsecret'
Authorization: Bearer very-sensitive-token
LM_NOTIFY_TOKEN=abc123
session_id = "sess-42"
refresh_token='refresh-secret'
id_token: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.abcdefghijklmnop.qrstuvwxyzABCD"
x-auth-token: token-raw-value
notes: sessionization is normal text
CFG

bundle_path="$(LM_REDACT_LOGS=1 LM_PACK_LOGS_HASH=1 OUTDIR="$workdir" LOG_DIR="$logdir" CFG_DIR="$cfgdir" STATE_DIR="$statedir" REPO_ROOT="$ROOT_DIR" "$ROOT_DIR/tools/pack_logs.sh")"
[[ -f "$bundle_path" ]]

tar_list="$workdir/tar.list"
tar -tzf "$bundle_path" > "$tar_list"
grep -q '^\./logs/full_health_monitor_summary_latest\.log$' "$tar_list"
grep -q '^\./config/servers\.txt$' "$tar_list"
grep -q '^\./meta/bundle_meta\.txt$' "$tar_list"
grep -q '^\./meta/bundle_manifest\.txt$' "$tar_list"
grep -q '^\./meta/redaction_report\.txt$' "$tar_list"
grep -q '^\./meta/support_handoff\.txt$' "$tar_list"
grep -q '^\./meta/bundle_hashes\.txt$' "$tar_list"

extracted_cfg="$workdir/extracted_servers.txt"
tar -xOf "$bundle_path" ./config/servers.txt > "$extracted_cfg"

extracted_log="$workdir/extracted_log.txt"
tar -xOf "$bundle_path" ./logs/full_health_monitor_latest.log > "$extracted_log"

# Metadata should report redaction enabled
meta_file="$workdir/bundle_meta.txt"
tar -xOf "$bundle_path" ./meta/bundle_meta.txt > "$meta_file"
grep -q '^redaction=enabled$' "$meta_file"
grep -q '^hashes=enabled$' "$meta_file"

manifest_file="$workdir/bundle_manifest.txt"
tar -xOf "$bundle_path" ./meta/bundle_manifest.txt > "$manifest_file"
grep -q '^copied_logs=4$' "$manifest_file"
grep -q '^copied_config=1$' "$manifest_file"
grep -q '^redaction_logs=enabled$' "$manifest_file"
grep -q '^redacted_files=4$' "$manifest_file"
grep -q '^changed_by_redaction=2$' "$manifest_file"
grep -q '^integrity_manifest=enabled$' "$manifest_file"
grep -q '^hash_manifest=enabled$' "$manifest_file"

redaction_report="$workdir/redaction_report.txt"
tar -xOf "$bundle_path" ./meta/redaction_report.txt > "$redaction_report"
grep -q '^log_redaction=enabled$' "$redaction_report"
grep -q '^section=config path=config/servers\.txt .* policy=always changed=yes$' "$redaction_report"
grep -q '^section=logs path=logs/full_health_monitor_latest\.log .* policy=optional changed=yes$' "$redaction_report"

handoff_file="$workdir/support_handoff.txt"
tar -xOf "$bundle_path" ./meta/support_handoff.txt > "$handoff_file"
grep -q '^linux-maint support handoff$' "$handoff_file"
grep -q '^   meta/bundle_manifest\.txt$' "$handoff_file"
grep -q '^   meta/redaction_report\.txt$' "$handoff_file"

hash_file="$workdir/bundle_hashes.txt"
tar -xOf "$bundle_path" ./meta/bundle_hashes.txt > "$hash_file"
grep -q '  \./config/servers\.txt$' "$hash_file"
grep -q '  \./logs/full_health_monitor_latest\.log$' "$hash_file"

# Sensitive values must be redacted
grep -qi 'password=REDACTED' "$extracted_cfg"
grep -qi 'api_key="REDACTED"' "$extracted_cfg"
grep -qi "secret='REDACTED'" "$extracted_cfg"
grep -qi 'Authorization: REDACTED' "$extracted_cfg"
grep -qi 'token=REDACTED' "$extracted_cfg"

grep -qi 'session_id="REDACTED"' "$extracted_cfg"
grep -qi "refresh_token='REDACTED'" "$extracted_cfg"
grep -qi 'id_token: "REDACTED"' "$extracted_cfg"
grep -qi '^x-auth-token: REDACTED$' "$extracted_cfg"

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
assert_not_contains 'sess-42' "$extracted_cfg"
assert_not_contains 'refresh-secret' "$extracted_cfg"
assert_not_contains 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.abcdefghijklmnop.qrstuvwxyzABCD' "$extracted_cfg"
assert_not_contains 'token-raw-value' "$extracted_cfg"

# Non-secret useful line preserved
grep -q '^localhost$' "$extracted_cfg"
grep -q '^notes: sessionization is normal text$' "$extracted_cfg"

# Logs should be redacted when LM_REDACT_LOGS=1
grep -qi 'token=REDACTED' "$extracted_log"
assert_not_contains 'rawsecret' "$extracted_log"

echo "ok: pack-logs"
