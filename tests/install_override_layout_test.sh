#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

prefix="$workdir/prefix"
cfg="$workdir/etc/linux_maint"
logdir="$workdir/var/log/health"
statedir="$workdir/var/lib/linux_maint"

(
  cd "$ROOT_DIR"
  LM_INSTALL_SKIP_ROOT_CHECK=1 \
  LM_INSTALL_CFG_DIR="$cfg" \
  LM_INSTALL_LOG_DIR="$logdir" \
  LM_INSTALL_STATE_DIR="$statedir" \
  bash ./install.sh --prefix "$prefix" >/dev/null
)

[[ -x "$prefix/bin/linux-maint" ]] || {
  echo "install.sh did not install linux-maint into custom prefix" >&2
  exit 1
}

[[ -f "$prefix/share/linux_maint/VERSION" ]] || {
  echo "install.sh did not install VERSION into custom share dir" >&2
  exit 1
}

[[ -f "$prefix/share/linux_maint/plugins/index.json" ]] || {
  echo "install.sh did not install packaged plugin index into custom share dir" >&2
  exit 1
}

[[ -f "$prefix/lib/linux_maint_help.sh" ]] || {
  echo "install.sh did not install linux_maint_help.sh into custom lib dir" >&2
  exit 1
}

[[ -f "$cfg/linux-maint.conf" ]] || {
  echo "install.sh did not install linux-maint.conf into override cfg dir" >&2
  exit 1
}

[[ -d "$cfg/conf.d" && -d "$cfg/baselines" ]] || {
  echo "install.sh did not create override cfg subdirectories" >&2
  exit 1
}

[[ -d "$logdir" && -d "$statedir" ]] || {
  echo "install.sh did not create override log/state dirs" >&2
  exit 1
}

echo "install override layout ok"
