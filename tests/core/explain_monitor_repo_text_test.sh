#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LM="$ROOT_DIR/bin/linux-maint"

cfg_out="$(bash "$LM" explain monitor config_validate)"
printf '%s\n' "$cfg_out" | grep -q '^purpose=Validate config file formats$' || {
  echo "config_validate explain purpose should be mode-neutral" >&2
  echo "$cfg_out" >&2
  exit 1
}
printf '%s\n' "$cfg_out" | grep -q '/etc/linux_maint' && {
  echo "config_validate explain should not hardcode /etc/linux_maint" >&2
  echo "$cfg_out" >&2
  exit 1
}

echo "explain monitor repo text ok"
