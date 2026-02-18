#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

prev="$workdir/prev.log"
cur="$workdir/cur.log"

cat > "$prev" <<'S'
monitor=service_monitor host=web-1 status=OK
monitor=service_monitor host=web-1 status=WARN reason=prev_warn
monitor=network_monitor host=web-1 status=WARN reason=old_network
S

cat > "$cur" <<'S'
monitor=service_monitor host=web-1 status=OK
monitor=service_monitor host=web-1 status=CRIT reason=cur_crit
monitor=network_monitor host=web-1 status=OK
monitor=backup_check host=backup-1 status=OK
monitor=backup_check host=backup-1 status=WARN reason=missing_targets_file
S

out="$(python3 "$ROOT_DIR/tools/summary_diff.py" "$prev" "$cur" --json)"
printf '%s' "$out" | python3 -c '
import json,sys
obj=json.load(sys.stdin)
assert obj["new_failures"] == []
assert len(obj["recovered"]) == 1
rec=obj["recovered"][0]
assert rec["monitor"]=="network_monitor" and rec["host"]=="web-1"
assert rec["prev"]["status"]=="WARN" and rec["cur"]["status"]=="OK"
trans=[x for x in obj["changed"] if x.get("type")=="transition"]
assert len(trans)==1
tr=trans[0]
assert tr["key"]==["service_monitor","web-1"]
assert tr["prev"]["status"]=="WARN" and tr["prev"]["reason"]=="prev_warn"
assert tr["cur"]["status"]=="CRIT" and tr["cur"]["reason"]=="cur_crit"
new=[x for x in obj["changed"] if x.get("type")=="new"]
assert len(new)==1
assert new[0]["key"]==["backup_check","backup-1"]
assert new[0]["cur"]["status"]=="WARN"
'

echo "summary diff canonicalization ok"
