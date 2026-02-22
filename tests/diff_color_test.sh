#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"
LOG_DIR="$ROOT_DIR/.logs"
SUMMARY_FILE="$LOG_DIR/full_health_monitor_summary_latest.log"

mkdir -p "$LOG_DIR"

backup_summary=""
if [[ -f "$SUMMARY_FILE" ]]; then
  backup_summary="$SUMMARY_FILE.bak.$$"
  cp -f "$SUMMARY_FILE" "$backup_summary"
fi

workdir="$(mktemp -d -p "${TMPDIR:-/tmp}")"
trap 'rm -rf "$workdir"' EXIT

prev_file="$workdir/last_summary_monitor_lines.log"

cat > "$prev_file" <<'PREV'
monitor=svc host=a status=OK
monitor=svc host=b status=WARN reason=service_failed
PREV

cat > "$SUMMARY_FILE" <<'CUR'
monitor=svc host=a status=CRIT reason=service_failed
monitor=svc host=b status=OK
CUR

out_color="$(LM_STATE_DIR="$workdir" NO_COLOR= LM_FORCE_COLOR=1 bash "$LM" diff 2>/dev/null || true)"
printf '%s\n' "$out_color" | grep -q $'\033' || {
  echo "diff output missing ANSI when forced" >&2
  echo "$out_color" >&2
  exit 1
}

out_nocolor="$(LM_STATE_DIR="$workdir" NO_COLOR=1 LM_FORCE_COLOR=1 bash "$LM" diff 2>/dev/null || true)"
printf '%s\n' "$out_nocolor" | grep -q $'\033' && {
  echo "diff output should not contain ANSI when NO_COLOR=1" >&2
  echo "$out_nocolor" >&2
  exit 1
}

if [[ -n "$backup_summary" && -f "$backup_summary" ]]; then
  mv -f "$backup_summary" "$SUMMARY_FILE"
else
  rm -f "$SUMMARY_FILE"
fi

echo "diff color ok"
