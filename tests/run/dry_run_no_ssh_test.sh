#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

# Create a fake ssh that fails if called
tmp_base="${TMPDIR:-/tmp}"
workdir="$(mktemp -d -p "$tmp_base")"
mkdir -p "$workdir"
trap 'rm -rf "$workdir"' EXIT

cat > "$workdir/ssh" <<'SH'
#!/usr/bin/env bash
echo "ERROR: ssh was invoked during --dry-run" >&2
exit 99
SH
chmod +x "$workdir/ssh"

# Prepend to PATH
export PATH="$workdir:$PATH"

# Ensure we use repo libs
export LINUX_MAINT_LIB="$ROOT_DIR/lib/linux_maint.sh"
export LM_EMAIL_ENABLED=false

# Run dry-run planning. It should not invoke ssh.
# Use explicit hosts so it doesn't depend on /etc/linux_maint.
out=$(bash "$LM" run --hosts host-a,host-b --dry-run 2>&1 || true)

# If ssh was invoked, our fake ssh exits 99 and should appear in output
if echo "$out" | grep -q 'ERROR: ssh was invoked during --dry-run'; then
  echo "$out" >&2
  exit 1
fi

# Some sanity: dry-run should print something
[ -n "$out" ]

echo "dry-run no-ssh ok"
