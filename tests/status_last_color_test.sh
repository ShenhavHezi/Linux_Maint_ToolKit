#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"
LOG_DIR="$ROOT_DIR/.logs"
mkdir -p "$LOG_DIR"

summary_file="$LOG_DIR/full_health_monitor_summary_2099-12-31_235959.log"
trap 'rm -f "$summary_file"' EXIT

cat > "$summary_file" <<'S'
monitor=health_monitor host=localhost status=OK reason=ok
monitor=disk_monitor host=localhost status=WARN reason=high_load
S

# Ensure this summary is the newest by mtime so status --last picks it.
if touch -d '2099-12-31 23:59:59' "$summary_file" 2>/dev/null; then
  :
else
  touch "$summary_file"
fi

color_out="$(LM_FORCE_COLOR=1 NO_COLOR='' bash "$LM" status --last 1 2>/dev/null || true)"
printf '%s\n' "$color_out" | grep -q $'\033' || {
  echo "status --last should include ANSI when color forced" >&2
  echo "$color_out" >&2
  exit 1
}

no_color_out="$(NO_COLOR=1 LM_FORCE_COLOR=1 bash "$LM" status --last 1 2>/dev/null || true)"
printf '%s\n' "$no_color_out" | grep -q $'\033' && {
  echo "status --last should not include ANSI when NO_COLOR=1" >&2
  echo "$no_color_out" >&2
  exit 1
}

echo "status --last color ok"
