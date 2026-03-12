#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

prefix="$workdir/prefix"
cfg="$workdir/etc/linux_maint"
logdir="$workdir/var/log/health"
statedir="$workdir/var/lib/linux_maint"

mkdir -p "$prefix/bin" "$prefix/lib" "$prefix/share/linux_maint"
printf '%s\n' 'old-binary' > "$prefix/bin/linux-maint"
printf '%s\n' 'old-library' > "$prefix/lib/linux_maint.sh"
printf '%s\n' 'old-version' > "$prefix/share/linux_maint/VERSION"

set +e
out="$(
  cd "$ROOT_DIR"
  LM_INSTALL_SKIP_ROOT_CHECK=1 \
  LM_INSTALL_CFG_DIR="$cfg" \
  LM_INSTALL_LOG_DIR="$logdir" \
  LM_INSTALL_STATE_DIR="$statedir" \
  LM_INSTALL_FAIL_AT=after_payload_install \
  bash ./install.sh --prefix "$prefix" 2>&1
)"
rc=$?
set -e

if [[ "$rc" -eq 0 ]]; then
  echo "expected install.sh rollback failure path to exit non-zero" >&2
  exit 1
fi

grep -q '^Install failed; restoring previous payloads$' <<<"$out" || {
  echo "install.sh did not announce rollback on failure" >&2
  echo "$out" >&2
  exit 1
}

grep -q '^old-binary$' "$prefix/bin/linux-maint" || {
  echo "install.sh did not restore previous linux-maint binary" >&2
  exit 1
}

grep -q '^old-library$' "$prefix/lib/linux_maint.sh" || {
  echo "install.sh did not restore previous library" >&2
  exit 1
}

grep -q '^old-version$' "$prefix/share/linux_maint/VERSION" || {
  echo "install.sh did not restore previous VERSION file" >&2
  exit 1
}

[[ ! -e "$prefix/libexec/linux_maint" ]] || {
  echo "install.sh left partial libexec payload after rollback" >&2
  exit 1
}

echo "install rollback prefix failure ok"
