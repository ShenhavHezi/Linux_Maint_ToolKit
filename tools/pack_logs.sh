#!/usr/bin/env bash
set -euo pipefail

# tools/pack_logs.sh
# Build a support bundle (tar.gz) for incident handoff / dark-site export.
# Best-effort: includes what exists; never fails just because optional files are missing.

OUTDIR="${OUTDIR:-.}"
NAME_PREFIX="${NAME_PREFIX:-linux-maint-support}"
TS="${TS:-$(date -u +%Y%m%dT%H%M%SZ)}"

# Allow explicit paths (useful for repo vs installed)
LOG_DIR="${LOG_DIR:-/var/log/health}"
CFG_DIR="${CFG_DIR:-/etc/linux_maint}"
STATE_DIR="${STATE_DIR:-/var/lib/linux_maint}"

# Redaction is intentionally simple and conservative.
# We only redact common key patterns in *.conf and *.txt.
redact_file() {
  local in="$1" out="$2"
  # Best-effort redact common key/value + structured auth patterns.
  sed -E \
    -e 's/([[:alnum:]_]*(password|passwd|token|api[_-]?key|secret|access[_-]?key|private[_-]?key|session([_-]?id)?|id[_-]?token|refresh[_-]?token|x[_-]?auth[_-]?token)[[:alnum:]_]*)[[:space:]]*=[[:space:]]*[^[:space:]"'\'';]+/\1=REDACTED/gI' \
    -e 's/([[:alnum:]_]*(password|passwd|token|api[_-]?key|secret|access[_-]?key|private[_-]?key|session([_-]?id)?|id[_-]?token|refresh[_-]?token|x[_-]?auth[_-]?token)[[:alnum:]_]*)[[:space:]]*=[[:space:]]*"[^"]*"/\1="REDACTED"/gI' \
    -e "s/([[:alnum:]_]*(password|passwd|token|api[_-]?key|secret|access[_-]?key|private[_-]?key|session([_-]?id)?|id[_-]?token|refresh[_-]?token|x[_-]?auth[_-]?token)[[:alnum:]_]*)[[:space:]]*=[[:space:]]*'[^']*'/\\1='REDACTED'/gI" \
    -e 's/("?(authorization|x-auth-token|session_id|session|id_token|refresh_token|access_token)"?[[:space:]]*:[[:space:]]*)"[^"]*"/\1"REDACTED"/gI' \
    -e 's/(authorization:|x-auth-token:).*/\1 REDACTED/gI' \
    -e 's/(bearer)[[:space:]]+[[:alnum:]._~+\/-]+=*/\1 REDACTED/gI' \
    -e 's/[[:alnum:]_-]{12,}\.[[:alnum:]_-]{12,}\.[[:alnum:]_-]{12,}/REDACTED_JWT/g' \
    "$in" > "$out" 2>/dev/null || cp -f "$in" "$out"
}

mkdir -p "$OUTDIR"
workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

bundle_root="$workdir/bundle"
mkdir -p "$bundle_root"

# --- Logs ---
mkdir -p "$bundle_root/logs"

# Prefer latest symlinks if present
for f in \
  "$LOG_DIR/full_health_monitor_latest.log" \
  "$LOG_DIR/full_health_monitor_summary_latest.log" \
  "$LOG_DIR/full_health_monitor_summary_latest.json" \
  "$LOG_DIR/last_status_full" \
  ; do
  if [[ -e "$f" ]]; then
    cp -a "$f" "$bundle_root/logs/" 2>/dev/null || true
  fi
done

# Also include last N full logs if available (default 3)
MAX_LOGS="${MAX_LOGS:-3}"
if [[ -d "$LOG_DIR" ]]; then
  # shellcheck disable=SC2012
  ls -1t "$LOG_DIR"/full_health_monitor_*.log 2>/dev/null | head -n "$MAX_LOGS" | while IFS= read -r p; do
    cp -a "$p" "$bundle_root/logs/" 2>/dev/null || true
  done
  # shellcheck disable=SC2012
  ls -1t "$LOG_DIR"/full_health_monitor_summary_*.log 2>/dev/null | head -n "$MAX_LOGS" | while IFS= read -r p; do
    cp -a "$p" "$bundle_root/logs/" 2>/dev/null || true
  done
  # shellcheck disable=SC2012
  ls -1t "$LOG_DIR"/full_health_monitor_summary_*.json 2>/dev/null | head -n "$MAX_LOGS" | while IFS= read -r p; do
    cp -a "$p" "$bundle_root/logs/" 2>/dev/null || true
  done
fi

# --- Config (redacted) ---
if [[ -d "$CFG_DIR" ]]; then
  mkdir -p "$bundle_root/config"
  # Copy while preserving relative layout.
  # Redact only text-like files.
  find "$CFG_DIR" -type f 2>/dev/null | while IFS= read -r f; do
    rel="${f#"$CFG_DIR"/}"
    dest_dir="$bundle_root/config/$(dirname -- "$rel")"
    mkdir -p "$dest_dir"
    case "$f" in
      *.conf|*.txt|*.csv)
        # Redaction may fail if file is unreadable; treat as optional.
        redact_file "$f" "$dest_dir/$(basename -- "$rel")" 2>/dev/null || true
        ;;
      *)
        cp -a "$f" "$dest_dir/" 2>/dev/null || true
        ;;
    esac
  done
fi

# --- Build info ---
mkdir -p "$bundle_root/meta"
for f in \
  "/usr/local/share/linux_Maint_Scripts/BUILD_INFO" \
  "/usr/local/share/linux_Maint_Scripts/VERSION" \
  "/usr/local/share/linux-maint/BUILD_INFO" \
  "/usr/local/share/linux-maint/VERSION" \
  ; do
  if [[ -f "$f" ]]; then
    cp -a "$f" "$bundle_root/meta/" 2>/dev/null || true
  fi
done

# In repo mode, prefer repo-local files if present
if [[ -f "${REPO_ROOT:-}/BUILD_INFO" ]]; then
  cp -a "${REPO_ROOT}/BUILD_INFO" "$bundle_root/meta/" 2>/dev/null || true
fi
if [[ -f "${REPO_ROOT:-}/VERSION" ]]; then
  cp -a "${REPO_ROOT}/VERSION" "$bundle_root/meta/" 2>/dev/null || true
fi

# --- State dir (optional, small files only) ---
if [[ -d "$STATE_DIR" ]]; then
  mkdir -p "$bundle_root/state"
  # only include small state files (<256KB)
  find "$STATE_DIR" -maxdepth 2 -type f -size -256k 2>/dev/null | while IFS= read -r f; do
    cp -a "$f" "$bundle_root/state/" 2>/dev/null || true
  done
fi

out_name="${NAME_PREFIX}-${TS}.tar.gz"
out_path="$OUTDIR/$out_name"

tar -C "$bundle_root" -czf "$out_path" .

echo "$out_path"
