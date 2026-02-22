#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$ROOT_DIR/lib/linux_maint.sh"

out_default="$(bash -c 'unset LM_SSH_OPTS; unset LM_SSH_KNOWN_HOSTS_MODE; . "$0"; echo "$LM_SSH_OPTS"' "$LIB")"
printf '%s\n' "$out_default" | grep -q 'StrictHostKeyChecking=accept-new'

out_strict="$(LM_SSH_KNOWN_HOSTS_MODE=strict bash -c 'unset LM_SSH_OPTS; . "$0"; echo "$LM_SSH_OPTS"' "$LIB")"
printf '%s\n' "$out_strict" | grep -q 'StrictHostKeyChecking=yes'

out_override="$(LM_SSH_OPTS='-o StrictHostKeyChecking=accept-new' LM_SSH_KNOWN_HOSTS_MODE=strict bash -c '. "$0"; echo "$LM_SSH_OPTS"' "$LIB")"
printf '%s\n' "$out_override" | grep -q 'StrictHostKeyChecking=accept-new'

printf '%s\n' "ssh known_hosts mode ok"
