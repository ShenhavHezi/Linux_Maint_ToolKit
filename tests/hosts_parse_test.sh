#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$ROOT_DIR/lib/linux_maint.sh"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

servers="$workdir/servers.txt"
excluded="$workdir/excluded.txt"

cat > "$servers" <<'HOSTS'
# comment line
host1,host2 host3
user@host4  host5:2222
[2001:db8::1]:2222
host1  # duplicate
HOSTS

cat > "$excluded" <<'EXCL'
host2
host5:2222
EXCL

expected="$workdir/expected.txt"
cat > "$expected" <<'EXP'
host1
host3
user@host4
[2001:db8::1]:2222
EXP

out="$workdir/out.txt"
LM_SERVERLIST="$servers" LM_EXCLUDED="$excluded" bash -c ". \"$LIB\"; lm_hosts" > "$out"

if ! diff -u "$expected" "$out"; then
  echo "hosts_parse_test failed" >&2
  exit 1
fi

# Group precedence
hosts_dir="$workdir/hosts.d"
mkdir -p "$hosts_dir"
cat > "$hosts_dir/prod.txt" <<'HOSTS'
prod-1
prod-2
HOSTS

group_out="$workdir/group_out.txt"
LM_GROUP=prod LM_HOSTS_DIR="$hosts_dir" LM_SERVERLIST="$servers" bash -c ". \"$LIB\"; lm_hosts" > "$group_out"

cat > "$expected" <<'EXP'
prod-1
prod-2
EXP

if ! diff -u "$expected" "$group_out"; then
  echo "hosts_parse_test group precedence failed" >&2
  exit 1
fi

echo "hosts_parse_test ok"
