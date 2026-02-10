#!/usr/bin/env bash
set -euo pipefail

# Wrapper to run ShellCheck using the repo's single source of truth: .shellcheckrc
#
# Usage:
#   tools/shellcheck_wrapper.sh -x path/to/file.sh [...]
#   tools/shellcheck_wrapper.sh -x monitors/*.sh

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
RCFILE="$ROOT_DIR/.shellcheckrc"

if [[ ! -f "$RCFILE" ]]; then
  echo "ERROR: missing $RCFILE" >&2
  exit 2
fi

# Extract exclude=... from .shellcheckrc
EXCLUDES="$(awk -F= '/^exclude=/{print $2; exit}' "$RCFILE" | tr -d '[:space:]')"

args=("$@")

# Only add --exclude if configured
if [[ -n "${EXCLUDES:-}" ]]; then
  shellcheck --exclude="$EXCLUDES" "${args[@]}"
else
  shellcheck "${args[@]}"
fi
