#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

prefix="$workdir/prefix"
cfg="$workdir/etc_linux_maint"
logs="$workdir/logs"
state="$workdir/state"
lock="$workdir/lock"
mkdir -p "$prefix/bin" "$prefix/sbin" "$prefix/lib" "$prefix/libexec/linux_maint" \
  "$prefix/share/linux_maint" "$cfg" "$logs" "$state" "$lock"

cp "$ROOT_DIR/bin/linux-maint" "$prefix/bin/linux-maint"
chmod +x "$prefix/bin/linux-maint"
for support_lib in linux_maint_runtime.sh linux_maint_admin.sh linux_maint_help.sh linux_maint_tui.sh linux_maint_reporting.sh linux_maint_advanced.sh linux_maint_history.sh; do
  cp "$ROOT_DIR/lib/$support_lib" "$prefix/lib/$support_lib"
done

printf '#!/usr/bin/env bash\nexit 0\n' > "$prefix/sbin/run_full_health_monitor.sh"
chmod +x "$prefix/sbin/run_full_health_monitor.sh"
printf '# library\n' > "$prefix/lib/linux_maint.sh"
printf '# conf helper\n' > "$prefix/lib/linux_maint_conf.sh"
printf 'project=Linux_Maint_ToolKit\nversion=v0.0.0\ncommit=test\n' > "$prefix/share/linux_maint/BUILD_INFO"

cat > "$prefix/libexec/linux_maint/config_validate.sh" <<'EOF'
#!/usr/bin/env bash
echo "config-validate stub"
exit 0
EOF
cat > "$prefix/libexec/linux_maint/preflight_check.sh" <<'EOF'
#!/usr/bin/env bash
echo "preflight stub"
exit 0
EOF
cat > "$prefix/libexec/linux_maint/user_monitor.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
target="${LM_BASELINE_TARGET:-users}"
base="${LM_CFG_DIR:-/etc/linux_maint}/baselines/${target}/localhost.baseline"
mkdir -p "$(dirname "$base")"
printf '%s\n' sample > "$base"
if [[ "${LM_BASELINE_SHOW:-0}" == "1" ]]; then
  echo "baseline snapshot"
  cat "$base"
elif [[ "${LM_BASELINE_DIFF:-0}" == "1" ]]; then
  echo "baseline diff"
else
  echo "baseline update"
fi
EOF
chmod +x "$prefix/libexec/linux_maint/config_validate.sh" \
  "$prefix/libexec/linux_maint/preflight_check.sh" \
  "$prefix/libexec/linux_maint/user_monitor.sh"

printf '%s\n' localhost > "$cfg/servers.txt"
: > "$cfg/excluded.txt"
: > "$cfg/services.txt"
cat > "$cfg/linux-maint.conf" <<'EOF'
LM_NOTIFY=0
EOF
cat > "$logs/full_health_monitor_latest.log" <<'EOF'
repo log line 1
repo log line 2
EOF

cat > "$state/run_index.jsonl" <<'EOF'
{"run_id":"r1","timestamp":"2026-03-11T00:00:00Z","overall":"OK","exit_code":0,"hosts":{"crit":0,"warn":0,"unknown":0,"skipped":0,"ok":1}}
EOF

lm="$prefix/bin/linux-maint"
common_env=(
  "PREFIX=$prefix"
  "LM_CFG_DIR=$cfg"
  "LOG_DIR=$logs"
  "LM_STATE_DIR=$state"
  "LM_LOCKDIR=$lock"
  "NO_COLOR=1"
)

config_out="$(env "${common_env[@]}" "$lm" config 2>&1)"
printf '%s\n' "$config_out" | grep -q '^=== linux-maint config' || {
  echo "installed config should run without root" >&2
  echo "$config_out" >&2
  exit 1
}

check_out="$(env "${common_env[@]}" "$lm" check 2>&1)"
printf '%s\n' "$check_out" | grep -q '^=== config_validate ===' || {
  echo "installed check should run without root" >&2
  echo "$check_out" >&2
  exit 1
}

doctor_out="$(env "${common_env[@]}" "$lm" doctor --compact 2>&1)"
printf '%s\n' "$doctor_out" | grep -q '^=== linux-maint doctor ===' || {
  echo "installed doctor should run without root" >&2
  echo "$doctor_out" >&2
  exit 1
}

logs_out="$(env "${common_env[@]}" "$lm" logs 1 2>&1)"
printf '%s\n' "$logs_out" | grep -q '^repo log line 2$' || {
  echo "installed logs should run without root" >&2
  echo "$logs_out" >&2
  exit 1
}

preflight_out="$(env "${common_env[@]}" "$lm" preflight 2>&1)"
printf '%s\n' "$preflight_out" | grep -q '^preflight stub$' || {
  echo "installed preflight should run without root" >&2
  echo "$preflight_out" >&2
  exit 1
}

validate_out="$(env "${common_env[@]}" "$lm" validate 2>&1)"
printf '%s\n' "$validate_out" | grep -q '^config-validate stub$' || {
  echo "installed validate should run without root" >&2
  echo "$validate_out" >&2
  exit 1
}

history_out="$(env "${common_env[@]}" "$lm" history --compact 2>&1)"
printf '%s\n' "$history_out" | grep -q '^last_run=' || {
  echo "installed history should run without root" >&2
  echo "$history_out" >&2
  exit 1
}

run_index_out="$(env "${common_env[@]}" "$lm" run-index --stats 2>&1)"
printf '%s\n' "$run_index_out" | grep -q '^run_index path=' || {
  echo "installed run-index --stats should run without root" >&2
  echo "$run_index_out" >&2
  exit 1
}

env "${common_env[@]}" "$lm" baseline users >/dev/null 2>&1 || true
baseline_show_out="$(env "${common_env[@]}" "$lm" baseline users --show 2>&1)"
printf '%s\n' "$baseline_show_out" | grep -q 'baseline snapshot' || {
  echo "installed baseline --show should run without root" >&2
  echo "$baseline_show_out" >&2
  exit 1
}

baseline_diff_out="$(env "${common_env[@]}" "$lm" baseline users --diff 2>&1)"
printf '%s\n' "$baseline_diff_out" | grep -q 'baseline diff' || {
  echo "installed baseline --diff should run without root" >&2
  echo "$baseline_diff_out" >&2
  exit 1
}

echo "installed read-only commands ok"
