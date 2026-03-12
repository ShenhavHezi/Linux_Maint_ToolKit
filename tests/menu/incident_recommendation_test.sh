#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

source "$LM" >/dev/null 2>&1

[[ "$(tui_incident_recommendation_key ssh_unreachable network_monitor)" == "connectivity" ]] || {
  echo "ssh_unreachable should map to connectivity" >&2
  exit 1
}
[[ "$(tui_incident_recommendation_key config_missing service_monitor)" == "config" ]] || {
  echo "config_missing should map to config" >&2
  exit 1
}
[[ "$(tui_incident_recommendation_key service_failed service_monitor)" == "service" ]] || {
  echo "service_failed should map to service" >&2
  exit 1
}
[[ "$(tui_incident_recommendation_key updates_pending patch_monitor)" == "patching" ]] || {
  echo "updates_pending should map to patching" >&2
  exit 1
}
[[ "$(tui_incident_recommendation_key runtime_exceeded health_monitor)" == "runtime" ]] || {
  echo "runtime_exceeded should map to runtime" >&2
  exit 1
}

summary="$(tui_incident_recommendation_summary ssh_unreachable network_monitor web-01)"
printf '%s\n' "$summary" | grep -q 'connectivity triage' || {
  echo "incident recommendation summary missing connectivity text" >&2
  echo "$summary" >&2
  exit 1
}

echo "incident recommendation ok"
