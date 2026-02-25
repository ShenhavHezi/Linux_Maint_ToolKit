#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$ROOT_DIR/lib/linux_maint.sh"

tmp_root="$(mktemp -d -p "$TMPDIR" lm_kh_pin_test.XXXXXX)"
trap 'rm -rf "$tmp_root"' EXIT

pin_file="$tmp_root/pinned_hosts"
args_file="$tmp_root/ssh_args"
bin_dir="$tmp_root/bin"
mkdir -p "$bin_dir"

cat > "$bin_dir/ssh" <<'SH'
#!/usr/bin/env bash
echo "$@" > "$LM_SSH_TEST_ARGS_FILE"
exit 0
SH
chmod +x "$bin_dir/ssh"

PATH="$bin_dir:$PATH" \
LM_SSH_KNOWN_HOSTS_PIN_FILE="$pin_file" \
LM_SSH_TEST_ARGS_FILE="$args_file" \
bash -c '. "$0"; lm_ssh "example.com" "true"' "$LIB"

grep -q "UserKnownHostsFile=${pin_file}" "$args_file" || {
  echo "expected UserKnownHostsFile to use pin file" >&2
  cat "$args_file" >&2 || true
  exit 1
}

grep -q "StrictHostKeyChecking=yes" "$args_file" || {
  echo "expected StrictHostKeyChecking=yes with pin file" >&2
  cat "$args_file" >&2 || true
  exit 1
}

echo "ssh known_hosts pin ok"
