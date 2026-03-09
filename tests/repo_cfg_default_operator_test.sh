#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
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

mkdir -p "$repo_cfg"
cat > "$repo_cfg/linux-maint.conf" <<'CONF'
LM_LOCAL_ONLY=true
CONF
printf '%s\n' localhost > "$repo_cfg/servers.txt"
: > "$repo_cfg/excluded.txt"
: > "$repo_cfg/services.txt"
printf '%s\n' slow=1 > "$repo_cfg/monitor_runtime_warn.conf"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'cleanup; rm -rf "$workdir"' EXIT

logdir="$workdir/logs"
statedir="$workdir/state"
lockdir="$workdir/lock"
mkdir -p "$logdir" "$statedir" "$lockdir"

cat > "$logdir/full_health_monitor_2099-12-31_235959.log" <<'LOG'
RUNTIME monitor=slow ms=1200
RUNTIME monitor=fast ms=10
LOG

config_out="$(env -u LM_CFG_DIR "$LM" config --json)"
self_out="$(env -u LM_CFG_DIR LOG_DIR="$logdir" LM_STATE_DIR="$statedir" LM_LOCKDIR="$lockdir" "$LM" self-check --json)"
security_out="$(env -u LM_CFG_DIR LOG_DIR="$logdir" LM_STATE_DIR="$statedir" LM_LOCKDIR="$lockdir" "$LM" security-profile --json)"

python3 - <<'PY' "$config_out" "$self_out" "$security_out" "$repo_cfg"
import json
import sys

config = json.loads(sys.argv[1])
self_check = json.loads(sys.argv[2])
security = json.loads(sys.argv[3])
repo_cfg = sys.argv[4]

assert config["cfg_dir"] == repo_cfg, config
assert any(path.startswith(repo_cfg) for path in config["sources"]), config["sources"]
assert self_check["cfg_dir"] == repo_cfg, self_check
checks = {row["check"] for row in security["checks"]}
assert f"path_perm:{repo_cfg}" in checks, checks
PY

runtimes_out="$(env -u LM_CFG_DIR NO_COLOR='' LM_FORCE_COLOR=1 LOG_DIR="$logdir" "$LM" runtimes)"
printf '%s' "$runtimes_out" | grep -q $'\033\[' || {
  echo "runtimes did not use repo-mode default monitor_runtime_warn.conf" >&2
  printf '%s\n' "$runtimes_out" >&2
  exit 1
}

echo "repo cfg default operators ok"
