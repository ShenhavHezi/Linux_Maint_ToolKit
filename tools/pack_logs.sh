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

hash_enabled=0
case "${LM_PACK_LOGS_HASH:-0}" in
  1|true|TRUE|yes|YES) hash_enabled=1 ;;
esac
integrity_enabled=0
if command -v sha256sum >/dev/null 2>&1 && command -v stat >/dev/null 2>&1; then
  integrity_enabled=1
fi

gpg_enabled=0
case "${LM_PACK_LOGS_GPG:-0}" in
  1|true|TRUE|yes|YES) gpg_enabled=1 ;;
esac
gpg_recipient="${LM_PACK_LOGS_GPG_RECIPIENT:-}"
gpg_keep_plaintext=0
case "${LM_PACK_LOGS_GPG_KEEP_PLAINTEXT:-0}" in
  1|true|TRUE|yes|YES) gpg_keep_plaintext=1 ;;
esac

if [[ "$gpg_enabled" -eq 1 ]]; then
  if ! command -v gpg >/dev/null 2>&1; then
    echo "ERROR: gpg not found (requested --gpg)" >&2
    exit 2
  fi
  if [[ -z "$gpg_recipient" ]]; then
    echo "ERROR: --gpg requires --gpg-recipient (email or key id)" >&2
    exit 2
  fi
fi

workdir=""
bundle_rows="$TMPDIR/.linux_maint_bundle_rows.$$"
redaction_rows="$TMPDIR/.linux_maint_redaction_rows.$$"
cleanup_tmp_rows() {
  rm -f "$bundle_rows" "$redaction_rows" 2>/dev/null || true
}
trap 'rm -rf "$workdir"; cleanup_tmp_rows' EXIT
: > "$bundle_rows"
: > "$redaction_rows"

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
    -e 's/\bgh[pousr]_[A-Za-z0-9]{20,}\b/GH_REDACTED/g' \
    -e 's/\bgithub_pat_[A-Za-z0-9_]{20,}\b/GH_PAT_REDACTED/g' \
    -e 's/\bxox[baprs]-[A-Za-z0-9-]{10,}\b/SLACK_REDACTED/g' \
    -e 's/\bAIza[0-9A-Za-z_-]{35}\b/GCP_REDACTED/g' \
    -e 's/\bya29\.[A-Za-z0-9_-]{10,}\b/OAUTH_REDACTED/g' \
    -e 's/-----BEGIN [A-Z ]*PRIVATE KEY-----/-----BEGIN PRIVATE KEY-----/g' \
    -e 's/-----END [A-Z ]*PRIVATE KEY-----/-----END PRIVATE KEY-----/g' \
    "$in" > "$out" 2>/dev/null || cp -f "$in" "$out"
}

redact_enabled() {
  case "${LM_REDACT_LOGS:-0}" in
    1|true|TRUE|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

is_redactable_text() {
  case "$1" in
    *.log|*.json|*.txt|*.csv|*.conf) return 0 ;;
    *) return 1 ;;
  esac
}

record_bundle_copy() {
  local section="$1" src="$2" dest="$3" policy="$4" changed="$5"
  local rel="${dest#"$bundle_root"/}"
  rel="${rel#/}"
  while [[ "$rel" == *"/./"* ]]; do
    rel="${rel//\/.\//\/}"
  done
  printf '%s\t%s\t%s\t%s\t%s\n' "$section" "$rel" "$src" "$policy" "$changed" >> "$bundle_rows"
  if [[ "$policy" != "none" ]]; then
    printf '%s\t%s\t%s\t%s\t%s\n' "$section" "$rel" "$src" "$policy" "$changed" >> "$redaction_rows"
  fi
}

LAST_COPY_DEST=""
LAST_COPY_POLICY="none"
LAST_COPY_CHANGED=0
LAST_COPY_OK=0

copy_log() {
  local src="$1" dest_dir="$2"
  local base
  base="$(basename -- "$src")"
  LAST_COPY_DEST="$dest_dir/$base"
  LAST_COPY_POLICY="none"
  LAST_COPY_CHANGED=0
  LAST_COPY_OK=0
  if redact_enabled && is_redactable_text "$src"; then
    redact_file "$src" "$LAST_COPY_DEST" 2>/dev/null || true
    if [[ -f "$LAST_COPY_DEST" ]]; then
      LAST_COPY_POLICY="optional"
      LAST_COPY_OK=1
      cmp -s -- "$src" "$LAST_COPY_DEST" 2>/dev/null || LAST_COPY_CHANGED=1
    fi
    return 0
  fi
  cp -Lf "$src" "$LAST_COPY_DEST" 2>/dev/null || true
  [[ -f "$LAST_COPY_DEST" ]] && LAST_COPY_OK=1
  return 0
}

copy_config_file() {
  local src="$1" dest="$2"
  LAST_COPY_DEST="$dest"
  LAST_COPY_POLICY="none"
  LAST_COPY_CHANGED=0
  LAST_COPY_OK=0
  case "$src" in
    *.conf|*.txt|*.csv)
      redact_file "$src" "$dest" 2>/dev/null || true
      if [[ -f "$dest" ]]; then
        LAST_COPY_POLICY="always"
        LAST_COPY_OK=1
        cmp -s -- "$src" "$dest" 2>/dev/null || LAST_COPY_CHANGED=1
      fi
      ;;
    *)
      cp -a "$src" "$dest" 2>/dev/null || true
      [[ -e "$dest" ]] && LAST_COPY_OK=1
      ;;
  esac
  return 0
}

copy_meta_file() {
  local src="$1" dest_dir="$2"
  local dest="$dest_dir/$(basename -- "$src")"
  LAST_COPY_DEST="$dest"
  LAST_COPY_POLICY="none"
  LAST_COPY_CHANGED=0
  LAST_COPY_OK=0
  cp -Lf "$src" "$dest" 2>/dev/null || true
  [[ -f "$dest" ]] && LAST_COPY_OK=1
  return 0
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
  "/usr/local/share/linux_maint/BUILD_INFO" \
  "/usr/local/share/linux_maint/VERSION" \
  "/usr/share/linux_maint/BUILD_INFO" \
  "/usr/share/linux_maint/VERSION" \
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
if [[ "$hash_enabled" -eq 1 ]]; then
  progress_total=$((progress_total + 1))
fi
if [[ "$integrity_enabled" -eq 1 ]]; then
  progress_total=$((progress_total + 1))
fi
if [[ "$gpg_enabled" -eq 1 ]]; then
  progress_total=$((progress_total + 1))
fi

mkdir -p "$OUTDIR"
workdir="$(mktemp -d -p "$TMPDIR")"

bundle_root="$workdir/bundle"
mkdir -p "$bundle_root"

# --- Logs ---
mkdir -p "$bundle_root/logs"

for f in "${log_files[@]}"; do
  [[ -n "$f" ]] || continue
  copy_log "$f" "$bundle_root/logs"
  if [[ "$LAST_COPY_OK" -eq 1 ]]; then
    record_bundle_copy "logs" "$f" "$LAST_COPY_DEST" "$LAST_COPY_POLICY" "$LAST_COPY_CHANGED"
  fi
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
    dest_file="$dest_dir/$(basename -- "$rel")"
    mkdir -p "$dest_dir"
    copy_config_file "$f" "$dest_file"
    if [[ "$LAST_COPY_OK" -eq 1 ]]; then
      record_bundle_copy "config" "$f" "$LAST_COPY_DEST" "$LAST_COPY_POLICY" "$LAST_COPY_CHANGED"
    fi
    progress_step "config:$(basename -- "$rel")"
  done
fi

# --- Build info ---
mkdir -p "$bundle_root/meta"
for f in "${meta_files[@]}"; do
  copy_meta_file "$f" "$bundle_root/meta"
  if [[ "$LAST_COPY_OK" -eq 1 ]]; then
    record_bundle_copy "meta" "$f" "$LAST_COPY_DEST" "$LAST_COPY_POLICY" "$LAST_COPY_CHANGED"
  fi
  progress_step "meta:$(basename -- "$f")"
done

# --- State dir (optional, small files only) ---
if [[ "${#state_files[@]}" -gt 0 ]]; then
  mkdir -p "$bundle_root/state"
  for f in "${state_files[@]}"; do
    copy_log "$f" "$bundle_root/state"
    if [[ "$LAST_COPY_OK" -eq 1 ]]; then
      record_bundle_copy "state" "$f" "$LAST_COPY_DEST" "$LAST_COPY_POLICY" "$LAST_COPY_CHANGED"
    fi
    progress_step "state:$(basename -- "$f")"
  done
fi

copied_logs="$(awk -F'\t' '$1=="logs"{seen[$2]=1} END{for (k in seen) c++; print c+0}' "$bundle_rows")"
copied_config="$(awk -F'\t' '$1=="config"{seen[$2]=1} END{for (k in seen) c++; print c+0}' "$bundle_rows")"
copied_state="$(awk -F'\t' '$1=="state"{seen[$2]=1} END{for (k in seen) c++; print c+0}' "$bundle_rows")"
copied_meta="$(awk -F'\t' '$1=="meta"{seen[$2]=1} END{for (k in seen) c++; print c+0}' "$bundle_rows")"
copied_total="$(awk -F'\t' 'NF{seen[$2]=1} END{for (k in seen) c++; print c+0}' "$bundle_rows")"
redacted_files="$(awk -F'\t' '$4!="none"{seen[$2]=1} END{for (k in seen) c++; print c+0}' "$bundle_rows")"
changed_redactions="$(awk -F'\t' '$4!="none" && $5=="1"{seen[$2]=1} END{for (k in seen) c++; print c+0}' "$bundle_rows")"

redact_state="disabled"
if redact_enabled; then
  redact_state="enabled"
fi
hash_state="disabled"
if [[ "$hash_enabled" -eq 1 ]]; then
  hash_state="enabled"
fi
gpg_state="disabled"
if [[ "$gpg_enabled" -eq 1 ]]; then
  gpg_state="enabled"
fi
integrity_state="skipped"
if [[ "$integrity_enabled" -eq 1 ]]; then
  integrity_state="enabled"
fi
generated_meta="bundle_meta.txt,bundle_manifest.txt,redaction_report.txt,support_handoff.txt"
if [[ "$integrity_enabled" -eq 1 ]]; then
  generated_meta="${generated_meta},bundle_integrity.txt"
fi
if [[ "$hash_enabled" -eq 1 ]]; then
  generated_meta="${generated_meta},bundle_hashes.txt"
fi

cat > "$bundle_root/meta/bundle_meta.txt" <<EOF
created_utc=$TS
redaction=$redact_state
hashes=$hash_state
gpg=$gpg_state
log_dir=$LOG_DIR
cfg_dir=$CFG_DIR
state_dir=$STATE_DIR
repo_root=${REPO_ROOT:-}
EOF

cat > "$bundle_root/meta/bundle_manifest.txt" <<EOF
created_utc=$TS
log_dir=$LOG_DIR
cfg_dir=$CFG_DIR
state_dir=$STATE_DIR
repo_root=${REPO_ROOT:-}
copied_logs=$copied_logs
copied_config=$copied_config
copied_state=$copied_state
copied_meta=$copied_meta
copied_total=$copied_total
redaction_logs=$redact_state
config_redaction=always-for-conf-txt-csv
redacted_files=$redacted_files
changed_by_redaction=$changed_redactions
hash_manifest=$hash_state
integrity_manifest=$integrity_state
gpg=$gpg_state
generated_meta=$generated_meta
EOF

{
  echo "created_utc=$TS"
  echo "log_redaction=$redact_state"
  echo "config_redaction=always-for-conf-txt-csv"
  echo "redacted_files=$redacted_files"
  echo "changed_by_redaction=$changed_redactions"
  echo "---"
  if [[ -s "$redaction_rows" ]]; then
    awk -F'\t' '!seen[$1 FS $2 FS $4 FS $5]++ {printf "section=%s path=%s source=%s policy=%s changed=%s\n", $1, $2, $3, $4, ($5=="1" ? "yes" : "no")}' "$redaction_rows"
  else
    echo "no_redacted_files=1"
  fi
} > "$bundle_root/meta/redaction_report.txt"

cat > "$bundle_root/meta/support_handoff.txt" <<'EOF'
linux-maint support handoff

1. Share the bundle artifact with the escalation target.
2. Include a short human summary:
   linux-maint report --short
3. Include machine-readable context if requested:
   linux-maint export --json
4. After extracting the bundle, start with:
   meta/bundle_manifest.txt
   meta/bundle_meta.txt
   meta/redaction_report.txt
   meta/bundle_integrity.txt
   meta/bundle_hashes.txt
5. Verify the transferred artifact:
   sha256sum <bundle.tar.gz>
6. If you received a GPG-encrypted bundle:
   gpg --decrypt --output bundle.tar.gz <bundle.tar.gz.gpg>
EOF

# --- Bundle integrity manifest (size + sha256 per file) ---
if [[ "$integrity_enabled" -eq 1 ]]; then
  integrity_file="$bundle_root/meta/bundle_integrity.txt"
  (cd "$bundle_root" && \
    find . -type f ! -path './meta/bundle_integrity.txt' -print0 2>/dev/null | \
    sort -z | while IFS= read -r -d '' f; do
      size="$(stat -c %s "$f" 2>/dev/null || echo 0)"
      sum="$(sha256sum "$f" 2>/dev/null | awk '{print $1}')"
      rel="${f#./}"
      printf '%s  %s  %s\n' "$sum" "$size" "$rel"
    done) > "$integrity_file" 2>/dev/null || true
  progress_step "integrity"
else
  echo "WARN: sha256sum/stat not found; integrity manifest skipped" >&2
fi

# --- Bundle hashes (optional) ---
if [[ "$hash_enabled" -eq 1 ]]; then
  if command -v sha256sum >/dev/null 2>&1; then
    hash_file="$bundle_root/meta/bundle_hashes.txt"
    (cd "$bundle_root" && \
      find . -type f ! -path './meta/bundle_hashes.txt' -print0 2>/dev/null | \
      sort -z | xargs -0 sha256sum) > "$hash_file" 2>/dev/null || true
  else
    echo "WARN: sha256sum not found; hash list skipped" >&2
  fi
  progress_step "hashes"
fi

out_name="${NAME_PREFIX}-${TS}.tar.gz"
out_path="$OUTDIR/$out_name"

tar -C "$bundle_root" -czf "$out_path" .
progress_step "compress"

if [[ "$gpg_enabled" -eq 1 ]]; then
  gpg_out="${out_path}.gpg"
  if gpg --batch --yes --recipient "$gpg_recipient" --output "$gpg_out" --encrypt "$out_path"; then
    progress_step "gpg"
    if [[ "$gpg_keep_plaintext" -ne 1 ]]; then
      rm -f "$out_path" 2>/dev/null || true
    fi
    out_path="$gpg_out"
  else
    echo "ERROR: gpg encryption failed" >&2
    exit 2
  fi
fi

progress_done

echo "$out_path"
