#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

if [[ "$(id -u)" -eq 0 ]]; then
  echo "SKIP: installed mutating root-gate test requires non-root context"
  exit 0
fi

prefix="$workdir/prefix"
cfg="$workdir/etc_linux_maint"
state="$workdir/state"
mkdir -p "$prefix/bin" "$prefix/sbin" "$prefix/lib" "$prefix/libexec/linux_maint" \
  "$prefix/share/linux_maint" "$cfg" "$state"

cp "$ROOT_DIR/bin/linux-maint" "$prefix/bin/linux-maint"
chmod +x "$prefix/bin/linux-maint"
for support_lib in linux_maint_runtime.sh linux_maint_admin.sh linux_maint_help.sh linux_maint_tui.sh linux_maint_reporting.sh linux_maint_advanced.sh; do
  cp "$ROOT_DIR/lib/$support_lib" "$prefix/lib/$support_lib"
done

printf '#!/usr/bin/env bash\nexit 0\n' > "$prefix/sbin/run_full_health_monitor.sh"
chmod +x "$prefix/sbin/run_full_health_monitor.sh"
printf '# library\n' > "$prefix/lib/linux_maint.sh"
printf '# conf helper\n' > "$prefix/lib/linux_maint_conf.sh"
printf 'project=Linux_Maint_ToolKit\nversion=v0.0.0\ncommit=test\n' > "$prefix/share/linux_maint/BUILD_INFO"

cat > "$prefix/libexec/linux_maint/user_monitor.sh" <<'EOF'
#!/usr/bin/env bash
echo "unexpected write path"
exit 0
EOF
chmod +x "$prefix/libexec/linux_maint/user_monitor.sh"

printf '%s\n' localhost > "$cfg/servers.txt"
: > "$cfg/excluded.txt"
: > "$cfg/services.txt"
printf '%s\n' '{}' > "$state/run_index.jsonl"

lm="$prefix/bin/linux-maint"
common_env=(
  "PREFIX=$prefix"
  "LM_CFG_DIR=$cfg"
  "LM_STATE_DIR=$state"
  "NO_COLOR=1"
)

out_prune="$(env "${common_env[@]}" "$lm" run-index --prune --keep 1 2>&1 || true)"
printf '%s\n' "$out_prune" | grep -qi 'requires root' || {
  echo "installed run-index --prune should require root" >&2
  echo "$out_prune" >&2
  exit 1
}

out_run="$(env "${common_env[@]}" "$lm" run 2>&1 || true)"
printf '%s\n' "$out_run" | grep -qi 'requires root' || {
  echo "installed run should require root" >&2
  echo "$out_run" >&2
  exit 1
}

out_baseline="$(env "${common_env[@]}" "$lm" baseline users 2>&1 || true)"
printf '%s\n' "$out_baseline" | grep -qi 'requires root' || {
  echo "installed baseline update should require root" >&2
  echo "$out_baseline" >&2
  exit 1
}

echo "installed mutating commands root gate ok"
