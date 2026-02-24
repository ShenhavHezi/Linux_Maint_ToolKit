#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$ROOT_DIR/lib/linux_maint.sh"

tmp_root="$(mktemp -d -p "$TMPDIR" lm_kh_test.XXXXXX)"
trap 'rm -rf "$tmp_root"' EXIT

state_dir="$tmp_root/state"
bin_dir="$tmp_root/bin"
args_file="$tmp_root/ssh_args"
mkdir -p "$bin_dir"

cat > "$bin_dir/ssh" <<'SH'
#!/usr/bin/env bash
echo "$@" > "$LM_SSH_TEST_ARGS_FILE"
exit 0
SH
chmod +x "$bin_dir/ssh"

PATH="$bin_dir:$PATH" \
LM_STATE_DIR="$state_dir" \
LM_SSH_TEST_ARGS_FILE="$args_file" \
bash -c '. "$0"; lm_ssh "example.com" "true"' "$LIB"

[ -d "$state_dir" ] || { echo "expected state dir to be created: $state_dir" >&2; exit 1; }

grep -q "UserKnownHostsFile=${state_dir}/known_hosts" "$args_file" || {
  echo "expected UserKnownHostsFile to use LM_STATE_DIR" >&2
  cat "$args_file" >&2 || true
  exit 1
}

echo "ssh known_hosts path ok"
