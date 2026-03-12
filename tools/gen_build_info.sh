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

{
  printf 'format=linux_maint_build_info\n'
  printf 'schema_version=1\n'
  printf 'version=%s\n' "$VER"
  printf 'commit=%s\n' "$SHA"
  printf 'build_time_utc=%s\n' "$STAMP"
  [[ -n "$CI_RUN_ID" ]] && printf 'ci_run_id=%s\n' "$CI_RUN_ID"
  [[ -n "$CI_RUN_ATTEMPT" ]] && printf 'ci_run_attempt=%s\n' "$CI_RUN_ATTEMPT"
  [[ -n "$CI_REF" ]] && printf 'ci_ref=%s\n' "$CI_REF"
  [[ -n "$CI_SHA" ]] && printf 'ci_sha=%s\n' "$CI_SHA"
} > "$ROOT/BUILD_INFO"

echo "Wrote $ROOT/BUILD_INFO" >&2
