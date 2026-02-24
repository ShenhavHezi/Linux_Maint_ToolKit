#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

host="cache-host"

export LINUX_MAINT_LIB="$ROOT_DIR/lib/linux_maint.sh"
export LM_SERVERLIST="$workdir/hosts.txt"
export LM_INVENTORY_OUTPUT_DIR="$workdir/out"
export LM_INVENTORY_CACHE_DIR="$workdir/cache"
export LM_INVENTORY_CACHE=1
export LM_INVENTORY_CACHE_TTL=99999
export LM_LOGFILE="$workdir/inventory_export.log"
export LM_LOCKDIR="$workdir/lock"
export LM_EMAIL_ENABLED=false

mkdir -p "$LM_INVENTORY_CACHE_DIR"

echo "$host" > "$LM_SERVERLIST"

cache_kv="$LM_INVENTORY_CACHE_DIR/${host}.kv"
cat > "$cache_kv" <<EOF_KV
DATE=2026-02-24T10:00:00+0000
HOST=$host
FQDN=$host.example
OS=TestOS
KERNEL=1.0
ARCH=x86_64
VIRT=none
UPTIME=up 1 hour
CPU_MODEL=TestCPU
SOCKETS=1
CORES_PER_SOCKET=2
THREADS_PER_CORE=1
VCPUS=2
MEM_MB=1024
SWAP_MB=0
DISK_TOTAL_GB=10
ROOTFS_USE=10%
VGS=0
LVS=0
PVS=0
VGS_SIZE_GB=0
IPS=127.0.0.1
GW=127.0.0.1
DNS=127.0.0.1
PKG_COUNT=1
EOF_KV

cache_details="$LM_INVENTORY_CACHE_DIR/${host}.details.txt"
echo "cached details" > "$cache_details"

out="$(bash "$ROOT_DIR/monitors/inventory_export.sh")"
echo "$out" | grep -q 'monitor=inventory_export'

today_csv="$LM_INVENTORY_OUTPUT_DIR/inventory_$(date +%F).csv"
if [[ ! -f "$today_csv" ]]; then
  echo "expected csv at $today_csv" >&2
  exit 1
fi

rows=$(wc -l < "$today_csv" | tr -d ' ')
if [[ "$rows" -ne 2 ]]; then
  echo "expected 2 rows in csv (header+1), got $rows" >&2
  exit 1
fi

details="$LM_INVENTORY_OUTPUT_DIR/details/${host}_$(date +%F).txt"
if ! grep -q 'cached details' "$details"; then
  echo "expected cached details copy in $details" >&2
  exit 1
fi

echo "inventory cache ok"
