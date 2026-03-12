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
cat > "$repo_cfg/servers.txt" <<'EOF'
web-01
web-02
db-01
lab-01
EOF
: > "$repo_cfg/excluded.txt"
cat > "$repo_cfg/inventory_meta.csv" <<'EOF'
host,tags,role,env
web-01,web;frontend,web,prod
web-02,web;frontend,web,prod
db-01,db;stateful,db,prod
lab-01,lab;canary,web,dev
EOF

tag_plan_json="$(env -u LM_CFG_DIR -u LM_SERVERLIST -u LM_EXCLUDED -u LM_HOSTS_DIR -u LM_INVENTORY_META "$LM" run --plan --json --local-only --tag web --env prod)"
role_plan_json="$(env -u LM_CFG_DIR -u LM_SERVERLIST -u LM_EXCLUDED -u LM_HOSTS_DIR -u LM_INVENTORY_META "$LM" run --plan --json --local-only --role db)"

python3 - <<'PY' "$tag_plan_json" "$role_plan_json"
import json
import sys

tag_plan = json.loads(sys.argv[1])
role_plan = json.loads(sys.argv[2])

assert tag_plan["hosts"] == ["web-01", "web-02"], tag_plan
assert tag_plan["tag_filter"] == "web", tag_plan
assert tag_plan["env_filter"] == "prod", tag_plan
assert role_plan["hosts"] == ["db-01"], role_plan
assert role_plan["role_filter"] == "db", role_plan
PY

echo "run inventory meta filters ok"
