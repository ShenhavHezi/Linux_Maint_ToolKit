#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$ROOT_DIR/tests/testlib.sh"

workdir="$(mktemp -d -p "$TMPDIR")"
repo_copy="$workdir/repo"
policy_file="$workdir/policy.conf"
tmp_run_dir="$workdir/tmp"
trap 'chmod 644 "$policy_file" 2>/dev/null || true; rm -rf "$workdir"' EXIT
testlib_copy_repo_tracked "$repo_copy"
LM="$repo_copy/bin/linux-maint"
mkdir -p "$tmp_run_dir"
chmod 1777 "$tmp_run_dir"

cat > "$policy_file" <<'EOF'
max_crit=0
max_warn=10
require_overall=
EOF
chmod 000 "$policy_file"

if [[ "$(id -u)" -eq 0 ]]; then
  if command -v su >/dev/null 2>&1 && id nobody >/dev/null 2>&1; then
    chmod 0755 "$workdir" "$repo_copy"
    chmod 1777 "$tmp_run_dir"
    chmod -R a+rX "$repo_copy"
    chmod 0600 "$policy_file"
    set +e
    out="$(su -s /bin/bash nobody -c "HOME='$workdir' TMPDIR='$tmp_run_dir' bash '$LM' gate --policy '$policy_file' --json" 2>&1)"
    rc=$?
    set -e
  else
    echo "gate unreadable policy skipped under root: no su/nobody"
    exit 0
  fi
else
  set +e
  out="$(bash "$LM" gate --policy "$policy_file" --json 2>&1)"
  rc=$?
  set -e
fi

[[ "$rc" -eq 2 ]] || {
  echo "expected gate unreadable policy failure rc=2, got rc=$rc" >&2
  echo "$out" >&2
  exit 1
}

printf '%s\n' "$out" | grep -q 'policy file not readable' || {
  echo "unexpected gate unreadable policy output" >&2
  echo "$out" >&2
  exit 1
}

echo "gate unreadable policy ok"
