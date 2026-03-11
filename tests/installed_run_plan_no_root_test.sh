#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

prefix="$workdir/prefix"
cfg="$workdir/etc_linux_maint"
state="$workdir/state"
logs="$workdir/logs"
mkdir -p "$prefix/bin" "$prefix/sbin" "$prefix/lib" "$prefix/libexec/linux_maint" \
  "$prefix/share/linux_maint" "$cfg/hosts.d" "$state" "$logs"

cp "$ROOT_DIR/bin/linux-maint" "$prefix/bin/linux-maint"
chmod +x "$prefix/bin/linux-maint"
for support_lib in linux_maint_runtime.sh linux_maint_admin.sh linux_maint_help.sh linux_maint_tui.sh linux_maint_reporting.sh linux_maint_advanced.sh; do
  cp "$ROOT_DIR/lib/$support_lib" "$prefix/lib/$support_lib"
done

printf '#!/usr/bin/env bash\nexit 0\n' > "$prefix/sbin/run_full_health_monitor.sh"
chmod +x "$prefix/sbin/run_full_health_monitor.sh"
cp "$ROOT_DIR/lib/linux_maint.sh" "$prefix/lib/linux_maint.sh"
printf '#!/usr/bin/env bash\necho \"stub monitor\"\n' > "$prefix/libexec/linux_maint/health_monitor.sh"
chmod +x "$prefix/libexec/linux_maint/health_monitor.sh"
printf '# conf helper\n' > "$prefix/lib/linux_maint_conf.sh"
printf 'project=Linux_Maint_ToolKit\nversion=v0.0.0\ncommit=test\n' > "$prefix/share/linux_maint/BUILD_INFO"

printf '%s\n' web-1 web-2 > "$cfg/servers.txt"
: > "$cfg/excluded.txt"
: > "$cfg/services.txt"

lm="$prefix/bin/linux-maint"
out="$(PREFIX="$prefix" LM_CFG_DIR="$cfg" LM_STATE_DIR="$state" LOG_DIR="$logs" NO_COLOR=1 "$lm" run --plan --json --local-only 2>&1)"
printf '%s' "$out" | python3 -c 'import json,sys; obj=json.load(sys.stdin); assert obj["mode"]=="installed"; assert obj["local_only"] is True; assert obj["hosts"]==["web-1","web-2"]; assert isinstance(obj["monitors"], list) and obj["monitors"]'

echo "installed run plan no root ok"
