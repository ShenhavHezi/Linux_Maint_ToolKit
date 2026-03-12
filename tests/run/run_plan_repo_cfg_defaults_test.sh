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
printf '%s\n' repo-host-a repo-host-b > "$repo_cfg/servers.txt"
: > "$repo_cfg/excluded.txt"
printf '%s\n' group-host-a group-host-b > "$repo_cfg/hosts.d/prod.txt"

plan_json="$(env -u LM_CFG_DIR -u LM_SERVERLIST -u LM_EXCLUDED -u LM_HOSTS_DIR -u LM_GROUP "$LM" run --plan --json --local-only)"
group_plan_json="$(env -u LM_CFG_DIR -u LM_SERVERLIST -u LM_EXCLUDED -u LM_HOSTS_DIR LM_GROUP=prod "$LM" run --plan --json --local-only)"

python3 - <<'PY' "$plan_json" "$group_plan_json"
import json
import sys

plan = json.loads(sys.argv[1])
group_plan = json.loads(sys.argv[2])

assert plan["hosts"] == ["repo-host-a", "repo-host-b"], plan
assert group_plan["hosts"] == ["group-host-a", "group-host-b"], group_plan
PY

echo "run plan repo cfg defaults ok"
