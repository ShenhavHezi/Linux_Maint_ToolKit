#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
quickref="$ROOT_DIR/docs/QUICK_REFERENCE.md"
troubleshooting="$ROOT_DIR/docs/troubleshooting.md"
faq="$ROOT_DIR/docs/FAQ.md"

grep -F -q "Examples below use repo-mode form: \`linux-maint ...\`" "$quickref" || {
  echo "quick reference missing repo-mode example guidance" >&2
  exit 1
}
grep -F -q 'Installed mode:' "$quickref" || {
  echo "quick reference missing installed-mode workflow" >&2
  exit 1
}
grep -F -q '<cfg_dir>/hosts_drain.txt' "$quickref" || {
  echo "quick reference missing cfg-dir placeholder for drain file" >&2
  exit 1
}
grep -F -q 'LM_PLUGIN_TRUST_POLICY_FILE=<cfg_dir>/plugin_trust_policy.json' "$quickref" || {
  echo "quick reference missing cfg-dir placeholder for plugin trust policy" >&2
  exit 1
}
grep -F -q '.logs/full_health_monitor_latest.log' "$quickref" || {
  echo "quick reference missing repo artifact paths" >&2
  exit 1
}

grep -F -q 'Run and review (repo mode)' "$troubleshooting" || {
  echo "troubleshooting missing repo-mode run path" >&2
  exit 1
}
grep -F -q 'Run and review (installed mode)' "$troubleshooting" || {
  echo "troubleshooting missing installed-mode run path" >&2
  exit 1
}
grep -F -q '<cfg_dir>/network_targets.txt' "$troubleshooting" || {
  echo "troubleshooting missing cfg-dir placeholder for expected skips" >&2
  exit 1
}
grep -F -q '.logs/' "$troubleshooting" || {
  echo "troubleshooting missing repo log-dir guidance" >&2
  exit 1
}

grep -F -q "repo mode, or \`sudo linux-maint init\` in installed mode" "$faq" || {
  echo "faq config_missing answer missing mode-aware init guidance" >&2
  exit 1
}

echo "operator docs mode aware ok"
