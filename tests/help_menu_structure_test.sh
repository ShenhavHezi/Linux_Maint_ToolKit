#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

out="$(NO_COLOR=1 bash "$LM" help menu 2>&1 || true)"

printf '%s\n' "$out" | grep -q '^Repo vs installed:$' || {
  echo "help menu missing repo-vs-installed section" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q 'repo mode:      linux-maint menu' || {
  echo "help menu missing repo-mode guidance" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q 'installed mode: sudo linux-maint menu' || {
  echo "help menu missing installed-mode guidance" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q '^Key flags:$' || {
  echo "help menu missing key flags section" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q 'Main sections:' || {
  echo "help menu missing main section overview" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -Eq 'Quickstart[[:space:]]+first setup, guided rescue, and escalation workflows' || {
  echo "help menu missing quickstart summary" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -Eq 'Overview[[:space:]]+fleet health, latest problems, and the fast answer' || {
  echo "help menu missing overview summary" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -Eq 'Triage[[:space:]]+investigate failures and repair safely' || {
  echo "help menu missing triage summary" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -Eq 'Share[[:space:]]+report, export, bundle, and reference docs in one place' || {
  echo "help menu missing share summary" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q 'Best path by task:' || {
  echo "help menu missing best path section" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -Eq 'First day with the tool\?[[:space:]]+Quickstart -> first setup' || {
  echo "help menu missing quickstart path guidance" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q 'Need to recover quickly?       Triage -> incident or doctor' || {
  echo "help menu missing recovery path guidance" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q 'Need to share data?            Share -> report, export JSON, or pack logs' || {
  echo "help menu missing share path guidance" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q 'Global gum controls:' || {
  echo "help menu missing gum controls section" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q 'Quickstart bootstrap:' || {
  echo "help menu missing quickstart bootstrap section" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q 'first_setup guides init, config review, check, plan, and starter baselines' || {
  echo "help menu missing first_setup bootstrap guidance" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q 'Workflow notes:' || {
  echo "help menu missing workflow notes section" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q 'Triage keeps drilldown, logs, doctor, and focused recovery in one workspace' || {
  echo "help menu missing triage workflow guidance" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q 'arrows         move through the chooser' || {
  echo "help menu missing arrow-navigation guidance" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q 'Search         smart command palette (search by names, aliases, task words)' || {
  echo "help menu missing command palette guidance" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q 'examples: first run, triage, bundle, report, logs, doctor' || {
  echo "help menu missing command palette examples" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q 'Optional letter shortcuts remain available when enabled' || {
  echo "help menu missing optional shortcut guidance" >&2
  echo "$out" >&2
  exit 1
}
printf '%s\n' "$out" | grep -q 'LM_TUI_CONFIRM_RISKY=1|0' || {
  echo "help menu missing env var guidance" >&2
  echo "$out" >&2
  exit 1
}

echo "help menu structure ok"
