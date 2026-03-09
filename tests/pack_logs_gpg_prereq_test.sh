#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

logdir="$workdir/logs"
cfgdir="$workdir/etc_linux_maint"
statedir="$workdir/state"
outdir="$workdir/out"
mkdir -p "$logdir" "$cfgdir" "$statedir" "$outdir"
echo "dummy" > "$logdir/full_health_monitor_latest.log"

set +e
OUTDIR="$outdir" LOG_DIR="$logdir" CFG_DIR="$cfgdir" STATE_DIR="$statedir" LM_PACK_LOGS_GPG=1 "$ROOT_DIR/tools/pack_logs.sh" >/tmp/pack_logs_gpg_prereq.out 2>/tmp/pack_logs_gpg_prereq.err
rc=$?
set -e

[[ "$rc" -eq 2 ]] || {
  echo "expected pack_logs.sh rc=2 when --gpg recipient is missing, got rc=$rc" >&2
  exit 1
}

grep -q 'ERROR: --gpg requires --gpg-recipient' /tmp/pack_logs_gpg_prereq.err || {
  echo "missing pack-logs gpg recipient error" >&2
  cat /tmp/pack_logs_gpg_prereq.err >&2
  exit 1
}

if find "$outdir" -maxdepth 1 -type f | grep -q .; then
  echo "pack-logs should not leave plaintext bundle behind when gpg prerequisites fail" >&2
  find "$outdir" -maxdepth 1 -type f -print >&2
  exit 1
fi

rm -f /tmp/pack_logs_gpg_prereq.out /tmp/pack_logs_gpg_prereq.err
echo "pack-logs gpg prereq ok"
