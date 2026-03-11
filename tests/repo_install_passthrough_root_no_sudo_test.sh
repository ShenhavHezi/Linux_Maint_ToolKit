#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

repo="$workdir/repo"
shim="$workdir/shim"
mkdir -p "$repo/bin" "$repo/lib" "$repo/monitors" "$shim"

cp "$ROOT_DIR/bin/linux-maint" "$repo/bin/linux-maint"
chmod +x "$repo/bin/linux-maint"
cp "$ROOT_DIR/lib/linux_maint.sh" "$repo/lib/linux_maint.sh"
cp "$ROOT_DIR/lib/linux_maint_runtime.sh" "$repo/lib/linux_maint_runtime.sh"
cp "$ROOT_DIR/lib/linux_maint_admin.sh" "$repo/lib/linux_maint_admin.sh"
cp "$ROOT_DIR/lib/linux_maint_tui.sh" "$repo/lib/linux_maint_tui.sh"

cat > "$repo/install.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" > "${CAPTURE_FILE:?}"
SH
chmod +x "$repo/install.sh"

cat > "$shim/id" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "-u" ]]; then
  printf '0\n'
  exit 0
fi
exec /usr/bin/id "$@"
SH
chmod +x "$shim/id"

PATH="$shim:/usr/bin:/bin" CAPTURE_FILE="$workdir/install.args" \
  bash "$repo/bin/linux-maint" install --prefix /opt/linux-maint-test

grep -qx -- '--prefix /opt/linux-maint-test' "$workdir/install.args" || {
  echo "repo-mode install passthrough did not execute install.sh directly as root" >&2
  cat "$workdir/install.args" >&2 || true
  exit 1
}

PATH="$shim:/usr/bin:/bin" CAPTURE_FILE="$workdir/uninstall.args" \
  bash "$repo/bin/linux-maint" uninstall --purge

grep -qx -- '--uninstall --purge' "$workdir/uninstall.args" || {
  echo "repo-mode uninstall passthrough did not execute install.sh directly as root" >&2
  cat "$workdir/uninstall.args" >&2 || true
  exit 1
}

echo "repo install passthrough root no sudo ok"
