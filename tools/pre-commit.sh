#!/usr/bin/env bash
# tools/pre-commit.sh - Local checks before committing (optional)
# Runs a subset of checks enforced by CI.

set -euo pipefail

echo "[pre-commit] Running shellcheck..."
if ! command -v shellcheck >/dev/null 2>&1; then
  echo "shellcheck not found. Install it (e.g. apt-get install shellcheck / dnf install ShellCheck)" >&2
  exit 1
fi

# Use repo ShellCheck policy (single source of truth: .shellcheckrc)
./tools/shellcheck_wrapper.sh -x -- ./*.sh ./install.sh ./bin/linux-maint ./tools/*.sh

# README tuning knob sync is best-effort. Older README versions may not have
# the exact section header expected by tools/update_readme_defaults.py.
if grep -q '^## Tuning knobs (common configuration variables)' README.md && \
   grep -q '^## Exit codes (for automation)' README.md; then
  echo "[pre-commit] Verifying README tuning knobs are in sync..."
  python3 tools/update_readme_defaults.py
  git diff --exit-code README.md
else
  echo "[pre-commit] Skipping README tuning knob sync (section not present)."
fi

echo "[pre-commit] OK"
