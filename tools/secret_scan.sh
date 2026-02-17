#!/usr/bin/env bash
# Lightweight high-confidence secret scanner with allowlist support.
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SCAN_DIR="$ROOT_DIR"
ALLOWLIST="$ROOT_DIR/tests/secret_scan_allowlist.txt"

usage(){
  cat <<USAGE
Usage: $0 [--path DIR] [--allowlist FILE]

Scans for high-confidence secret patterns and fails non-zero when matches are found
that are not allowlisted.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --path) SCAN_DIR="$2"; shift 2 ;;
    --allowlist) ALLOWLIST="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -d "$SCAN_DIR" ]] || { echo "ERROR: scan path not found: $SCAN_DIR" >&2; exit 2; }

# High-confidence patterns to reduce false positives.
patterns=(
  'AKIA[0-9A-Z]{16}'
  '-----BEGIN (RSA|EC|OPENSSH|DSA|PGP)? ?PRIVATE KEY-----'
  'ghp_[A-Za-z0-9]{36}'
  'github_pat_[A-Za-z0-9_]{20,}'
  'xox[baprs]-[A-Za-z0-9-]{20,}'
)

raw_matches="$(mktemp /tmp/lm_secret_scan_raw.XXXXXX)"
trap 'rm -f "$raw_matches"' EXIT
: > "$raw_matches"

for pat in "${patterns[@]}"; do
  rg -n --pcre2 --hidden --no-ignore-vcs --glob '!.git/**' --glob '!dist/**' -- "$pat" "$SCAN_DIR" >> "$raw_matches" || true
done

if [[ ! -s "$raw_matches" ]]; then
  echo "secret scan ok"
  exit 0
fi

# Apply allowlist (line contains any allowlist token => ignored).
filtered="$(mktemp /tmp/lm_secret_scan_filtered.XXXXXX)"
trap 'rm -f "$raw_matches" "$filtered"' EXIT
cp "$raw_matches" "$filtered"

if [[ -f "$ALLOWLIST" ]]; then
  while IFS= read -r token; do
    [[ -z "$token" || "$token" =~ ^# ]] && continue
    # Remove lines containing allowlist token (fixed substring).
    grep -F -v -- "$token" "$filtered" > "$filtered.tmp" || true
    mv "$filtered.tmp" "$filtered"
  done < "$ALLOWLIST"
fi

if [[ -s "$filtered" ]]; then
  echo "Potential secrets detected:" >&2
  cat "$filtered" >&2
  exit 1
fi

echo "secret scan ok"
