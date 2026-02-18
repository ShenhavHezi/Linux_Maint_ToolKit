#!/usr/bin/env bash
set -euo pipefail

# Run a minimal set of commands to ensure the repo can execute without installation.
# This should be safe on GitHub Actions runners.

# Exit code semantics (keep stable; documented for CI and dark-site use):
#   0 = ok
#   3 = skipped optional checks (e.g., sudo-gated tests not run)
#   other non-zero = failure (a required smoke sub-test failed)

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_TMP="${LM_TEST_TMPDIR:-$ROOT_DIR/.tmp_test}"
mkdir -p "$TEST_TMP"
export TMPDIR="$TEST_TMP"

SMOKE_OK=0
SMOKE_SKIPPED_OPTIONAL=3

export LINUX_MAINT_LIB="$ROOT_DIR/lib/linux_maint.sh"
export LM_LOCKDIR="${TMPDIR}"
export LM_LOGFILE=${TMPDIR}/linux_maint.log
export LM_EMAIL_ENABLED=false

skipped_optional=0
SMOKE_PROFILE="${SMOKE_PROFILE:-full}"

run_required(){
  local label="$1"; shift
  if ! "$@" >/dev/null; then
    echo "FAIL: $label" >&2
    return 1
  fi
}

# Basic help/version checks
run_required "linux-maint help" bash "$ROOT_DIR/bin/linux-maint" help

# Preflight should not hard-fail just because optional tools are missing
LM_LOGFILE=${TMPDIR}/preflight_check.log LM_LOCKDIR="${TMPDIR}" bash "$ROOT_DIR/monitors/preflight_check.sh" >/dev/null || true

# Validate config formats (should succeed even if config files are absent; best-effort)
LM_LOGFILE=${TMPDIR}/config_validate.log LM_LOCKDIR="${TMPDIR}" bash "$ROOT_DIR/monitors/config_validate.sh" >/dev/null || true

# lm_for_each_host_rc aggregation test
run_required "lm_for_each_host_rc_test" bash "$ROOT_DIR/tests/lm_for_each_host_rc_test.sh"

# Monitor exit-code policy (local-only)
run_required "monitor_exit_codes_test" bash "$ROOT_DIR/tests/monitor_exit_codes_test.sh"
run_required "lm_mktemp_fallback_test" bash "$ROOT_DIR/tests/lm_mktemp_fallback_test.sh"

# Monitor summary emission contract (each monitor must emit monitor= lines)
run_required "monitor_summary_emission_test" bash "$ROOT_DIR/tests/monitor_summary_emission_test.sh"
run_required "summary_diff_canonicalization_test" bash "$ROOT_DIR/tests/summary_diff_canonicalization_test.sh"
run_required "quick_check_make_target_test" bash "$ROOT_DIR/tests/quick_check_make_target_test.sh"
run_required "wrapper_runtime_summary_test" bash "$ROOT_DIR/tests/wrapper_runtime_summary_test.sh"
run_required "runtimes_command_test" bash "$ROOT_DIR/tests/runtimes_command_test.sh"
run_required "runtime_warn_threshold_test" bash "$ROOT_DIR/tests/runtime_warn_threshold_test.sh"

# Security lint: forbid eval usage
run_required "no_eval_lint" bash "$ROOT_DIR/tests/no_eval_lint.sh"
run_required "secret_scan_lint_test" bash "$ROOT_DIR/tests/secret_scan_lint_test.sh"

# Dependency behavior example: network_monitor should emit missing_dependency when curl missing
run_required "network_monitor_missing_curl_test" bash "$ROOT_DIR/tests/network_monitor_missing_curl_test.sh"
run_required "nfs_reason_unreachable_test" bash "$ROOT_DIR/tests/nfs_reason_unreachable_test.sh"
run_required "nfs_tempfile_cleanup_on_timeout_test" bash "$ROOT_DIR/tests/nfs_tempfile_cleanup_on_timeout_test.sh"

# Fleet safety: --dry-run must not invoke ssh
run_required "dry_run_no_ssh_test" bash "$ROOT_DIR/tests/dry_run_no_ssh_test.sh"

if [[ "$SMOKE_PROFILE" != "compat" ]]; then
  # Per-monitor timeout overrides (wrapper-level)
  run_required "per_monitor_timeout_override_test" bash "$ROOT_DIR/tests/per_monitor_timeout_override_test.sh"

  # Summary noise guardrail (wrapper-level)
  run_required "summary_noise_lint" bash "$ROOT_DIR/tests/summary_noise_lint.sh"
  run_required "summary_budget_lint_fixture_test" bash "$ROOT_DIR/tests/summary_budget_lint_fixture_test.sh"
  run_required "wrapper_fallback_paths_test" bash "$ROOT_DIR/tests/wrapper_fallback_paths_test.sh"

  # Prometheus textfile output (best-effort; wrapper-level)
  run_required "prom_textfile_output_test" bash "$ROOT_DIR/tests/prom_textfile_output_test.sh"
fi

if [[ "$SMOKE_PROFILE" != "compat" ]]; then
# Resource monitor (local)
run_required "resource_monitor_basic_test" bash "$ROOT_DIR/tests/resource_monitor_basic_test.sh"
run_required "service_monitor_failed_units_test" bash "$ROOT_DIR/tests/service_monitor_failed_units_test.sh"
run_required "disk_trend_inode_trend_test" bash "$ROOT_DIR/tests/disk_trend_inode_trend_test.sh"
run_required "ntp_chrony_parsing_test" bash "$ROOT_DIR/tests/ntp_chrony_parsing_test.sh"
run_required "ntp_chrony_parsing_variants_test" bash "$ROOT_DIR/tests/ntp_chrony_parsing_variants_test.sh"
run_required "log_spike_fixture_test" bash "$ROOT_DIR/tests/log_spike_fixture_test.sh"
run_required "cert_monitor_scan_dir_test" bash "$ROOT_DIR/tests/cert_monitor_scan_dir_test.sh"
run_required "verify_install_test" bash "$ROOT_DIR/tests/verify_install_test.sh"
run_required "init_minimal_idempotent_test" bash "$ROOT_DIR/tests/init_minimal_idempotent_test.sh"
run_required "pack_logs_test" bash "$ROOT_DIR/tests/pack_logs_test.sh"
run_required "release_verify_test" bash "$ROOT_DIR/tests/release_verify_test.sh"
run_required "doctor_offline_hints_test" bash "$ROOT_DIR/tests/doctor_offline_hints_test.sh"
run_required "doctor_json_test" bash "$ROOT_DIR/tests/doctor_json_test.sh"
run_required "doctor_json_schema_test" bash "$ROOT_DIR/tests/doctor_json_schema_test.sh"
run_required "explain_reason_test" bash "$ROOT_DIR/tests/explain_reason_test.sh"
run_required "status_reason_rollup_test" bash "$ROOT_DIR/tests/status_reason_rollup_test.sh"
run_required "status_json_compat_test" bash "$ROOT_DIR/tests/status_json_compat_test.sh"
run_required "status_json_schema_test" bash "$ROOT_DIR/tests/status_json_schema_test.sh"
run_required "export_json_test" bash "$ROOT_DIR/tests/export_json_test.sh"
run_required "status_since_test" bash "$ROOT_DIR/tests/status_since_test.sh"
run_required "trend_command_test" bash "$ROOT_DIR/tests/trend_command_test.sh"
fi

# Sudo-gated tests
if sudo -n true >/dev/null 2>&1; then
  bash "$ROOT_DIR/tests/wrapper_artifacts_test.sh" >/dev/null
  bash "$ROOT_DIR/tests/status_json_test.sh" >/dev/null
  bash "$ROOT_DIR/tests/status_quiet_test.sh" >/dev/null
  bash "$ROOT_DIR/tests/status_contract_test.sh" >/dev/null
  bash "$ROOT_DIR/tests/summary_reason_lint.sh" >/dev/null
  run_required "prom_textfile_output_test" bash "$ROOT_DIR/tests/prom_textfile_output_test.sh"
else
  skipped_optional=1
  echo "NOTE: skipping sudo-gated tests (no passwordless sudo)" >&2
fi

if [[ "$skipped_optional" -eq 1 ]]; then
  echo "smoke ok (optional checks skipped)"
  exit "$SMOKE_SKIPPED_OPTIONAL"
fi

echo "smoke ok"
exit "$SMOKE_OK"
