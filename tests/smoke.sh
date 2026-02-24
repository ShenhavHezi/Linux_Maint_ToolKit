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
export LC_ALL="${LC_ALL:-C}"
export TZ="${TZ:-UTC}"

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
run_required "lm_summary_strict_test" bash "$ROOT_DIR/tests/lm_summary_strict_test.sh"
run_required "lm_summary_allowlist_test" bash "$ROOT_DIR/tests/lm_summary_allowlist_test.sh"
run_required "lm_time_test" bash "$ROOT_DIR/tests/lm_time_test.sh"
run_required "lm_ssh_allowlist_test" bash "$ROOT_DIR/tests/lm_ssh_allowlist_test.sh"
run_required "hosts_parse_test" bash "$ROOT_DIR/tests/hosts_parse_test.sh"
run_required "seed_known_hosts_test" bash "$ROOT_DIR/tests/seed_known_hosts_test.sh"
run_required "lm_ssh_opts_guard_test" bash "$ROOT_DIR/tests/lm_ssh_opts_guard_test.sh"
run_required "lm_log_json_test" bash "$ROOT_DIR/tests/lm_log_json_test.sh"
run_required "log_redaction_test" bash "$ROOT_DIR/tests/log_redaction_test.sh"
run_required "next_step_hint_test" bash "$ROOT_DIR/tests/next_step_hint_test.sh"
run_required "timer_monitor_test" bash "$ROOT_DIR/tests/timer_monitor_test.sh"
run_required "filesystem_readonly_monitor_test" bash "$ROOT_DIR/tests/filesystem_readonly_monitor_test.sh"
run_required "last_run_age_monitor_test" bash "$ROOT_DIR/tests/last_run_age_monitor_test.sh"

# Monitor exit-code policy (local-only)
run_required "monitor_exit_codes_test" bash "$ROOT_DIR/tests/monitor_exit_codes_test.sh"
run_required "lm_mktemp_fallback_test" bash "$ROOT_DIR/tests/lm_mktemp_fallback_test.sh"

# Monitor summary emission contract (each monitor must emit monitor= lines)
run_required "monitor_summary_emission_test" bash "$ROOT_DIR/tests/monitor_summary_emission_test.sh"
run_required "summary_diff_canonicalization_test" bash "$ROOT_DIR/tests/summary_diff_canonicalization_test.sh"
run_required "summary_fixture_per_monitor_test" bash "$ROOT_DIR/tests/summary_fixture_per_monitor_test.sh"
run_required "quick_check_make_target_test" bash "$ROOT_DIR/tests/quick_check_make_target_test.sh"
run_required "wrapper_runtime_summary_test" bash "$ROOT_DIR/tests/wrapper_runtime_summary_test.sh"
run_required "strict_run_validation_test" bash "$ROOT_DIR/tests/strict_run_validation_test.sh"
run_required "test_mode_deterministic_test" bash "$ROOT_DIR/tests/test_mode_deterministic_test.sh"
run_required "runtimes_command_test" bash "$ROOT_DIR/tests/runtimes_command_test.sh"
run_required "runtimes_json_fields_test" bash "$ROOT_DIR/tests/runtimes_json_fields_test.sh"
run_required "runtime_warn_threshold_test" bash "$ROOT_DIR/tests/runtime_warn_threshold_test.sh"
run_required "report_command_test" bash "$ROOT_DIR/tests/report_command_test.sh"
run_required "report_short_test" bash "$ROOT_DIR/tests/report_short_test.sh"
run_required "check_command_test" bash "$ROOT_DIR/tests/check_command_test.sh"
run_required "diff_color_test" bash "$ROOT_DIR/tests/diff_color_test.sh"
run_required "diff_json_schema_test" bash "$ROOT_DIR/tests/diff_json_schema_test.sh"
run_required "metrics_command_test" bash "$ROOT_DIR/tests/metrics_command_test.sh"
run_required "history_command_test" bash "$ROOT_DIR/tests/history_command_test.sh"
run_required "summary_command_test" bash "$ROOT_DIR/tests/summary_command_test.sh"
run_required "status_summary_test" bash "$ROOT_DIR/tests/status_summary_test.sh"
run_required "status_last_color_test" bash "$ROOT_DIR/tests/status_last_color_test.sh"
run_required "status_group_by_test" bash "$ROOT_DIR/tests/status_group_by_test.sh"
run_required "status_group_by_top_test" bash "$ROOT_DIR/tests/status_group_by_top_test.sh"
run_required "status_expected_skips_banner_test" bash "$ROOT_DIR/tests/status_expected_skips_banner_test.sh"
run_required "status_prom_test" bash "$ROOT_DIR/tests/status_prom_test.sh"
run_required "status_strict_test" bash "$ROOT_DIR/tests/status_strict_test.sh"
run_required "help_command_test" bash "$ROOT_DIR/tests/help_command_test.sh"
run_required "color_precedence_test" bash "$ROOT_DIR/tests/color_precedence_test.sh"
run_required "progress_tty_test" bash "$ROOT_DIR/tests/progress_tty_test.sh"
run_required "json_progress_guard_test" bash "$ROOT_DIR/tests/json_progress_guard_test.sh"
run_required "json_output_clean_test" bash "$ROOT_DIR/tests/json_output_clean_test.sh"

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

  # Summary noise guardrail (wrapper-level) - use fixture to avoid long wrapper runs in CI
  run_required "summary_noise_lint" bash "$ROOT_DIR/tests/summary_noise_lint.sh" "$ROOT_DIR/tests/fixtures/summary_ok.log"
  run_required "summary_budget_lint_fixture_test" bash "$ROOT_DIR/tests/summary_budget_lint_fixture_test.sh"
  run_required "inventory_cache_test" bash "$ROOT_DIR/tests/inventory_cache_test.sh"
run_required "wrapper_fallback_paths_test" bash "$ROOT_DIR/tests/wrapper_fallback_paths_test.sh"
run_required "wrapper_summary_write_fail_test" bash "$ROOT_DIR/tests/wrapper_summary_write_fail_test.sh"
run_required "summary_checksum_test" bash "$ROOT_DIR/tests/summary_checksum_test.sh"

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
run_required "installed_mode_sanity_test" bash "$ROOT_DIR/tests/installed_mode_sanity_test.sh"
run_required "init_minimal_idempotent_test" bash "$ROOT_DIR/tests/init_minimal_idempotent_test.sh"
run_required "pack_logs_test" bash "$ROOT_DIR/tests/pack_logs_test.sh"
run_required "release_verify_test" bash "$ROOT_DIR/tests/release_verify_test.sh"
run_required "doctor_offline_hints_test" bash "$ROOT_DIR/tests/doctor_offline_hints_test.sh"
run_required "doctor_json_test" bash "$ROOT_DIR/tests/doctor_json_test.sh"
run_required "doctor_json_schema_test" bash "$ROOT_DIR/tests/doctor_json_schema_test.sh"
run_required "explain_reason_test" bash "$ROOT_DIR/tests/explain_reason_test.sh"
run_required "explain_monitor_test" bash "$ROOT_DIR/tests/explain_monitor_test.sh"
run_required "ssh_known_hosts_mode_test" bash "$ROOT_DIR/tests/ssh_known_hosts_mode_test.sh"
run_required "self_check_json_test" bash "$ROOT_DIR/tests/self_check_json_test.sh"
run_required "self_check_json_schema_test" bash "$ROOT_DIR/tests/self_check_json_schema_test.sh"
run_required "status_reason_rollup_test" bash "$ROOT_DIR/tests/status_reason_rollup_test.sh"
run_required "status_json_compat_test" bash "$ROOT_DIR/tests/status_json_compat_test.sh"
run_required "status_json_schema_test" bash "$ROOT_DIR/tests/status_json_schema_test.sh"
run_required "export_json_test" bash "$ROOT_DIR/tests/export_json_test.sh"
run_required "export_json_schema_test" bash "$ROOT_DIR/tests/export_json_schema_test.sh"
run_required "export_csv_test" bash "$ROOT_DIR/tests/export_csv_test.sh"
run_required "status_since_test" bash "$ROOT_DIR/tests/status_since_test.sh"
run_required "trend_command_test" bash "$ROOT_DIR/tests/trend_command_test.sh"
run_required "run_index_command_test" bash "$ROOT_DIR/tests/run_index_command_test.sh"
run_required "runtimes_json_fields_test" bash "$ROOT_DIR/tests/runtimes_json_fields_test.sh"
run_required "summary_json_schema_test" bash "$ROOT_DIR/tests/summary_json_schema_test.sh"
run_required "run_index_schema_test" bash "$ROOT_DIR/tests/run_index_schema_test.sh"
fi

# Sudo-gated tests
if sudo -n true >/dev/null 2>&1; then
  bash "$ROOT_DIR/tests/wrapper_artifacts_test.sh" >/dev/null
  bash "$ROOT_DIR/tests/status_json_test.sh" >/dev/null
  bash "$ROOT_DIR/tests/status_quiet_test.sh" >/dev/null
  bash "$ROOT_DIR/tests/status_contract_test.sh" >/dev/null
  bash "$ROOT_DIR/tests/summary_reason_lint.sh" >/dev/null
  bash "$ROOT_DIR/tests/doctor_fix_json_test.sh" >/dev/null
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
