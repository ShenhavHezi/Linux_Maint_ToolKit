#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export LINUX_MAINT_LIB="$ROOT_DIR/lib/linux_maint.sh"

# shellcheck disable=SC1090
. "$LINUX_MAINT_LIB"

export LM_LOGFILE="/tmp/linux_maint_redaction_test.log"
rm -f "$LM_LOGFILE"

# Default: no redaction
unset LM_REDACT_LOGS || true
lm_info "token=ABC123 password=hunter2 Authorization: Bearer XYZ"
if grep -q 'REDACTED' "$LM_LOGFILE"; then
  echo "FAIL: unexpected redaction when LM_REDACT_LOGS is off" >&2
  exit 1
fi

# Enabled: redact
export LM_REDACT_LOGS=1
lm_info "token=ABC123 password=hunter2 api_key=K Authorization: Bearer XYZ session_id=sess-123 x-auth-token=tok-999 id_token=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.aaaaaaaaaaaa.bbbbbbbbbbbb"
if ! grep -q 'token=REDACTED' "$LM_LOGFILE"; then
  echo "FAIL: token not redacted" >&2
  cat "$LM_LOGFILE" >&2
  exit 1
fi
if ! grep -q 'password=REDACTED' "$LM_LOGFILE"; then
  echo "FAIL: password not redacted" >&2
  cat "$LM_LOGFILE" >&2
  exit 1
fi
if ! grep -q 'Authorization: REDACTED' "$LM_LOGFILE"; then
  echo "FAIL: Authorization not redacted" >&2
  cat "$LM_LOGFILE" >&2
  exit 1
fi

if ! grep -q 'session_id=REDACTED' "$LM_LOGFILE"; then
  echo "FAIL: session_id not redacted" >&2
  cat "$LM_LOGFILE" >&2
  exit 1
fi
if ! grep -q 'x-auth-token=REDACTED' "$LM_LOGFILE"; then
  echo "FAIL: x-auth-token not redacted" >&2
  cat "$LM_LOGFILE" >&2
  exit 1
fi
if ! grep -q 'id_token=REDACTED' "$LM_LOGFILE"; then
  echo "FAIL: id_token key-value not redacted" >&2
  cat "$LM_LOGFILE" >&2
  exit 1
fi
lm_info "note=sessionization complete for operator"
if ! grep -q "sessionization complete" "$LM_LOGFILE"; then
  echo "FAIL: non-secret context unexpectedly changed" >&2
  cat "$LM_LOGFILE" >&2
  exit 1
fi

echo "log redaction ok"
