#!/usr/bin/env bash
set -euo pipefail

TMPDIR="${TMPDIR:-/tmp}"

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

# Progress (stderr, best-effort)
progress_enabled=0
if [[ -t 2 ]]; then
  progress_enabled=1
fi
case "${LM_PROGRESS:-1}" in
  0|false|no|off) progress_enabled=0 ;;
esac
progress_width="${LM_PROGRESS_WIDTH:-24}"
progress_total=0
progress_idx=0
progress_render() {
  local idx="$1" total="$2" label="$3"
  [[ "$progress_enabled" -eq 1 ]] || return 0
  [[ "$total" -gt 0 ]] || return 0
  local filled=$(( idx * progress_width / total ))
  local rest=$(( progress_width - filled ))
  local bar
  bar="$(printf '%*s' "$filled" '' | tr ' ' '#')"
  bar="${bar}$(printf '%*s' "$rest" '' | tr ' ' '-')"
  printf '\r[%s] %d/%d %s' "$bar" "$idx" "$total" "$label" >&2
}
progress_step() {
  [[ "$progress_enabled" -eq 1 ]] || return 0
  progress_idx=$((progress_idx+1))
  progress_render "$progress_idx" "$progress_total" "${1:-}"
}
progress_done() {
  [[ "$progress_enabled" -eq 1 ]] || return 0
  printf '\n' >&2
}

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

redact_enabled() {
  case "${LM_REDACT_LOGS:-0}" in
    1|true|TRUE|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

copy_log() {
  local src="$1" dest_dir="$2"
  local base
  base="$(basename -- "$src")"
  if redact_enabled; then
    case "$src" in
      *.log|*.json|*.txt|*.csv|*.conf)
        redact_file "$src" "$dest_dir/$base" 2>/dev/null || true
        return 0
        ;;
    esac
  fi
  cp -a "$src" "$dest_dir/" 2>/dev/null || true
}

list_latest() {
  local pattern="$1" max="$2"
  find "$(dirname -- "$pattern")" -maxdepth 1 -type f -name "$(basename -- "$pattern")" \
    -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n "$max" | awk '{print $2}'
}

# Collect candidate files (for progress sizing)
log_files=()
for f in \
  "$LOG_DIR/full_health_monitor_latest.log" \
  "$LOG_DIR/full_health_monitor_summary_latest.log" \
  "$LOG_DIR/full_health_monitor_summary_latest.json" \
  "$LOG_DIR/last_status_full" \
  ; do
  if [[ -e "$f" ]]; then
    log_files+=("$f")
  fi
done

MAX_LOGS="${MAX_LOGS:-3}"
if [[ -d "$LOG_DIR" ]]; then
  mapfile -t _list < <(list_latest "${LOG_DIR}/full_health_monitor_*.log" "$MAX_LOGS")
  log_files+=("${_list[@]}")
  mapfile -t _list < <(list_latest "${LOG_DIR}/full_health_monitor_summary_*.log" "$MAX_LOGS")
  log_files+=("${_list[@]}")
  mapfile -t _list < <(list_latest "${LOG_DIR}/full_health_monitor_summary_*.json" "$MAX_LOGS")
  log_files+=("${_list[@]}")
fi

cfg_files=()
if [[ -d "$CFG_DIR" && -r "$CFG_DIR" ]]; then
  mapfile -t cfg_files < <(find "$CFG_DIR" -type f 2>/dev/null || true)
fi

meta_files=()
for f in \
  "/usr/local/share/Linux_Maint_ToolKit/BUILD_INFO" \
  "/usr/local/share/Linux_Maint_ToolKit/VERSION" \
  "/usr/local/share/linux-maint/BUILD_INFO" \
  "/usr/local/share/linux-maint/VERSION" \
  "${REPO_ROOT:-}/BUILD_INFO" \
  "${REPO_ROOT:-}/VERSION" \
  ; do
  if [[ -f "$f" ]]; then
    meta_files+=("$f")
  fi
done

state_files=()
if [[ -d "$STATE_DIR" && -r "$STATE_DIR" ]]; then
  mapfile -t state_files < <(find "$STATE_DIR" -maxdepth 2 -type f -size -256k 2>/dev/null || true)
fi

progress_total=$(( ${#log_files[@]} + ${#cfg_files[@]} + ${#meta_files[@]} + ${#state_files[@]} + 1 ))

mkdir -p "$OUTDIR"
workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

bundle_root="$workdir/bundle"
mkdir -p "$bundle_root"

# Bundle metadata
mkdir -p "$bundle_root/meta"
redact_state="disabled"
if redact_enabled; then
  redact_state="enabled"
fi
{
  echo "created_utc=$TS"
  echo "redaction=$redact_state"
} > "$bundle_root/meta/bundle_meta.txt"

# --- Logs ---
mkdir -p "$bundle_root/logs"

for f in "${log_files[@]}"; do
  [[ -n "$f" ]] || continue
  copy_log "$f" "$bundle_root/logs"
  progress_step "log:$(basename -- "$f")"
done

# --- Config (redacted) ---
if [[ "${#cfg_files[@]}" -gt 0 ]]; then
  mkdir -p "$bundle_root/config"
  # Copy while preserving relative layout.
  # Redact only text-like files.
  for f in "${cfg_files[@]}"; do
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
    progress_step "config:$(basename -- "$rel")"
  done
fi

# --- Build info ---
mkdir -p "$bundle_root/meta"
for f in "${meta_files[@]}"; do
  cp -a "$f" "$bundle_root/meta/" 2>/dev/null || true
  progress_step "meta:$(basename -- "$f")"
done

# --- State dir (optional, small files only) ---
if [[ "${#state_files[@]}" -gt 0 ]]; then
  mkdir -p "$bundle_root/state"
  for f in "${state_files[@]}"; do
    copy_log "$f" "$bundle_root/state"
    progress_step "state:$(basename -- "$f")"
  done
fi

out_name="${NAME_PREFIX}-${TS}.tar.gz"
out_path="$OUTDIR/$out_name"

tar -C "$bundle_root" -czf "$out_path" .
progress_step "compress"
progress_done

echo "$out_path"
