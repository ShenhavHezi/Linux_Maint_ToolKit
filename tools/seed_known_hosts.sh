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
  --check                verify current known_hosts entries against live keys
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
CHECK=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --hosts) HOSTS_RAW="$2"; shift 2;;
    --hosts-file) HOSTS_FILE="$2"; shift 2;;
    --group) GROUP="$2"; shift 2;;
    --out) OUT="$2"; shift 2;;
    --timeout) TIMEOUT="$2"; shift 2;;
    --hash) HASH=1; shift;;
    --dry-run) DRY_RUN=1; shift;;
    --check) CHECK=1; shift;;
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

if ! command -v ssh-keyscan >/dev/null 2>&1; then
  echo "ERROR: ssh-keyscan not found (install openssh-clients)" >&2
  exit 1
fi

normalize_host() {
  local raw="$1" host="$1" port=""
  host="${host#*@}"
  if [[ "$host" =~ ^\[.*\]:[0-9]+$ ]]; then
    port="${host##*:}"
    host="${host#\[}"
    host="${host%\]:*}"
  elif [[ "$host" =~ ^[^:]+:[0-9]+$ ]]; then
    port="${host##*:}"
    host="${host%%:*}"
  fi
  if [[ -n "$port" ]]; then
    printf '[%s]:%s' "$host" "$port"
  else
    printf '%s' "$host"
  fi
}

scan_host_lines() {
  local raw="$1" host="$1" port=""
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
    ssh-keyscan -T "$TIMEOUT" -p "$port" "$host" 2>/dev/null | \
      awk -v h="$host" -v p="$port" '{ $1="["h"]:"p; print }'
  else
    ssh-keyscan -T "$TIMEOUT" "$host" 2>/dev/null
  fi
}

if [[ "$CHECK" -eq 1 ]]; then
  if [[ ! -s "$OUT" ]]; then
    echo "ERROR: known_hosts file not found or empty: $OUT" >&2
    exit 1
  fi
  if grep -q '^\|1\|' "$OUT"; then
    echo "WARN: hashed known_hosts entries detected; check may be incomplete" >&2
  fi

  declare -A existing_keys=()
  declare -A existing_hosts=()
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    [[ "$line" =~ ^\|1\| ]] && continue
    read -r hostfield keytype key _rest <<< "$line"
    [[ -z "$hostfield" || -z "$keytype" || -z "$key" ]] && continue
    IFS=',' read -ra hostlist <<< "$hostfield"
    for h in "${hostlist[@]}"; do
      existing_hosts["$h"]=1
      existing_keys["$h|$keytype|$key"]=1
    done
  done < "$OUT"

  missing=0
  mismatch=0
  for h in "${hosts[@]}"; do
    label="$(normalize_host "$h")"
    if [[ -z "${existing_hosts[$label]+x}" ]]; then
      echo "MISSING: $label (no known_hosts entry)" >&2
      missing=$((missing+1))
      continue
    fi
    found_match=0
    while IFS= read -r line; do
      read -r hostfield keytype key _rest <<< "$line"
      [[ -z "$hostfield" || -z "$keytype" || -z "$key" ]] && continue
      if [[ -n "${existing_keys[$hostfield|$keytype|$key]+x}" ]]; then
        found_match=1
        break
      fi
    done < <(scan_host_lines "$h")
    if [[ "$found_match" -eq 0 ]]; then
      echo "MISMATCH: $label (key changed or not present)" >&2
      mismatch=$((mismatch+1))
    fi
  done

  if [[ "$missing" -gt 0 || "$mismatch" -gt 0 ]]; then
    echo "known_hosts check failed: missing=$missing mismatch=$mismatch" >&2
    exit 1
  fi
  echo "known_hosts check ok (hosts=${#hosts[@]})"
  exit 0
fi

mkdir -p "$(dirname "$OUT")" 2>/dev/null || true

workdir="${TMPDIR:-/tmp}"
tmp="$(mktemp -p "$workdir" lm_known_hosts.XXXXXX)"
trap 'rm -f "$tmp"' EXIT

fail=0

scan_host() {
  local raw="$1"
  if ! scan_host_lines "$raw" >> "$tmp"; then
    echo "WARN: ssh-keyscan failed for $raw" >&2
    fail=1
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
