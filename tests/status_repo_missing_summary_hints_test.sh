#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

logdir="$workdir/logs"
mkdir -p "$logdir"

out="$(NO_COLOR=1 LOG_DIR="$logdir" bash "$LM" status 2>&1 || true)"

printf '%s\n' "$out" | grep -q "Permission issue writing to $logdir" || {
  echo "status missing-summary output did not use repo log dir" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q -- '- Run: linux-maint run' || {
  echo "status missing-summary output did not use repo run hint" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q -- '- Check logs: linux-maint logs 200' || {
  echo "status missing-summary output did not use repo logs hint" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q -- '- Diagnose: linux-maint doctor' || {
  echo "status missing-summary output did not use repo doctor hint" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q '/var/log/health' && {
  echo "status missing-summary output leaked installed log path" >&2
  echo "$out" >&2
  exit 1
}

echo "status repo missing summary hints ok"
