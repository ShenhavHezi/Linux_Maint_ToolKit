#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
workdir="$(mktemp -d "${TMPDIR:-/tmp}/lm_cfg_validate.XXXXXX")"
cleanup(){ chmod 0644 "$workdir/linux-maint.conf" 2>/dev/null || true; rm -rf "$workdir"; }
trap cleanup EXIT

mkdir -p "$workdir/conf.d"
cat > "$workdir/linux-maint.conf" <<'EOF_CONF'
LM_DARK_SITE=false
EOF_CONF
chmod 000 "$workdir/linux-maint.conf"

cat > "$workdir/linux-maint.conf.example" <<'EOF_EX'
LM_DARK_SITE=false
EOF_EX

log_file="$workdir/config_validate.log"
set +e
out="$(
  LM_CFG_DIR="$workdir" \
  LM_LOGFILE="$log_file" \
  LINUX_MAINT_LIB="$ROOT_DIR/lib/linux_maint.sh" \
  bash "$ROOT_DIR/monitors/config_validate.sh" 2>&1
)"
rc=$?
set -e

printf '%s\n' "$out" | grep -q '^monitor=config_validate ' || {
  echo "missing config_validate summary" >&2
  echo "$out" >&2
  exit 1
}

if printf '%s\n' "$out" | grep -q 'Permission denied'; then
  echo "config_validate leaked shell permission denied output" >&2
  echo "$out" >&2
  exit 1
fi

grep -q 'config unreadable:' "$log_file" || {
  echo "expected unreadable config warning in log" >&2
  cat "$log_file" >&2 || true
  exit 1
}

case "$rc" in
  0|1) ;;
  *)
    echo "unexpected exit code: $rc" >&2
    exit 1
    ;;
esac

echo "config validate unreadable conf ok"
