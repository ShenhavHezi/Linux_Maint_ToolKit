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

run_required_if_cmd(){
  local tool="$1"; shift
  local label="$1"; shift
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "SKIP: $label ($tool not installed)" >&2
    return 0
  fi
  run_required "$label" "$@"
}

# Basic help/version checks
run_required "linux-maint help" bash "$ROOT_DIR/bin/linux-maint" help

# Preflight should not hard-fail just because optional tools are missing
LM_LOGFILE=${TMPDIR}/preflight_check.log LM_LOCKDIR="${TMPDIR}" bash "$ROOT_DIR/monitors/preflight_check.sh" >/dev/null || true
run_required "preflight_repo_paths_test" bash "$ROOT_DIR/tests/preflight_repo_paths_test.sh"

# Validate config formats (should succeed even if config files are absent; best-effort)
LM_LOGFILE=${TMPDIR}/config_validate.log LM_LOCKDIR="${TMPDIR}" bash "$ROOT_DIR/monitors/config_validate.sh" >/dev/null || true

# lm_for_each_host_rc aggregation test
run_required "lm_for_each_host_rc_test" bash "$ROOT_DIR/tests/lm_for_each_host_rc_test.sh"
run_required "lm_summary_strict_test" bash "$ROOT_DIR/tests/lm_summary_strict_test.sh"
run_required "lm_summary_allowlist_test" bash "$ROOT_DIR/tests/lm_summary_allowlist_test.sh"
run_required "lm_summary_allowlist_strict_test" bash "$ROOT_DIR/tests/lm_summary_allowlist_strict_test.sh"
run_required "lm_time_test" bash "$ROOT_DIR/tests/lm_time_test.sh"
run_required "lm_cfg_defaults_test" bash "$ROOT_DIR/tests/lm_cfg_defaults_test.sh"
run_required "bash_min_version_guard_test" bash "$ROOT_DIR/tests/bash_min_version_guard_test.sh"
run_required "lm_ssh_allowlist_test" bash "$ROOT_DIR/tests/lm_ssh_allowlist_test.sh"
run_required "lm_ssh_allowlist_strict_test" bash "$ROOT_DIR/tests/lm_ssh_allowlist_strict_test.sh"
run_required "ssh_opts_weak_cipher_strict_test" bash "$ROOT_DIR/tests/ssh_opts_weak_cipher_strict_test.sh"
run_required "hosts_parse_test" bash "$ROOT_DIR/tests/hosts_parse_test.sh"
run_required "seed_known_hosts_test" bash "$ROOT_DIR/tests/seed_known_hosts_test.sh"
run_required "lm_ssh_opts_guard_test" bash "$ROOT_DIR/tests/lm_ssh_opts_guard_test.sh"
run_required "lm_log_json_test" bash "$ROOT_DIR/tests/lm_log_json_test.sh"
run_required "log_redaction_test" bash "$ROOT_DIR/tests/log_redaction_test.sh"
run_required "config_validate_keys_test" bash "$ROOT_DIR/tests/config_validate_keys_test.sh"
run_required "config_validate_unreadable_conf_test" bash "$ROOT_DIR/tests/config_validate_unreadable_conf_test.sh"
run_required "config_type_validation_test" bash "$ROOT_DIR/tests/config_type_validation_test.sh"
run_required "config_no_config_json_test" bash "$ROOT_DIR/tests/config_no_config_json_test.sh"
run_required "config_source_failure_test" bash "$ROOT_DIR/tests/config_source_failure_test.sh"
run_required "config_source_failure_human_hint_test" bash "$ROOT_DIR/tests/config_source_failure_human_hint_test.sh"
run_required "config_unreadable_sources_json_test" bash "$ROOT_DIR/tests/config_unreadable_sources_json_test.sh"
run_required "config_unreadable_sources_lint_test" bash "$ROOT_DIR/tests/config_unreadable_sources_lint_test.sh"
run_required "installed_read_only_commands_no_root_test" bash "$ROOT_DIR/tests/installed_read_only_commands_no_root_test.sh"
run_required "installed_reporting_commands_no_root_test" bash "$ROOT_DIR/tests/installed_reporting_commands_no_root_test.sh"
run_required "installed_run_plan_no_root_test" bash "$ROOT_DIR/tests/installed_run_plan_no_root_test.sh"
run_required "installed_mutating_commands_require_root_test" bash "$ROOT_DIR/tests/installed_mutating_commands_require_root_test.sh"
run_required "next_step_hint_test" bash "$ROOT_DIR/tests/next_step_hint_test.sh"
run_required "timer_monitor_test" bash "$ROOT_DIR/tests/timer_monitor_test.sh"
run_required "filesystem_readonly_monitor_test" bash "$ROOT_DIR/tests/filesystem_readonly_monitor_test.sh"
run_required "last_run_age_monitor_test" bash "$ROOT_DIR/tests/last_run_age_monitor_test.sh"

# Monitor exit-code policy (local-only)
run_required "monitor_exit_codes_test" bash "$ROOT_DIR/tests/monitor_exit_codes_test.sh"
run_required "lm_mktemp_fallback_test" bash "$ROOT_DIR/tests/lm_mktemp_fallback_test.sh"

# Monitor summary emission contract (each monitor must emit monitor= lines)
run_required "monitor_summary_emission_test" bash "$ROOT_DIR/tests/monitor_summary_emission_test.sh"
run_required "summary_contract_monitor_list_test" bash "$ROOT_DIR/tests/summary_contract_monitor_list_test.sh"
run_required "summary_diff_canonicalization_test" bash "$ROOT_DIR/tests/summary_diff_canonicalization_test.sh"
run_required "summary_fixture_per_monitor_test" bash "$ROOT_DIR/tests/summary_fixture_per_monitor_test.sh"
run_required "skip_gate_reason_test" bash "$ROOT_DIR/tests/skip_gate_reason_test.sh"
run_required "quick_check_make_target_test" bash "$ROOT_DIR/tests/quick_check_make_target_test.sh"
run_required "wrapper_runtime_summary_test" bash "$ROOT_DIR/tests/wrapper_runtime_summary_test.sh"
run_required "wrapper_repo_logfile_default_test" bash "$ROOT_DIR/tests/wrapper_repo_logfile_default_test.sh"
run_required "wrapper_explicit_state_no_fallback_test" bash "$ROOT_DIR/tests/wrapper_explicit_state_no_fallback_test.sh"
run_required "wrapper_invalid_run_index_preserve_test" bash "$ROOT_DIR/tests/wrapper_invalid_run_index_preserve_test.sh"
run_required "wrapper_summary_latest_override_test" bash "$ROOT_DIR/tests/wrapper_summary_latest_override_test.sh"
run_required "wrapper_status_write_fail_test" bash "$ROOT_DIR/tests/wrapper_status_write_fail_test.sh"
run_required "wrapper_cfg_dir_fallback_cert_monitor_test" bash "$ROOT_DIR/tests/wrapper_cfg_dir_fallback_cert_monitor_test.sh"
run_required "wrapper_summary_hosts_line_test" bash "$ROOT_DIR/tests/wrapper_summary_hosts_line_test.sh"
run_required "strict_run_validation_test" bash "$ROOT_DIR/tests/strict_run_validation_test.sh"
run_required "test_mode_deterministic_test" bash "$ROOT_DIR/tests/test_mode_deterministic_test.sh"
run_required "wrapper_tmpdir_cleanup_test" bash "$ROOT_DIR/tests/wrapper_tmpdir_cleanup_test.sh"
run_required "run_only_skip_test" bash "$ROOT_DIR/tests/run_only_skip_test.sh"
run_required "run_only_progress_output_test" bash "$ROOT_DIR/tests/run_only_progress_output_test.sh"
run_required "run_id_propagation_test" bash "$ROOT_DIR/tests/run_id_propagation_test.sh"
run_required "run_lock_test" bash "$ROOT_DIR/tests/run_lock_test.sh"
run_required "run_lock_stale_meta_test" bash "$ROOT_DIR/tests/run_lock_stale_meta_test.sh"
run_required "run_resume_state_test" bash "$ROOT_DIR/tests/run_resume_state_test.sh"
run_required "run_resume_explicit_state_no_fallback_test" bash "$ROOT_DIR/tests/run_resume_explicit_state_no_fallback_test.sh"
run_required "run_resume_invalid_index_test" bash "$ROOT_DIR/tests/run_resume_invalid_index_test.sh"
run_required "runtimes_command_test" bash "$ROOT_DIR/tests/runtimes_command_test.sh"
run_required "runtimes_json_fields_test" bash "$ROOT_DIR/tests/runtimes_json_fields_test.sh"
run_required "repo_cfg_default_operator_test" bash "$ROOT_DIR/tests/repo_cfg_default_operator_test.sh"
run_required "runtime_warn_threshold_test" bash "$ROOT_DIR/tests/runtime_warn_threshold_test.sh"
run_required "report_command_test" bash "$ROOT_DIR/tests/report_command_test.sh"
run_required "reporting_repo_log_dir_override_test" bash "$ROOT_DIR/tests/reporting_repo_log_dir_override_test.sh"
run_required_if_cmd perl "report_invalid_status_test" bash "$ROOT_DIR/tests/report_invalid_status_test.sh"
run_required "report_short_test" bash "$ROOT_DIR/tests/report_short_test.sh"
run_required "report_golden_fixture_test" bash "$ROOT_DIR/tests/report_golden_fixture_test.sh"
run_required "tui_report_golden_fixture_test" bash "$ROOT_DIR/tests/tui_report_golden_fixture_test.sh"
run_required "status_table_golden_fixture_test" bash "$ROOT_DIR/tests/status_table_golden_fixture_test.sh"
run_required "check_command_test" bash "$ROOT_DIR/tests/check_command_test.sh"
run_required "check_json_test" bash "$ROOT_DIR/tests/check_json_test.sh"
run_required "check_json_schema_test" bash "$ROOT_DIR/tests/check_json_schema_test.sh"
run_required "check_exit_code_test" bash "$ROOT_DIR/tests/check_exit_code_test.sh"
run_required "check_no_side_effects_test" bash "$ROOT_DIR/tests/check_no_side_effects_test.sh"
run_required "init_repo_default_cfg_dir_test" bash "$ROOT_DIR/tests/init_repo_default_cfg_dir_test.sh"
run_required "gate_command_test" bash "$ROOT_DIR/tests/gate_command_test.sh"
run_required_if_cmd perl "gate_invalid_status_test" bash "$ROOT_DIR/tests/gate_invalid_status_test.sh"
run_required "diff_color_test" bash "$ROOT_DIR/tests/diff_color_test.sh"
run_required "diff_json_schema_test" bash "$ROOT_DIR/tests/diff_json_schema_test.sh"
run_required "diff_golden_fixture_test" bash "$ROOT_DIR/tests/diff_golden_fixture_test.sh"
run_required "metrics_command_test" bash "$ROOT_DIR/tests/metrics_command_test.sh"
run_required_if_cmd perl "metrics_invalid_status_test" bash "$ROOT_DIR/tests/metrics_invalid_status_test.sh"
run_required "metrics_top_slow_test" bash "$ROOT_DIR/tests/metrics_top_slow_test.sh"
run_required "history_command_test" bash "$ROOT_DIR/tests/history_command_test.sh"
run_required "history_repo_hint_test" bash "$ROOT_DIR/tests/history_repo_hint_test.sh"
run_required "history_sqlite_test" bash "$ROOT_DIR/tests/history_sqlite_test.sh"
run_required "history_invalid_run_index_test" bash "$ROOT_DIR/tests/history_invalid_run_index_test.sh"
run_required "history_large_index_perf_test" bash "$ROOT_DIR/tests/history_large_index_perf_test.sh"
run_required "tune_dark_site_repo_mode_test" bash "$ROOT_DIR/tests/tune_dark_site_repo_mode_test.sh"
run_required "tune_dark_site_duplicate_key_test" bash "$ROOT_DIR/tests/tune_dark_site_duplicate_key_test.sh"
run_required "summary_command_test" bash "$ROOT_DIR/tests/summary_command_test.sh"
run_required_if_cmd perl "summary_invalid_status_test" bash "$ROOT_DIR/tests/summary_invalid_status_test.sh"
run_required "status_summary_test" bash "$ROOT_DIR/tests/status_summary_test.sh"
run_required "status_repo_missing_summary_hints_test" bash "$ROOT_DIR/tests/status_repo_missing_summary_hints_test.sh"
run_required "status_last_color_test" bash "$ROOT_DIR/tests/status_last_color_test.sh"
run_required "status_group_by_test" bash "$ROOT_DIR/tests/status_group_by_test.sh"
run_required "status_group_by_top_test" bash "$ROOT_DIR/tests/status_group_by_top_test.sh"
run_required "status_expected_skips_no_side_effects_test" bash "$ROOT_DIR/tests/status_expected_skips_no_side_effects_test.sh"
run_required "status_expected_skips_banner_test" bash "$ROOT_DIR/tests/status_expected_skips_banner_test.sh"
run_required "status_prom_test" bash "$ROOT_DIR/tests/status_prom_test.sh"
run_required "status_prom_parse_safety_test" bash "$ROOT_DIR/tests/status_prom_parse_safety_test.sh"
run_required "status_prom_unreadable_summary_test" bash "$ROOT_DIR/tests/status_prom_unreadable_summary_test.sh"
run_required "metrics_prom_output_test" bash "$ROOT_DIR/tests/metrics_prom_output_test.sh"
run_required "metrics_prom_parse_safety_test" bash "$ROOT_DIR/tests/metrics_prom_parse_safety_test.sh"
run_required "status_strict_test" bash "$ROOT_DIR/tests/status_strict_test.sh"
run_required "self_check_strict_test" bash "$ROOT_DIR/tests/self_check_strict_test.sh"
run_required "help_command_test" bash "$ROOT_DIR/tests/help_command_test.sh"
run_required "help_command_consistency_test" bash "$ROOT_DIR/tests/help_command_consistency_test.sh"
run_required "help_repo_usage_test" bash "$ROOT_DIR/tests/help_repo_usage_test.sh"
run_required "help_top_level_golden_test" bash "$ROOT_DIR/tests/help_top_level_golden_test.sh"
run_required "help_top_level_structure_test" bash "$ROOT_DIR/tests/help_top_level_structure_test.sh"
run_required "help_menu_command_test" bash "$ROOT_DIR/tests/help_menu_command_test.sh"
run_required "help_menu_golden_test" bash "$ROOT_DIR/tests/help_menu_golden_test.sh"
run_required "help_menu_structure_test" bash "$ROOT_DIR/tests/help_menu_structure_test.sh"
run_required "menu_help_overlay_text_test" bash "$ROOT_DIR/tests/menu_help_overlay_text_test.sh"
run_required "help_operator_depth_test" bash "$ROOT_DIR/tests/help_operator_depth_test.sh"
run_required "operator_docs_mode_aware_test" bash "$ROOT_DIR/tests/operator_docs_mode_aware_test.sh"
run_required "repo_install_passthrough_root_no_sudo_test" bash "$ROOT_DIR/tests/repo_install_passthrough_root_no_sudo_test.sh"
run_required_if_cmd perl "init_installed_root_no_sudo_test" bash "$ROOT_DIR/tests/init_installed_root_no_sudo_test.sh"
run_required "logs_no_side_effects_test" bash "$ROOT_DIR/tests/logs_no_side_effects_test.sh"
run_required "security_profile_command_test" bash "$ROOT_DIR/tests/security_profile_command_test.sh"
run_required "security_profile_json_schema_test" bash "$ROOT_DIR/tests/security_profile_json_schema_test.sh"
run_required "doctor_repo_paths_test" bash "$ROOT_DIR/tests/doctor_repo_paths_test.sh"
run_required "doctor_repo_inventory_optional_test" bash "$ROOT_DIR/tests/doctor_repo_inventory_optional_test.sh"
run_required "plugin_command_test" bash "$ROOT_DIR/tests/plugin_command_test.sh"
run_required "plugin_init_test" bash "$ROOT_DIR/tests/plugin_init_test.sh"
run_required "plugin_update_test" bash "$ROOT_DIR/tests/plugin_update_test.sh"
run_required "plugin_registry_invalid_test" bash "$ROOT_DIR/tests/plugin_registry_invalid_test.sh"
run_required "plugin_installed_default_index_test" bash "$ROOT_DIR/tests/plugin_installed_default_index_test.sh"
run_required "plugin_verify_installed_version_test" bash "$ROOT_DIR/tests/plugin_verify_installed_version_test.sh"
run_required "plugin_force_install_rollback_test" bash "$ROOT_DIR/tests/plugin_force_install_rollback_test.sh"
run_required "plugin_index_lint_test" bash "$ROOT_DIR/tests/plugin_index_lint_test.sh"
run_required "plugin_signature_verify_test" bash "$ROOT_DIR/tests/plugin_signature_verify_test.sh"
run_required "plugin_verify_index_attestation_test" bash "$ROOT_DIR/tests/plugin_verify_index_attestation_test.sh"
run_required "plugin_verify_index_json_schema_test" bash "$ROOT_DIR/tests/plugin_verify_index_json_schema_test.sh"
run_required "plugin_trust_policy_test" bash "$ROOT_DIR/tests/plugin_trust_policy_test.sh"
run_required "plugin_verify_trust_policy_test" bash "$ROOT_DIR/tests/plugin_verify_trust_policy_test.sh"
run_required "plugin_provenance_report_test" bash "$ROOT_DIR/tests/plugin_provenance_report_test.sh"
run_required "plugin_verify_json_schema_test" bash "$ROOT_DIR/tests/plugin_verify_json_schema_test.sh"
run_required "notify_command_test" bash "$ROOT_DIR/tests/notify_command_test.sh"
run_required "notify_curl_timeout_test" bash "$ROOT_DIR/tests/notify_curl_timeout_test.sh"
run_required "ticket_command_test" bash "$ROOT_DIR/tests/ticket_command_test.sh"
run_required "ticket_curl_timeout_test" bash "$ROOT_DIR/tests/ticket_curl_timeout_test.sh"
run_required "ticket_json_schema_test" bash "$ROOT_DIR/tests/ticket_json_schema_test.sh"
run_required "cm_hook_command_test" bash "$ROOT_DIR/tests/cm_hook_command_test.sh"
run_required "cm_hook_json_schema_test" bash "$ROOT_DIR/tests/cm_hook_json_schema_test.sh"
run_required "audit_log_command_test" bash "$ROOT_DIR/tests/audit_log_command_test.sh"
run_required "audit_log_verify_tamper_test" bash "$ROOT_DIR/tests/audit_log_verify_tamper_test.sh"
run_required "audit_log_concurrency_test" bash "$ROOT_DIR/tests/audit_log_concurrency_test.sh"
run_required "audit_log_json_schema_test" bash "$ROOT_DIR/tests/audit_log_json_schema_test.sh"
run_required "serve_command_test" bash "$ROOT_DIR/tests/serve_command_test.sh"
run_required "serve_command_timeout_test" bash "$ROOT_DIR/tests/serve_command_timeout_test.sh"
run_required "serve_invalid_json_upstream_test" bash "$ROOT_DIR/tests/serve_invalid_json_upstream_test.sh"
run_required "agent_command_test" bash "$ROOT_DIR/tests/agent_command_test.sh"
run_required_if_cmd perl "agent_once_failure_exit_test" bash "$ROOT_DIR/tests/agent_once_failure_exit_test.sh"
run_required "agent_interval_validation_test" bash "$ROOT_DIR/tests/agent_interval_validation_test.sh"
run_required "policy_command_test" bash "$ROOT_DIR/tests/policy_command_test.sh"
run_required "policy_lint_require_overall_test" bash "$ROOT_DIR/tests/policy_lint_require_overall_test.sh"
run_required "federate_command_test" bash "$ROOT_DIR/tests/federate_command_test.sh"
run_required "federate_invalid_input_test" bash "$ROOT_DIR/tests/federate_invalid_input_test.sh"
run_required "federate_contract_validation_test" bash "$ROOT_DIR/tests/federate_contract_validation_test.sh"
run_required "ai_assist_command_test" bash "$ROOT_DIR/tests/ai_assist_command_test.sh"
run_required_if_cmd perl "ai_assist_invalid_status_test" bash "$ROOT_DIR/tests/ai_assist_invalid_status_test.sh"
run_required "predict_command_test" bash "$ROOT_DIR/tests/predict_command_test.sh"
run_required "predict_no_history_test" bash "$ROOT_DIR/tests/predict_no_history_test.sh"
run_required "predict_last_validation_test" bash "$ROOT_DIR/tests/predict_last_validation_test.sh"
run_required_if_cmd perl "predict_invalid_history_test" bash "$ROOT_DIR/tests/predict_invalid_history_test.sh"
run_required "predict_invalid_history_shape_test" bash "$ROOT_DIR/tests/predict_invalid_history_shape_test.sh"
run_required "menu_choice_normalization_test" bash "$ROOT_DIR/tests/menu_choice_normalization_test.sh"
run_required "menu_doc_path_resolution_test" bash "$ROOT_DIR/tests/menu_doc_path_resolution_test.sh"
run_required "menu_config_wiring_test" bash "$ROOT_DIR/tests/menu_config_wiring_test.sh"
run_required "menu_shortcuts_test" bash "$ROOT_DIR/tests/menu_shortcuts_test.sh"
run_required "menu_pack_logs_wizard_test" bash "$ROOT_DIR/tests/menu_pack_logs_wizard_test.sh"
run_required "menu_palette_rank_test" bash "$ROOT_DIR/tests/menu_palette_rank_test.sh"
run_required "menu_empty_state_preview_test" bash "$ROOT_DIR/tests/menu_empty_state_preview_test.sh"
run_required "menu_first_setup_wizard_test" bash "$ROOT_DIR/tests/menu_first_setup_wizard_test.sh"
run_required "menu_fallback_prompt_test" bash "$ROOT_DIR/tests/menu_fallback_prompt_test.sh"
run_required "menu_command_preview_test" bash "$ROOT_DIR/tests/menu_command_preview_test.sh"
run_required "menu_action_preview_text_test" bash "$ROOT_DIR/tests/menu_action_preview_text_test.sh"
run_required "menu_quickstart_shortcuts_test" bash "$ROOT_DIR/tests/menu_quickstart_shortcuts_test.sh"
run_required "menu_return_to_main_after_failure_test" bash "$ROOT_DIR/tests/menu_return_to_main_after_failure_test.sh"
run_required "incident_recommendation_test" bash "$ROOT_DIR/tests/incident_recommendation_test.sh"
run_required "menu_settings_roundtrip_test" bash "$ROOT_DIR/tests/menu_settings_roundtrip_test.sh"
run_required "menu_settings_validation_test" bash "$ROOT_DIR/tests/menu_settings_validation_test.sh"
run_required "menu_all_sections_fixture_test" bash "$ROOT_DIR/tests/menu_all_sections_fixture_test.sh"
run_required "menu_compact_frame_fixture_test" bash "$ROOT_DIR/tests/menu_compact_frame_fixture_test.sh"
run_required "menu_section_frame_fixture_test" bash "$ROOT_DIR/tests/menu_section_frame_fixture_test.sh"
run_required "menu_run_wizard_test" bash "$ROOT_DIR/tests/menu_run_wizard_test.sh"
run_required "menu_drilldown_top_explain_test" bash "$ROOT_DIR/tests/menu_drilldown_top_explain_test.sh"
run_required "menu_run_loop_continuation_test" bash "$ROOT_DIR/tests/menu_run_loop_continuation_test.sh"
run_required "menu_stdin_guard_test" bash "$ROOT_DIR/tests/menu_stdin_guard_test.sh"
run_required "list_monitors_test" bash "$ROOT_DIR/tests/list_monitors_test.sh"
run_required "lint_summary_test" bash "$ROOT_DIR/tests/lint_summary_test.sh"
run_required "run_plan_json_test" bash "$ROOT_DIR/tests/run_plan_json_test.sh"
run_required "run_plan_repo_cfg_defaults_test" bash "$ROOT_DIR/tests/run_plan_repo_cfg_defaults_test.sh"
run_required "run_plan_strategy_fields_test" bash "$ROOT_DIR/tests/run_plan_strategy_fields_test.sh"
run_required "run_maintenance_window_gate_test" bash "$ROOT_DIR/tests/run_maintenance_window_gate_test.sh"
run_required "run_drain_file_plan_test" bash "$ROOT_DIR/tests/run_drain_file_plan_test.sh"
run_required "run_monitor_privilege_policy_test" bash "$ROOT_DIR/tests/run_monitor_privilege_policy_test.sh"
run_required "monitor_order_test" bash "$ROOT_DIR/tests/monitor_order_test.sh"
run_required "color_precedence_test" bash "$ROOT_DIR/tests/color_precedence_test.sh"
run_required "progress_tty_test" bash "$ROOT_DIR/tests/progress_tty_test.sh"
run_required "json_progress_guard_test" bash "$ROOT_DIR/tests/json_progress_guard_test.sh"
run_required "json_output_clean_test" bash "$ROOT_DIR/tests/json_output_clean_test.sh"
run_required "json_output_prefix_test" bash "$ROOT_DIR/tests/json_output_prefix_test.sh"
run_required "json_redact_test" bash "$ROOT_DIR/tests/json_redact_test.sh"
run_required "ssh_known_hosts_path_test" bash "$ROOT_DIR/tests/ssh_known_hosts_path_test.sh"
run_required "ssh_known_hosts_pin_test" bash "$ROOT_DIR/tests/ssh_known_hosts_pin_test.sh"

# Security lint: forbid eval usage
run_required "no_eval_lint" bash "$ROOT_DIR/tests/no_eval_lint.sh"
run_required "secret_scan_lint_test" bash "$ROOT_DIR/tests/secret_scan_lint_test.sh"

# Dependency behavior example: network_monitor should emit missing_dependency when curl missing
run_required "network_monitor_missing_curl_test" bash "$ROOT_DIR/tests/network_monitor_missing_curl_test.sh"
run_required "config_drift_allowlist_test" bash "$ROOT_DIR/tests/config_drift_allowlist_test.sh"
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
run_required "inventory_cache_prune_test" bash "$ROOT_DIR/tests/inventory_cache_prune_test.sh"
run_required "wrapper_fallback_paths_test" bash "$ROOT_DIR/tests/wrapper_fallback_paths_test.sh"
run_required "wrapper_summary_write_fail_test" bash "$ROOT_DIR/tests/wrapper_summary_write_fail_test.sh"
run_required "summary_checksum_test" bash "$ROOT_DIR/tests/summary_checksum_test.sh"
  run_required "run_only_skip_integration_test" bash "$ROOT_DIR/tests/run_only_skip_integration_test.sh"

  # Prometheus textfile output (best-effort; wrapper-level)
  run_required "prom_textfile_output_test" bash "$ROOT_DIR/tests/prom_textfile_output_test.sh"
  run_required "openmetrics_eof_consistency_test" bash "$ROOT_DIR/tests/openmetrics_eof_consistency_test.sh"
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
run_required "verify_install_repo_defaults_test" bash "$ROOT_DIR/tests/verify_install_repo_defaults_test.sh"
run_required "verify_install_installed_layout_test" bash "$ROOT_DIR/tests/verify_install_installed_layout_test.sh"
run_required "install_override_layout_test" bash "$ROOT_DIR/tests/install_override_layout_test.sh"
run_required "install_rollback_prefix_failure_test" bash "$ROOT_DIR/tests/install_rollback_prefix_failure_test.sh"
run_required "install_rollback_systemd_logrotate_failure_test" bash "$ROOT_DIR/tests/install_rollback_systemd_logrotate_failure_test.sh"
run_required "doctor_verify_install_no_side_effects_test" bash "$ROOT_DIR/tests/doctor_verify_install_no_side_effects_test.sh"
run_required "installed_verify_release_dispatch_test" bash "$ROOT_DIR/tests/installed_verify_release_dispatch_test.sh"
run_required "installed_version_autodetect_test" bash "$ROOT_DIR/tests/installed_version_autodetect_test.sh"
run_required "installed_make_tarball_requires_checkout_test" bash "$ROOT_DIR/tests/installed_make_tarball_requires_checkout_test.sh"
run_required "installed_mode_sanity_test" bash "$ROOT_DIR/tests/installed_mode_sanity_test.sh"
run_required "install_manifest_test" bash "$ROOT_DIR/tests/install_manifest_test.sh"
run_required "rpm_manifest_test" bash "$ROOT_DIR/tests/rpm_manifest_test.sh"
run_required "rpm_systemd_units_test" bash "$ROOT_DIR/tests/rpm_systemd_units_test.sh"
run_required "init_minimal_idempotent_test" bash "$ROOT_DIR/tests/init_minimal_idempotent_test.sh"
run_required "init_repo_mode_no_sudo_test" bash "$ROOT_DIR/tests/init_repo_mode_no_sudo_test.sh"
run_required "pack_logs_test" bash "$ROOT_DIR/tests/pack_logs_test.sh"
run_required "pack_logs_gpg_prereq_test" bash "$ROOT_DIR/tests/pack_logs_gpg_prereq_test.sh"
run_required "pack_logs_symlink_test" bash "$ROOT_DIR/tests/pack_logs_symlink_test.sh"
run_required "pack_logs_config_symlink_test" bash "$ROOT_DIR/tests/pack_logs_config_symlink_test.sh"
run_required "pack_logs_handoff_optional_meta_test" bash "$ROOT_DIR/tests/pack_logs_handoff_optional_meta_test.sh"
run_required "pack_logs_meta_paths_test" bash "$ROOT_DIR/tests/pack_logs_meta_paths_test.sh"
run_required "pack_logs_repo_override_test" bash "$ROOT_DIR/tests/pack_logs_repo_override_test.sh"
run_required "release_verify_test" bash "$ROOT_DIR/tests/release_verify_test.sh"
run_required "release_verify_manifest_test" bash "$ROOT_DIR/tests/release_verify_manifest_test.sh"
run_required "release_verify_members_test" bash "$ROOT_DIR/tests/release_verify_members_test.sh"
run_required "release_provenance_manifest_test" bash "$ROOT_DIR/tests/release_provenance_manifest_test.sh"
run_required "release_metadata_guard_test" bash "$ROOT_DIR/tests/release_metadata_guard_test.sh"
run_required "release_contract_guard_test" bash "$ROOT_DIR/tests/release_contract_guard_test.sh"
run_required "release_version_format_test" bash "$ROOT_DIR/tests/release_version_format_test.sh"
run_required "release_notes_refs_helper_test" bash "$ROOT_DIR/tests/release_notes_refs_helper_test.sh"
run_required "release_audit_test" bash "$ROOT_DIR/tests/release_audit_test.sh"
run_required "release_audit_make_target_test" bash "$ROOT_DIR/tests/release_audit_make_target_test.sh"
run_required "release_sh_checks_test" bash "$ROOT_DIR/tests/release_sh_checks_test.sh"
run_required "ci_release_provenance_workflow_test" bash "$ROOT_DIR/tests/ci_release_provenance_workflow_test.sh"
run_required "monitor_cfg_path_helper_test" bash "$ROOT_DIR/tests/monitor_cfg_path_helper_test.sh"
run_required "make_tarball_roundtrip_test" bash "$ROOT_DIR/tests/make_tarball_roundtrip_test.sh"
run_required "upgrade_command_test" bash "$ROOT_DIR/tests/upgrade_command_test.sh"
run_required "upgrade_command_failure_manifest_test" bash "$ROOT_DIR/tests/upgrade_command_failure_manifest_test.sh"
run_required "doctor_offline_hints_test" bash "$ROOT_DIR/tests/doctor_offline_hints_test.sh"
run_required "doctor_json_test" bash "$ROOT_DIR/tests/doctor_json_test.sh"
run_required "doctor_json_schema_test" bash "$ROOT_DIR/tests/doctor_json_schema_test.sh"
run_required "doctor_json_unreadable_servers_test" bash "$ROOT_DIR/tests/doctor_json_unreadable_servers_test.sh"
run_required "doctor_json_strict_exit_test" bash "$ROOT_DIR/tests/doctor_json_strict_exit_test.sh"
run_required "doctor_fix_requires_root_test" bash "$ROOT_DIR/tests/doctor_fix_requires_root_test.sh"
run_required "doctor_fix_repo_mode_no_root_test" bash "$ROOT_DIR/tests/doctor_fix_repo_mode_no_root_test.sh"
run_required "explain_reason_test" bash "$ROOT_DIR/tests/explain_reason_test.sh"
run_required "explain_config_missing_repo_test" bash "$ROOT_DIR/tests/explain_config_missing_repo_test.sh"
run_required "explain_monitor_test" bash "$ROOT_DIR/tests/explain_monitor_test.sh"
run_required "explain_monitor_installed_doc_path_test" bash "$ROOT_DIR/tests/explain_monitor_installed_doc_path_test.sh"
run_required "explain_monitor_repo_text_test" bash "$ROOT_DIR/tests/explain_monitor_repo_text_test.sh"
run_required "ssh_known_hosts_mode_test" bash "$ROOT_DIR/tests/ssh_known_hosts_mode_test.sh"
run_required "self_check_json_test" bash "$ROOT_DIR/tests/self_check_json_test.sh"
run_required "self_check_json_schema_test" bash "$ROOT_DIR/tests/self_check_json_schema_test.sh"
run_required "self_check_json_strict_exit_test" bash "$ROOT_DIR/tests/self_check_json_strict_exit_test.sh"
run_required "status_reason_rollup_test" bash "$ROOT_DIR/tests/status_reason_rollup_test.sh"
run_required "status_json_compat_test" bash "$ROOT_DIR/tests/status_json_compat_test.sh"
run_required "status_json_schema_test" bash "$ROOT_DIR/tests/status_json_schema_test.sh"
run_required "status_unreadable_summary_test" bash "$ROOT_DIR/tests/status_unreadable_summary_test.sh"
run_required "export_json_test" bash "$ROOT_DIR/tests/export_json_test.sh"
run_required "export_json_schema_test" bash "$ROOT_DIR/tests/export_json_schema_test.sh"
run_required "export_invalid_summary_json_test" bash "$ROOT_DIR/tests/export_invalid_summary_json_test.sh"
run_required "export_unreadable_summary_log_test" bash "$ROOT_DIR/tests/export_unreadable_summary_log_test.sh"
run_required "export_csv_test" bash "$ROOT_DIR/tests/export_csv_test.sh"
run_required "export_jsonl_test" bash "$ROOT_DIR/tests/export_jsonl_test.sh"
run_required "export_jsonl_schema_test" bash "$ROOT_DIR/tests/export_jsonl_schema_test.sh"
run_required "status_since_test" bash "$ROOT_DIR/tests/status_since_test.sh"
run_required "trend_command_test" bash "$ROOT_DIR/tests/trend_command_test.sh"
run_required "trend_anomaly_test" bash "$ROOT_DIR/tests/trend_anomaly_test.sh"
run_required "trend_cache_ttl_test" bash "$ROOT_DIR/tests/trend_cache_ttl_test.sh"
run_required "trend_large_fixture_perf_test" bash "$ROOT_DIR/tests/trend_large_fixture_perf_test.sh"
run_required "trend_golden_fixture_test" bash "$ROOT_DIR/tests/trend_golden_fixture_test.sh"
run_required "run_index_command_test" bash "$ROOT_DIR/tests/run_index_command_test.sh"
run_required "runtimes_json_fields_test" bash "$ROOT_DIR/tests/runtimes_json_fields_test.sh"
run_required "summary_json_schema_test" bash "$ROOT_DIR/tests/summary_json_schema_test.sh"
run_required "run_index_schema_test" bash "$ROOT_DIR/tests/run_index_schema_test.sh"
run_required "run_index_prune_test" bash "$ROOT_DIR/tests/run_index_prune_test.sh"
run_required "run_index_prune_write_failure_test" bash "$ROOT_DIR/tests/run_index_prune_write_failure_test.sh"
run_required "run_index_explicit_state_no_fallback_test" bash "$ROOT_DIR/tests/run_index_explicit_state_no_fallback_test.sh"
run_required "run_index_prune_invalid_lines_test" bash "$ROOT_DIR/tests/run_index_prune_invalid_lines_test.sh"
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
