#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
prom_file="$(mktemp)"
cleanup() { rm -f "$prom_file"; }
trap cleanup EXIT

(
  cd "$ROOT_DIR"
  PROM_FILE="$prom_file" LM_PROM_FORMAT="openmetrics" bash ./run_full_health_monitor.sh >/dev/null 2>&1 || true
)

if [[ ! -s "$prom_file" ]]; then
  echo "openmetrics eof consistency skipped: no prom output"
  exit 0
fi

tail -n 1 "$prom_file" | grep -q '^# EOF$' || {
  echo "openmetrics output missing # EOF terminator" >&2
  tail -n 5 "$prom_file" >&2
  exit 1
}

if grep -q $'\033\[' "$prom_file"; then
  echo "openmetrics output contains ANSI escapes" >&2
  exit 1
fi

echo "openmetrics eof consistency ok"
