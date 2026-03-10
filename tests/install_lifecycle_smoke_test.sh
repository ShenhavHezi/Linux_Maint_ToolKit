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

run_install() {
  (
    cd "$ROOT_DIR"
    LM_INSTALL_SKIP_ROOT_CHECK=1 \
    LM_INSTALL_CFG_DIR="$cfg" \
    LM_INSTALL_LOG_DIR="$logdir" \
    LM_INSTALL_STATE_DIR="$statedir" \
    bash ./install.sh --prefix "$prefix" >/dev/null
  )
}

run_install
run_install

lm="$prefix/bin/linux-maint"
[[ -x "$lm" ]] || {
  echo "installed linux-maint binary missing after reinstall" >&2
  exit 1
}

status_help="$(NO_COLOR=1 "$lm" help status 2>&1 || true)"
printf '%s\n' "$status_help" | grep -q '^Purpose:$' || {
  echo "installed linux-maint help status missing Purpose section" >&2
  echo "$status_help" >&2
  exit 1
}

serve_help="$(NO_COLOR=1 "$lm" help serve 2>&1 || true)"
printf '%s\n' "$serve_help" | grep -q '^Examples:$' || {
  echo "installed linux-maint help serve missing Examples section" >&2
  echo "$serve_help" >&2
  exit 1
}

(
  cd "$ROOT_DIR"
  LM_INSTALL_SKIP_ROOT_CHECK=1 \
  LM_INSTALL_CFG_DIR="$cfg" \
  LM_INSTALL_LOG_DIR="$logdir" \
  LM_INSTALL_STATE_DIR="$statedir" \
  bash ./install.sh --prefix "$prefix" --uninstall >/dev/null
)

[[ ! -e "$prefix/bin/linux-maint" ]] || {
  echo "installed linux-maint binary still exists after uninstall" >&2
  exit 1
}

echo "install lifecycle smoke ok"
