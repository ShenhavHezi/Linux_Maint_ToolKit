#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

log_dir="$workdir/logs"
summary_dir="$workdir/summary"
state_dir="$workdir/state"
mkdir -p "$log_dir" "$summary_dir" "$state_dir"

export LOG_DIR="$log_dir"
export SUMMARY_DIR="$summary_dir"
export LM_STATE_DIR="$state_dir"
export LM_CFG_DIR="$workdir/cfg"
mkdir -p "$LM_CFG_DIR"

export LM_LOCAL_ONLY=true
export LM_TEST_MODE=1
export LM_PROGRESS=0

# Run only a single monitor
bash "$LM" run --only health_monitor >/dev/null 2>&1 || true

summary_latest="$summary_dir/full_health_monitor_summary_latest.log"
if [ ! -s "$summary_latest" ]; then
  echo "missing summary file: $summary_latest" >&2
  exit 1
fi

mons=$(awk -F'[ =]' '/^monitor=/{print $2}' "$summary_latest" | sort -u)
allowed="health_monitor wrapper"
for m in $mons; do
  case " $allowed " in
    *" $m "*) ;;
    *) echo "unexpected monitor in summary: $m" >&2; exit 1;;
  esac
done

if ! printf '%s\n' "$mons" | grep -q '^health_monitor$'; then
  echo "health_monitor missing from summary" >&2
  exit 1
fi

echo "run --only integration ok"
