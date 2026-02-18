#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

workdir="$(mktemp -d)"
trap 'chmod -R u+w "$workdir" 2>/dev/null || true; rm -rf "$workdir"' EXIT

mon_dir="$workdir/monitors"
mkdir -p "$mon_dir"

cat > "$mon_dir/ok_monitor.sh" <<'MON'
#!/usr/bin/env bash
set -euo pipefail
if command -v hostname >/dev/null 2>&1; then
  host="$(hostname -f 2>/dev/null || hostname)"
else
  host="localhost"
fi
echo "monitor=ok_monitor host=$host status=OK msg=ok"
exit 0
MON
chmod +x "$mon_dir/ok_monitor.sh"

log_unwritable="$workdir/logs_unwritable"
state_unwritable="$workdir/state_unwritable"
mkdir -p "$log_unwritable" "$state_unwritable"
chmod 0555 "$log_unwritable" "$state_unwritable"

if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  # When running as root, chmod 0555 may still be writable; use read-only system paths.
  req_log_dir="/proc"
  req_state_dir="/proc"
else
  req_log_dir="$log_unwritable"
  req_state_dir="$state_unwritable"
fi

out="$workdir/wrapper.out"
ts_file="$workdir/ts"
touch "$ts_file"
set +e
LM_MONITORS="ok_monitor.sh" \
  SCRIPTS_DIR="$mon_dir" \
  LOG_DIR="$req_log_dir" \
  SUMMARY_DIR="$req_log_dir" \
  LM_STATE_DIR="$req_state_dir" \
  bash "$ROOT_DIR/run_full_health_monitor.sh" >"$out" 2>&1
rc=$?
set -e

if [[ "$rc" -ne 0 ]]; then
  echo "expected wrapper to complete with rc=0, got rc=$rc" >&2
  tail -n 200 "$out" >&2 || true
  exit 1
fi

logfile=""
for d in /var/tmp/linux_maint/logs /tmp/linux_maint/logs ${TMPDIR}/linux_maint/logs; do
  [ -d "$d" ] || continue
  while IFS= read -r f; do
    logfile="$f"
    break
  done < <(find "$d" -type f -name 'full_health_monitor_*.log' -newer "$ts_file" 2>/dev/null | sort -r)
  [ -n "$logfile" ] && break
done

if [[ -z "$logfile" || ! -f "$logfile" ]]; then
  echo "expected wrapper logfile to exist in fallback dirs" >&2
  tail -n 200 "$out" >&2 || true
  exit 1
fi

if ! grep -a -q 'reason=log_dir_fallback' "$logfile"; then
  echo "missing log dir fallback warning in logfile" >&2
  tail -n 200 "$logfile" >&2 || true
  exit 1
fi

if ! grep -a -q 'reason=summary_dir_fallback' "$logfile"; then
  echo "missing summary dir fallback warning in logfile" >&2
  tail -n 200 "$logfile" >&2 || true
  exit 1
fi

if ! grep -a -q 'reason=state_dir_fallback' "$logfile"; then
  echo "missing state dir fallback warning in logfile" >&2
  tail -n 200 "$logfile" >&2 || true
  exit 1
fi

echo "ok: wrapper fell back to writable log/summary/state dirs"
