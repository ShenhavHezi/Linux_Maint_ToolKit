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
lm_info "token=ABC123 password=hunter2 api_key=K Authorization: Bearer XYZ"
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

echo "log redaction ok"
