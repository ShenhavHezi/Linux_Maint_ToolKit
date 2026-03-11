#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

prefix="$workdir/prefix"
mkdir -p "$prefix/bin" "$prefix/lib" "$prefix/share/linux_maint"

cp "$ROOT_DIR/bin/linux-maint" "$prefix/bin/linux-maint"
chmod +x "$prefix/bin/linux-maint"
for support_lib in linux_maint_runtime.sh linux_maint_admin.sh linux_maint_help.sh linux_maint_tui.sh linux_maint_reporting.sh linux_maint_advanced.sh linux_maint_history.sh; do
  cp "$ROOT_DIR/lib/$support_lib" "$prefix/lib/$support_lib"
done
cat > "$prefix/share/linux_maint/BUILD_INFO" <<'EOF'
project=Linux_Maint_ToolKit
version=v9.9.9
commit=testdeadbeef
branch=main
built_at_utc=2026-03-10T00:00:00Z
EOF

out="$("$prefix/bin/linux-maint" version)"
printf '%s\n' "$out" | grep -q '^version=v9.9.9$' || {
  echo "installed linux-maint did not autodetect prefix for BUILD_INFO" >&2
  echo "$out" >&2
  exit 1
}

echo "installed version autodetect ok"
