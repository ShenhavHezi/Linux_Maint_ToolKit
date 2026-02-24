#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$ROOT_DIR/lib/linux_maint.sh"

tmp_root="$(mktemp -d -p "$TMPDIR" lm_remote_dep.XXXXXX)"
trap 'rm -rf "$tmp_root"' EXIT

state_dir="$tmp_root/state"
bin_dir="$tmp_root/bin"
args_file="$tmp_root/ssh_args"
mkdir -p "$bin_dir"

cat > "$bin_dir/ssh" <<'SH'
#!/usr/bin/env bash
echo "$@" > "$LM_SSH_TEST_ARGS_FILE"
exit 1
SH
chmod +x "$bin_dir/ssh"

out="$(PATH="$bin_dir:$PATH" \
  LM_STATE_DIR="$state_dir" \
  LM_SSH_TEST_ARGS_FILE="$args_file" \
  bash -c '. "$0"; lm_require_cmd "dep_check" "remote-host" "bash" || true' "$LIB")"

[ -f "$args_file" ] || { echo "expected ssh to be invoked for remote dependency check" >&2; exit 1; }

printf '%s\n' "$out" | grep -q 'monitor=dep_check' || { echo "missing monitor tag" >&2; echo "$out" >&2; exit 1; }
printf '%s\n' "$out" | grep -q 'host=remote-host' || { echo "missing host tag" >&2; echo "$out" >&2; exit 1; }
printf '%s\n' "$out" | grep -q 'reason=missing_dependency' || { echo "missing reason" >&2; echo "$out" >&2; exit 1; }
printf '%s\n' "$out" | grep -q 'dep=bash' || { echo "missing dep" >&2; echo "$out" >&2; exit 1; }

echo "remote dependency check ok"
