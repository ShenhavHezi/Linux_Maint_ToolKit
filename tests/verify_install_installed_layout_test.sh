#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

prefix="$workdir/prefix"
cfg="$workdir/etc_linux_maint"
logs="$workdir/logs"
state="$workdir/state"
lock="$workdir/lock"
unitdir="$workdir/systemd"
shim="$workdir/shim"

mkdir -p "$prefix/bin" "$prefix/sbin" "$prefix/lib" "$prefix/libexec/linux_maint" \
  "$prefix/share/linux_maint" "$cfg" "$logs" "$state" "$lock" "$unitdir" "$shim"

cp "$ROOT_DIR/bin/linux-maint" "$prefix/bin/linux-maint"
chmod +x "$prefix/bin/linux-maint"
for support_lib in linux_maint_runtime.sh linux_maint_admin.sh linux_maint_help.sh linux_maint_tui.sh linux_maint_reporting.sh linux_maint_advanced.sh linux_maint_history.sh; do
  cp "$ROOT_DIR/lib/$support_lib" "$prefix/lib/$support_lib"
done
printf '#!/usr/bin/env bash\nexit 0\n' > "$prefix/sbin/run_full_health_monitor.sh"
chmod +x "$prefix/sbin/run_full_health_monitor.sh"
printf '# library\n' > "$prefix/lib/linux_maint.sh"
printf '# conf helper\n' > "$prefix/lib/linux_maint_conf.sh"
printf 'version=0.0.0\ncommit=test\n' > "$prefix/share/linux_maint/BUILD_INFO"

for helper in summary_diff.py pack_logs.sh seed_known_hosts.sh verify_release.sh upgrade_release.sh; do
  printf '#!/usr/bin/env bash\nexit 0\n' > "$prefix/libexec/linux_maint/$helper"
  chmod +x "$prefix/libexec/linux_maint/$helper"
done

printf '%s\n' localhost > "$cfg/servers.txt"
: > "$cfg/excluded.txt"
: > "$cfg/services.txt"
: > "$unitdir/linux-maint.service"
: > "$unitdir/linux-maint.timer"

cat > "$shim/systemctl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
exit 1
SH
chmod +x "$shim/systemctl"

out="$(PATH="$shim:$PATH" PREFIX="$prefix" LM_CFG_DIR="$cfg" LOG_DIR="$logs" LM_STATE_DIR="$state" LM_LOCKDIR="$lock" LM_SYSTEMD_UNIT_DIRS="$unitdir" "$prefix/bin/linux-maint" verify-install 2>&1)"

printf '%s\n' "$out" | grep -q "^OK: verify-release helper: $prefix/libexec/linux_maint/verify_release.sh$" || {
  echo "verify-install did not validate installed verify-release helper" >&2
  echo "$out" >&2
  exit 1
}

printf '%s\n' "$out" | grep -q "^OK: runtime support lib: $prefix/lib/linux_maint_runtime.sh$" || {
  echo "verify-install did not validate installed runtime support lib" >&2
  echo "$out" >&2
  exit 1
}

printf '%s\n' "$out" | grep -q "^OK: admin support lib: $prefix/lib/linux_maint_admin.sh$" || {
  echo "verify-install did not validate installed admin support lib" >&2
  echo "$out" >&2
  exit 1
}

printf '%s\n' "$out" | grep -q "^OK: tui support lib: $prefix/lib/linux_maint_tui.sh$" || {
  echo "verify-install did not validate installed tui support lib" >&2
  echo "$out" >&2
  exit 1
}

printf '%s\n' "$out" | grep -q "^OK: reporting support lib: $prefix/lib/linux_maint_reporting.sh$" || {
  echo "verify-install did not validate installed reporting support lib" >&2
  echo "$out" >&2
  exit 1
}

printf '%s\n' "$out" | grep -q "^OK: advanced support lib: $prefix/lib/linux_maint_advanced.sh$" || {
  echo "verify-install did not validate installed advanced support lib" >&2
  echo "$out" >&2
  exit 1
}

printf '%s\n' "$out" | grep -q "^OK: history support lib: $prefix/lib/linux_maint_history.sh$" || {
  echo "verify-install did not validate installed history support lib" >&2
  echo "$out" >&2
  exit 1
}

printf '%s\n' "$out" | grep -q "^OK: upgrade helper: $prefix/libexec/linux_maint/upgrade_release.sh$" || {
  echo "verify-install did not validate installed upgrade helper" >&2
  echo "$out" >&2
  exit 1
}

printf '%s\n' "$out" | grep -q "^OK: unit file: $unitdir/linux-maint.service$" || {
  echo "verify-install did not detect service unit in configured systemd dirs" >&2
  echo "$out" >&2
  exit 1
}

printf '%s\n' "$out" | grep -q "^OK: unit file: $unitdir/linux-maint.timer$" || {
  echo "verify-install did not detect timer unit in configured systemd dirs" >&2
  echo "$out" >&2
  exit 1
}

printf '%s\n' "$out" | grep -q '^verify-install ok$' || {
  echo "verify-install installed layout did not complete successfully" >&2
  echo "$out" >&2
  exit 1
}

echo "verify-install installed layout ok"
