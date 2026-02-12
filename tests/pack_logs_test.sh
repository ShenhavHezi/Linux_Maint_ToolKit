#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

# Create a minimal fake log dir with the expected latest files
logdir="$workdir/logs"
mkdir -p "$logdir"

echo "monitor=fake host=localhost status=OK node=test" > "$logdir/full_health_monitor_summary_latest.log"
echo '{"rows":[]}' > "$logdir/full_health_monitor_summary_latest.json"
echo "log" > "$logdir/full_health_monitor_latest.log"
echo "overall=OK" > "$logdir/last_status_full"

# Create a minimal fake config dir
cfgdir="$workdir/etc_linux_maint"
mkdir -p "$cfgdir"
echo "localhost" > "$cfgdir/servers.txt"

after="$("$ROOT_DIR/tools/pack_logs.sh" OUTDIR="$workdir" LOG_DIR="$logdir" CFG_DIR="$cfgdir" REPO_ROOT="$ROOT_DIR")"

# tools/pack_logs.sh prints the tarball path
bundle_path="$after"
[[ -f "$bundle_path" ]]

tar -tzf "$bundle_path" | grep -q '^\./logs/full_health_monitor_summary_latest\.log$'
tar -tzf "$bundle_path" | grep -q '^\./config/servers\.txt$'

echo "ok: pack-logs"
