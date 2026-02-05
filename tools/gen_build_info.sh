#!/usr/bin/env bash
set -euo pipefail

# Generate BUILD_INFO deterministically for packaging/installs.
# Uses VERSION file if present; otherwise falls back.

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
VER="0.0.0"
if [[ -f "$ROOT/VERSION" ]]; then
  VER="$(tr -d '\r' < "$ROOT/VERSION" | head -n 1 | awk '{print $1}')"
fi

SHA="unknown"
if command -v git >/dev/null 2>&1 && [[ -d "$ROOT/.git" ]]; then
  SHA="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
fi

STAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Optional CI metadata
CI_RUN_ID="${GITHUB_RUN_ID:-${CI_RUN_ID:-}}"
CI_RUN_ATTEMPT="${GITHUB_RUN_ATTEMPT:-${CI_RUN_ATTEMPT:-}}"
CI_REF="${GITHUB_REF:-${CI_REF:-}}"
CI_SHA="${GITHUB_SHA:-${CI_SHA:-}}"

cat > "$ROOT/BUILD_INFO" <<EOF
format=linux_maint_build_info
schema_version=1
version=$VER
commit=$SHA
build_time_utc=$STAMP
ci_run_id=$CI_RUN_ID
ci_run_attempt=$CI_RUN_ATTEMPT
ci_ref=$CI_REF
ci_sha=$CI_SHA
EOF

echo "Wrote $ROOT/BUILD_INFO" >&2
