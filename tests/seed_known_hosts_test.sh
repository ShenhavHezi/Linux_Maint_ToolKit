#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TOOL="$ROOT_DIR/tools/seed_known_hosts.sh"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

out="$workdir/out.txt"

# 1) Explicit hosts list with user@host, host:port, and IPv6 bracket form
"$TOOL" --hosts 'user@host1,host2:2222,[2001:db8::1]:2222' --out "$workdir/known_hosts" --dry-run > "$out"

grep -q "out=$workdir/known_hosts" "$out"
grep -q '^user@host1$' "$out"
grep -q '^host2:2222$' "$out"
grep -q '^\[2001:db8::1\]:2222$' "$out"

# 2) Hosts file parsing (ignore comments/blank lines)
cat > "$workdir/servers.txt" <<'HOSTS'
# comment
hostA

hostB
HOSTS

"$TOOL" --hosts-file "$workdir/servers.txt" --out "$workdir/known_hosts" --dry-run > "$out"

grep -q '^hostA$' "$out"
grep -q '^hostB$' "$out"

# 3) Group file parsing
mkdir -p "$workdir/hosts.d"
cat > "$workdir/hosts.d/prod.txt" <<'HOSTS'
prod-1
prod-2
HOSTS

LM_HOSTS_DIR="$workdir/hosts.d" "$TOOL" --group prod --out "$workdir/known_hosts" --dry-run > "$out"

grep -q '^prod-1$' "$out"
grep -q '^prod-2$' "$out"

echo "seed known_hosts ok"
