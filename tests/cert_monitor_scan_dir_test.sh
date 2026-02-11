#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
workdir="$(mktemp -d)"
cleanup(){ rm -rf "$workdir"; }
trap cleanup EXIT

# Create 2 certs: one expiring soon, one long-lived.
# Use openssl req -x509 to generate self-signed certs.

# long-lived (365 days)
openssl req -x509 -newkey rsa:2048 -sha256 -days 365 -nodes \
  -subj "/CN=long.example" \
  -keyout "$workdir/long.key" -out "$workdir/long.crt" >/dev/null 2>&1

# short-lived (1 day)
openssl req -x509 -newkey rsa:2048 -sha256 -days 1 -nodes \
  -subj "/CN=short.example" \
  -keyout "$workdir/short.key" -out "$workdir/short.crt" >/dev/null 2>&1

# Ignore the long-lived cert
printf '%s\n' 'long.crt' > "$workdir/ignore.txt"

out="$(
  env \
    LINUX_MAINT_LIB="$ROOT_DIR/lib/linux_maint.sh" \
    LM_LOCKDIR=/tmp \
    LM_LOGFILE=/tmp/linux_maint_cert_scan_test.log \
    CERTS_SCAN_DIR="$workdir" \
    CERTS_SCAN_IGNORE_FILE="$workdir/ignore.txt" \
    CERTS_SCAN_EXTS="crt" \
    LM_CERT_WARN_DAYS=30 \
    LM_CERT_CRIT_DAYS=7 \
    bash "$ROOT_DIR/monitors/cert_monitor.sh" 2>/dev/null
)"

# Must emit summary line
echo "$out" | grep -q '^monitor=cert_monitor ' || { echo "missing summary" >&2; echo "$out" >&2; exit 1; }

# Expect WARN or CRIT because short cert is near expiry.
status="$(echo "$out" | awk '{for(i=1;i<=NF;i++){split($i,a,"="); if(a[1]=="status"){print a[2]; exit}}}')"
case "$status" in
  WARN|CRIT) ;;
  *)
    echo "expected WARN/CRIT got $status" >&2
    echo "$out" >&2
    exit 1
    ;;
esac

echo "cert_monitor scan dir ok"
