#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

repo_logs="$ROOT_DIR/.logs"
workdir="$(mktemp -d)"
backup="$workdir/logs_backup"

cleanup() {
  rm -rf "$repo_logs" 2>/dev/null || true
  if [[ -d "$backup" ]]; then
    mv "$backup" "$repo_logs"
  fi
  rm -rf "$workdir"
}
trap cleanup EXIT

if [[ -d "$repo_logs" ]]; then
  mv "$repo_logs" "$backup"
fi
mkdir -p "$repo_logs"

cat > "$repo_logs/full_health_monitor_summary_latest.log" <<'S'
monitor=custom_monitor host=localhost status=WARN reason=unknown token=ghp_ABCDEFGHIJKLMNOPQRSTUVWX
S

out="$(LM_REDACT_JSON=1 bash "$LM" export --json)"

if echo "$out" | grep -q 'ghp_ABCDEFGHIJKLMNOPQRSTUVWX'; then
  echo "expected JSON redaction to mask token" >&2
  echo "$out" >&2
  exit 1
fi

echo "json redaction ok"
