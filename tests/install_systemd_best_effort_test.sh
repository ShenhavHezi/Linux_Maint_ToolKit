#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

prefix="$workdir/prefix"
cfg="$workdir/etc_linux_maint"
logdir="$workdir/var_log_health"
statedir="$workdir/var_lib_linux_maint"
systemd_dir="$workdir/systemd"
shim="$workdir/shim"
mkdir -p "$shim"

cat > "$shim/systemctl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  daemon-reload|enable|status)
    exit 1
    ;;
esac
exit 1
SH
chmod +x "$shim/systemctl"

out="$(
  cd "$ROOT_DIR"
  PATH="$shim:$PATH" \
  LM_INSTALL_SKIP_ROOT_CHECK=1 \
  LM_INSTALL_CFG_DIR="$cfg" \
  LM_INSTALL_LOG_DIR="$logdir" \
  LM_INSTALL_STATE_DIR="$statedir" \
  LM_INSTALL_SYSTEMD_DIR="$systemd_dir" \
  bash ./install.sh --prefix "$prefix" --with-timer 2>&1
)"

[[ -x "$prefix/bin/linux-maint" ]] || {
  echo "install with --with-timer did not complete when systemctl failed" >&2
  echo "$out" >&2
  exit 1
}

[[ -f "$systemd_dir/linux-maint.service" && -f "$systemd_dir/linux-maint.timer" ]] || {
  echo "install with --with-timer did not write unit files" >&2
  echo "$out" >&2
  exit 1
}

printf '%s\n' "$out" | grep -q 'WARN: systemctl daemon-reload failed' || {
  echo "install did not warn about daemon-reload failure" >&2
  echo "$out" >&2
  exit 1
}

printf '%s\n' "$out" | grep -q 'WARN: unable to enable/start linux-maint.timer' || {
  echo "install did not warn about enable/start failure" >&2
  echo "$out" >&2
  exit 1
}

echo "install systemd best effort ok"
