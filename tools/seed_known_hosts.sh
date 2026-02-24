#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

# Best-effort source for defaults (LM_SERVERLIST, LM_HOSTS_DIR, LM_SSH_KNOWN_HOSTS_FILE)
for lib in "$ROOT_DIR/lib/linux_maint.sh" /usr/local/lib/linux_maint.sh /usr/lib/linux_maint.sh; do
  if [[ -f "$lib" ]]; then
    # shellcheck disable=SC1090
    . "$lib"
    break
  fi
done

usage() {
  cat <<'USAGE'
Usage: seed_known_hosts.sh [options]

Options:
  --hosts "a,b c"        explicit host list (comma/space-separated)
  --hosts-file FILE      hosts file (default: /etc/linux_maint/servers.txt)
  --group NAME           group file from /etc/linux_maint/hosts.d/NAME.txt
  --out FILE             output known_hosts file
  --timeout SECS         ssh-keyscan timeout per host (default: 5)
  --hash                 hash hostnames in output (ssh-keygen -H)
  --dry-run              print resolved hosts and target file
  -h, --help             show help

Notes:
- Requires ssh-keyscan (openssh-clients).
- For strict mode, set LM_SSH_KNOWN_HOSTS_MODE=strict after seeding.
- Verify host keys out-of-band for high-security environments.
USAGE
}

HOSTS_RAW=""
HOSTS_FILE=""
GROUP=""
OUT=""
TIMEOUT=5
HASH=0
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --hosts) HOSTS_RAW="$2"; shift 2;;
    --hosts-file) HOSTS_FILE="$2"; shift 2;;
    --group) GROUP="$2"; shift 2;;
    --out) OUT="$2"; shift 2;;
    --timeout) TIMEOUT="$2"; shift 2;;
    --hash) HASH=1; shift;;
    --dry-run) DRY_RUN=1; shift;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown option: $1" >&2; usage; exit 2;;
  esac
done

if [[ -z "$OUT" ]]; then
  OUT="${LM_SSH_KNOWN_HOSTS_FILE:-/var/lib/linux_maint/known_hosts}"
fi

if [[ -n "$GROUP" && -z "$HOSTS_FILE" ]]; then
  hosts_dir="${LM_HOSTS_DIR:-/etc/linux_maint/hosts.d}"
  HOSTS_FILE="$hosts_dir/${GROUP}.txt"
fi

if [[ -z "$HOSTS_FILE" ]]; then
  HOSTS_FILE="${LM_SERVERLIST:-/etc/linux_maint/servers.txt}"
fi

if ! command -v ssh-keyscan >/dev/null 2>&1; then
  echo "ERROR: ssh-keyscan not found (install openssh-clients)" >&2
  exit 1
fi

hosts=()
if [[ -n "$HOSTS_RAW" ]]; then
  while IFS= read -r h; do
    hosts+=("$h")
  done < <(printf '%s' "$HOSTS_RAW" | tr ', ' '\n' | awk 'NF')
elif [[ -n "$HOSTS_FILE" && -f "$HOSTS_FILE" ]]; then
  while IFS= read -r h; do
    hosts+=("$h")
  done < <(grep -vE '^[[:space:]]*($|#)' "$HOSTS_FILE")
fi

if [[ ${#hosts[@]} -eq 0 ]]; then
  echo "ERROR: no hosts found (use --hosts, --hosts-file, or --group)" >&2
  exit 2
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "out=$OUT"
  printf '%s\n' "${hosts[@]}"
  exit 0
fi

mkdir -p "$(dirname "$OUT")" 2>/dev/null || true

workdir="${TMPDIR:-/tmp}"
tmp="$(mktemp -p "$workdir" lm_known_hosts.XXXXXX)"
trap 'rm -f "$tmp"' EXIT

fail=0

scan_host() {
  local raw="$1" host="$1" port="" out_line
  # Strip user@ prefix if present
  host="${host#*@}"
  [[ -z "$host" ]] && return 0

  if [[ "$host" =~ ^\[.*\]:[0-9]+$ ]]; then
    port="${host##*:}"
    host="${host#\[}"
    host="${host%\]:*}"
  elif [[ "$host" =~ ^[^:]+:[0-9]+$ ]]; then
    port="${host##*:}"
    host="${host%%:*}"
  fi

  if [[ -n "$port" ]]; then
    if ! ssh-keyscan -T "$TIMEOUT" -p "$port" "$host" 2>/dev/null | \
      awk -v h="$host" -v p="$port" '{ $1="["h"]:"p; print }' >> "$tmp"; then
      echo "WARN: ssh-keyscan failed for $raw" >&2
      fail=1
    fi
  else
    if ! ssh-keyscan -T "$TIMEOUT" "$host" 2>/dev/null >> "$tmp"; then
      echo "WARN: ssh-keyscan failed for $raw" >&2
      fail=1
    fi
  fi
}

for h in "${hosts[@]}"; do
  scan_host "$h"
done

if [[ ! -s "$tmp" ]]; then
  echo "ERROR: no host keys collected" >&2
  exit 1
fi

# Optional hashing
if [[ "$HASH" -eq 1 ]]; then
  if command -v ssh-keygen >/dev/null 2>&1; then
    ssh-keygen -H -f "$tmp" >/dev/null 2>&1 || true
    rm -f "${tmp}.old" 2>/dev/null || true
  else
    echo "WARN: ssh-keygen not found; skipping --hash" >&2
  fi
fi

if [[ -f "$OUT" ]]; then
  cat "$OUT" "$tmp" | awk 'NF && $1 !~ /^#/' | awk '!seen[$0]++' > "${OUT}.new"
else
  awk 'NF && $1 !~ /^#/' "$tmp" | awk '!seen[$0]++' > "${OUT}.new"
fi

mv -f "${OUT}.new" "$OUT"
chmod 0644 "$OUT" 2>/dev/null || true

echo "known_hosts updated: $OUT (hosts=${#hosts[@]})"

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
