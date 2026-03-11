#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

prefix="$workdir/prefix"
mkdir -p "$prefix/bin" "$prefix/lib" "$prefix/share/linux_maint/docs"

cp "$ROOT_DIR/bin/linux-maint" "$prefix/bin/linux-maint"
chmod +x "$prefix/bin/linux-maint"
for support_lib in linux_maint_runtime.sh linux_maint_admin.sh linux_maint_help.sh linux_maint_tui.sh linux_maint_reporting.sh linux_maint_advanced.sh linux_maint_history.sh; do
  cp "$ROOT_DIR/lib/$support_lib" "$prefix/lib/$support_lib"
done
cat > "$prefix/share/linux_maint/docs/REASONS.md" <<'EOF'
# Reasons

### Connectivity
- `ssh_unreachable` - SSH unreachable
EOF

out="$(PREFIX="$prefix" REPO_ROOT="$workdir/no-repo" "$prefix/bin/linux-maint" explain monitor health_monitor)"
printf '%s\n' "$out" | grep -q "^see=$prefix/share/linux_maint/docs/REASONS.md$" || {
  echo "installed explain monitor should point at installed reasons doc" >&2
  echo "$out" >&2
  exit 1
}

echo "explain monitor installed doc path ok"
