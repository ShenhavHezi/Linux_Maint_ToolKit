#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

repo_cfg="$ROOT_DIR/.etc_linux_maint"
backup=""
cleanup() {
  rm -rf "$repo_cfg"
  if [[ -n "$backup" && -d "$backup" ]]; then
    mv "$backup" "$repo_cfg"
  fi
}
trap cleanup EXIT

if [[ -e "$repo_cfg" ]]; then
  backup="$(mktemp -d -p "$TMPDIR")/repo_cfg_backup"
  mv "$repo_cfg" "$backup"
fi

mkdir -p "$repo_cfg/hosts.d"
printf '%s\n' localhost > "$repo_cfg/servers.txt"
: > "$repo_cfg/excluded.txt"

set +e
out="$(env -u LM_CFG_DIR -u LM_SERVERLIST -u LM_EXCLUDED -u LM_HOSTS_DIR "$LM" run --group missing-prod --plan --json --local-only 2>&1)"
rc=$?
set -e

if [[ "$rc" -ne 2 ]]; then
  echo "expected missing run group rc=2, got $rc" >&2
  echo "$out" >&2
  exit 1
fi
printf '%s\n' "$out" | grep -q '^ERROR: run group not found: missing-prod$' || {
  echo "missing group error was not clear" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q 'Expected group file: .*/hosts.d/missing-prod.txt$' || {
  echo "missing expected group file hint" >&2
  echo "$out" >&2
  exit 1
}

echo "run missing group ok"
