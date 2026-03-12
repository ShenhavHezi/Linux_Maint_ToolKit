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
db-01
EOF
: > "$repo_cfg/excluded.txt"
cat > "$repo_cfg/inventory_meta.csv" <<'EOF'
host,tags,role,env
web-01,web;frontend,web,prod
db-01,db;stateful,db,prod
EOF

set +e
out="$(env -u LM_CFG_DIR -u LM_SERVERLIST -u LM_EXCLUDED -u LM_HOSTS_DIR -u LM_INVENTORY_META "$LM" run --plan --json --local-only --tag canary 2>&1)"
rc=$?
set -e

if [[ "$rc" -ne 2 ]]; then
  echo "expected run --plan empty inventory filter rc=2, got $rc" >&2
  echo "$out" >&2
  exit 1
fi
printf '%s\n' "$out" | grep -q '^ERROR: inventory filters matched 0 hosts using ' || {
  echo "missing empty inventory filter error" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q '^requested: tag=canary$' || {
  echo "missing requested filter hint" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q 'available: .*tags=' || {
  echo "missing available filter hint" >&2
  echo "$out" >&2
  exit 1
}

echo "run inventory meta empty filter ok"
