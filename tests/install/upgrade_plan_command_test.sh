#!/usr/bin/env bash
set -euo pipefail
TMPDIR="${TMPDIR:-/tmp}"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
CURRENT_VERSION="$(head -n 1 "$ROOT_DIR/VERSION" | tr -d '[:space:]')"
workdir="$(mktemp -d -p "$TMPDIR")"
trap 'rm -rf "$workdir"' EXIT

. "$ROOT_DIR/tests/testlib.sh"

release_repo="$workdir/release_repo"
testlib_copy_repo_worktree "$release_repo"
testlib_build_release_tarball "$release_repo"

tarball="$(find "$release_repo/dist" -maxdepth 1 -type f -name "Linux_Maint_ToolKit-v${CURRENT_VERSION}-*.tgz" | head -n 1)"
[[ -f "$tarball" ]] || {
  echo "expected release tarball for version $CURRENT_VERSION" >&2
  exit 1
}

prefix="$workdir/prefix"
cfg="$workdir/etc_linux_maint"
logdir="$workdir/var_log_health"
statedir="$workdir/var_lib_linux_maint"
systemd_dir="$workdir/systemd"
logrotate_file="$workdir/logrotate/linux-maint"

(
  cd "$ROOT_DIR"
  LM_INSTALL_SKIP_ROOT_CHECK=1 \
  LM_INSTALL_CFG_DIR="$cfg" \
  LM_INSTALL_LOG_DIR="$logdir" \
  LM_INSTALL_STATE_DIR="$statedir" \
  bash ./install.sh --prefix "$prefix" >/dev/null
)

mkdir -p "$cfg/conf.d" "$systemd_dir" "$(dirname "$logrotate_file")"
printf '%s\n' localhost > "$cfg/servers.txt"
: > "$cfg/excluded.txt"
: > "$cfg/services.txt"
printf 'host,tags,role,env\nlocalhost,web;ops,web,prod\n' > "$cfg/inventory_meta.csv"
printf 'marker=keep\n' > "$cfg/conf.d/site.conf"
printf '[Unit]\nDescription=test\n' > "$systemd_dir/linux-maint.service"
printf '[Timer]\nOnCalendar=*-*-* 02:15:00\n' > "$systemd_dir/linux-maint.timer"
printf '# logrotate test\n' > "$logrotate_file"

json_out="$(
  LM_INSTALL_SYSTEMD_DIR="$systemd_dir" \
  LM_INSTALL_LOGROTATE_FILE="$logrotate_file" \
  "$prefix/bin/linux-maint" upgrade "$tarball" \
    --plan \
    --json \
    --sums "$release_repo/dist/SHA256SUMS" \
    --rollback-tarball "$tarball" \
    --cfg-dir "$cfg" \
    --log-dir "$logdir" \
    --state-dir "$statedir" \
    --with-timer \
    --with-logrotate
)"

printf '%s' "$json_out" | python3 "$ROOT_DIR/tools/json_schema_validate.py" "$ROOT_DIR/docs/schemas/upgrade_plan.json"

CURRENT_VERSION="$CURRENT_VERSION" CFG_DIR="$cfg" SYSTEMD_DIR="$systemd_dir" LOGROTATE_FILE="$logrotate_file" python3 - <<'PY' "$json_out"
import json
import os
import sys

payload = json.loads(sys.argv[1])

assert payload["upgrade_plan_json_contract_version"] == 1, payload
assert payload["current_version"] == os.environ["CURRENT_VERSION"], payload
assert payload["target_version"] == os.environ["CURRENT_VERSION"], payload
assert payload["relation"] == "same", payload
assert payload["checks"]["release_notes_found"] is True, payload
assert payload["checks"]["upgrade_guide_found"] is True, payload
assert payload["checks"]["install_sh_found"] is True, payload
assert payload["checks"]["sums_supplied"] is True, payload
assert payload["checks"]["rollback_tarball_supplied"] is True, payload
assert payload["config"]["cfg_dir"] == os.environ["CFG_DIR"], payload
assert payload["config"]["exists"] is True, payload
assert payload["config"]["readable"] is True, payload
assert payload["config"]["inventory_meta_present"] is True, payload
assert payload["config"]["conf_d_files"] >= 1, payload
assert payload["service"]["systemd_unit_dir"] == os.environ["SYSTEMD_DIR"], payload
assert payload["service"]["current_service_file"] is True, payload
assert payload["service"]["current_timer_file"] is True, payload
assert payload["service"]["with_timer_requested"] is True, payload
assert payload["service"]["planned_effect"] == "install_or_refresh_timer", payload
assert payload["logrotate"]["path"] == os.environ["LOGROTATE_FILE"], payload
assert payload["logrotate"]["current_file"] is True, payload
assert payload["logrotate"]["with_logrotate_requested"] is True, payload
assert payload["logrotate"]["planned_effect"] == "install_or_refresh_logrotate", payload
assert payload["rollback_readiness"]["state"] == "ready", payload
assert payload["rollback_readiness"]["score"] == 3, payload
assert payload["rollback_readiness"]["checksums_supplied"] is True, payload
assert payload["rollback_readiness"]["rollback_artifact_supplied"] is True, payload
assert payload["warnings"], payload
assert payload["result"] == "WARN", payload
PY

human_out="$(
  LM_INSTALL_SYSTEMD_DIR="$systemd_dir" \
  LM_INSTALL_LOGROTATE_FILE="$logrotate_file" \
  "$prefix/bin/linux-maint" upgrade "$tarball" \
    --plan \
    --sums "$release_repo/dist/SHA256SUMS" \
    --rollback-tarball "$tarball" \
    --cfg-dir "$cfg" \
    --log-dir "$logdir" \
    --state-dir "$statedir" \
    --with-timer \
    --with-logrotate
)"

for required in \
  '^Config impact:$' \
  '^Service impact:$' \
  '^Logrotate impact:$' \
  '^Rollback readiness:$' \
  '^== Guidance ==$' \
  '^== Summary ==$' \
  '^upgrade plan warn$'
do
  printf '%s\n' "$human_out" | grep -q "$required" || {
    echo "upgrade plan output missing pattern: $required" >&2
    echo "$human_out" >&2
    exit 1
  }
done

printf '%s\n' "$human_out" | grep -q '^checks: release_notes=ok upgrade_guide=ok install_sh=ok sums=yes sig=no rollback_artifact=yes$' || {
  echo "upgrade plan checks line missing" >&2
  echo "$human_out" >&2
  exit 1
}

printf '%s\n' "$human_out" | grep -q '^- planned_effect=install_or_refresh_timer$' || {
  echo "upgrade plan service effect missing" >&2
  echo "$human_out" >&2
  exit 1
}

printf '%s\n' "$human_out" | grep -q '^- state=ready score=3/3$' || {
  echo "upgrade plan rollback readiness missing" >&2
  echo "$human_out" >&2
  exit 1
}

echo "upgrade plan command ok"
