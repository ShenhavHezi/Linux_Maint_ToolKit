#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

prefix="$workdir/prefix"
mkdir -p "$prefix/bin" "$prefix/lib" "$prefix/libexec/linux_maint"

cp "$ROOT_DIR/bin/linux-maint" "$prefix/bin/linux-maint"
chmod +x "$prefix/bin/linux-maint"
for support_lib in linux_maint_runtime.sh linux_maint_admin.sh linux_maint_help.sh linux_maint_tui.sh linux_maint_reporting.sh linux_maint_advanced.sh linux_maint_history.sh; do
  cp "$ROOT_DIR/lib/$support_lib" "$prefix/lib/$support_lib"
done

cat > "$prefix/libexec/linux_maint/verify_release.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'installed verify helper ok: %s\n' "$*"
SH
chmod +x "$prefix/libexec/linux_maint/verify_release.sh"

out="$("$prefix/bin/linux-maint" verify-release artifact.tgz --sums SHA256SUMS)"

printf '%s\n' "$out" | grep -q '^installed verify helper ok: artifact.tgz --sums SHA256SUMS$' || {
  echo "installed verify-release did not dispatch to installed helper" >&2
  echo "$out" >&2
  exit 1
}

echo "installed verify-release dispatch ok"
