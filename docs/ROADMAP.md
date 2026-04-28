# Roadmap
Last updated: 2026-04-28

## How to use this file each session
- `DONE`: implemented and validated with tests/docs.
- `PARTIAL`: implemented baseline/scaffold but acceptance criteria not fully closed.
- `NEXT`: not implemented yet, queued.
- Rule: when a task moves to `DONE`, add at least one proof item (`command`, `test`, or file path).

## Current session checkpoint
- Completed this session:
  - P2 analytics export depth: `export --jsonl` + schema/tests.
  - P3 integration contracts: JSON outputs + schemas/tests for `ticket`, `cm-hook`, `audit-log`.
  - P3 hardening: index attestation verification (`plugin verify-index`) with `sha256|gpg|cosign`.
  - P1 audit hardening: `audit-log --verify` tamper detection + tests.
  - P3 trust lifecycle baseline: trust policy enforcement (`LM_PLUGIN_TRUST_POLICY_FILE`, `LM_PLUGIN_REQUIRE_TRUST_POLICY`) for index and plugin verification.
  - P3 provenance reporting: `plugin provenance-report` with strict gating and artifact output.
  - P0 repo/runtime hardening: non-root wrapper logfile fallback, `LM_CFG_DIR` propagation, summary host-count fix, and monitor regression tests.
    - Proof: `tests/wrapper/wrapper_repo_logfile_default_test.sh`, `tests/wrapper/wrapper_cfg_dir_fallback_cert_monitor_test.sh`, `tests/wrapper/wrapper_summary_hosts_line_test.sh`, `tests/core/config_validate_unreadable_conf_test.sh`, `tests/runtime/config_drift_allowlist_test.sh`.
  - P0 plugin lifecycle hardening: forced plugin installs now preserve the previous plugin on source-copy failure.
    - Proof: `tests/plugin_force_install_rollback_test.sh`.
  - P0 integration hardening: `notify`/`ticket` curl calls now use bounded connect/total timeouts with regression tests.
    - Proof: `tests/notify_curl_timeout_test.sh`, `tests/ticket_curl_timeout_test.sh`.
  - P0 audit hardening: audit chain writes are now serialized so concurrent operations preserve a valid append-only chain.
    - Proof: `tests/audit_log_concurrency_test.sh`.
  - P0 CLI contract hardening: `check --json` now has an explicit schema/version contract, and `metrics --json` fails fast when delegated `status --json` is invalid.
    - Proof: `tests/core/check_json_schema_test.sh`, `tests/reporting/metrics_invalid_status_test.sh`.
  - P0 reporting contract hardening: `trend`/`runtimes`/`export` JSON now carry explicit contract versions, and `export` fails fast on corrupt preferred summary JSON artifacts.
    - Proof: `tests/reporting/trend_command_test.sh`, `tests/reporting/trend_cache_ttl_test.sh`, `tests/reporting/runtimes_json_fields_test.sh`, `tests/reporting/export_invalid_summary_json_test.sh`.
  - P0 run-index hardening: `run-index --prune` now fails on rewrite errors instead of silently reporting success, and `run-index --json` has an explicit contract/schema.
    - Proof: `tests/core/run_index_command_test.sh`, `tests/core/run_index_prune_write_failure_test.sh`.
  - P0 history hardening: `history --json` now fails on corrupt `run_index.jsonl` input instead of silently dropping bad lines, with explicit source/schema fields.
    - Proof: `tests/core/history_invalid_run_index_test.sh`, `tests/core/history_sqlite_test.sh`, `tests/core/history_large_index_perf_test.sh`.
  - P0 config contract hardening: `config --json` now emits structured, versioned error payloads instead of ad hoc unversioned JSON.
    - Proof: `tests/core/config_no_config_json_test.sh`, `tests/core/config_source_failure_test.sh`, `tests/core/config_type_validation_test.sh`.
  - P0 operator contract hardening: `doctor`, `self-check`, and `security-profile` JSON outputs now expose explicit schema/contract versions with schema-backed tests.
    - Proof: `tests/core/doctor_json_schema_test.sh`, `tests/core/self_check_json_schema_test.sh`, `tests/core/security_profile_json_schema_test.sh`.
  - P0 repo/install readiness hardening: `preflight` now respects repo-local config/state/log paths, `init` no longer requires `sudo` in repo mode, and `verify-install` uses repo-mode writable defaults.
    - Proof: `tests/install/preflight_repo_paths_test.sh`, `tests/install/init_repo_mode_no_sudo_test.sh`, `tests/install/verify_install_repo_defaults_test.sh`.
  - P0 readiness/support-bundle hardening: `check` now preserves validation severity in its exit code, and `pack-logs` no longer leaves plaintext bundles on failed `--gpg` setup or stores broken latest-log symlinks.
    - Proof: `tests/core/check_exit_code_test.sh`, `tests/core/pack_logs_gpg_prereq_test.sh`, `tests/core/pack_logs_symlink_test.sh`.
  - P0 reporting path hardening: repo-mode `status`/`report`/`export` now honor `LOG_DIR` instead of silently reading stale `.logs` artifacts.
    - Proof: `tests/reporting/reporting_repo_log_dir_override_test.sh`.
  - P0 read-only command hardening: `logs`, `status --expected-skips`, and `check` no longer create missing repo-local directories as side effects.
    - Proof: `tests/reporting/logs_no_side_effects_test.sh`, `tests/reporting/status_expected_skips_no_side_effects_test.sh`, `tests/core/check_no_side_effects_test.sh`.
  - P0 operator path hardening: `doctor`, `verify-install`, `config`, `self-check`, `security-profile`, `runtimes`, and repo-mode `pack-logs` now honor repo-local defaults/overrides consistently, and read-only writable checks no longer mutate directories.
    - Proof: `tests/core/doctor_repo_paths_test.sh`, `tests/core/doctor_verify_install_no_side_effects_test.sh`, `tests/core/repo_cfg_default_operator_test.sh`, `tests/core/pack_logs_repo_override_test.sh`.
  - P0 repo-mode operator guidance hardening: `run --plan`, `status`, `history`, and `explain` now use repo-local host/config defaults and repo-appropriate hints instead of leaking installed-mode `/etc` and `sudo` guidance.
    - Proof: `tests/run/run_plan_repo_cfg_defaults_test.sh`, `tests/reporting/status_repo_missing_summary_hints_test.sh`, `tests/core/history_repo_hint_test.sh`, `tests/core/explain_config_missing_repo_test.sh`.
  - P1 operator UX/help hardening: top-level help, run help, config source-failure hints, and monitor explanations now use repo/install-neutral wording instead of installed-only paths.
    - Proof: `tests/menu/help_repo_usage_test.sh`, `tests/core/config_source_failure_human_hint_test.sh`, `tests/core/explain_monitor_repo_text_test.sh`.
  - P1 operator UX/docs polish: menu labels and `help menu` now explain the main operator flows clearly, and the quick reference, troubleshooting guide, and FAQ are repo/install-aware instead of reading as installed-mode-only docs.
    - Proof: `tests/menu/help_menu_structure_test.sh`, `tests/menu/operator_docs_mode_aware_test.sh`, `tests/menu/menu_tty_flow_smoke_test.sh`.
  - P1 TUI upgrade: `linux-maint menu` now opens with a landing overview, keeps repo/install context visible, uses task-based main sections (`Overview/Run/Investigate/Repair/Export/Docs`), and incident mode can execute a recommended triage flow from the top reason class.
    - Proof: `tests/menu/menu_tty_flow_smoke_test.sh`, `tests/menu/menu_shortcuts_test.sh`, `tests/menu/menu_main_shortcut_dispatch_test.sh`, `tests/menu/incident_recommendation_test.sh`, `tests/menu/help_menu_structure_test.sh`.
  - P1 release/install/dark-site hardening: installed `verify-release` now dispatches to an installed helper, repo-only packaging/install commands fail clearly outside a checkout, `verify-install` validates installed helper/systemd layout more accurately, uninstall removes the installed CLI/share payloads, and dark-site/upgrade docs now match the real tarball flow.
    - Proof: `tests/install/installed_verify_release_dispatch_test.sh`, `tests/install/installed_make_tarball_requires_checkout_test.sh`, `tests/install/verify_install_installed_layout_test.sh`, `tests/install/install_manifest_test.sh`, `tests/release/release_verify_test.sh`, `docs/DARK_SITE.md`, `docs/UPGRADE.md`.
  - P1 plugin/advanced surface hardening: installed-mode plugin index/version defaults now resolve to packaged share assets, corrupt plugin registries fail fast instead of silently degrading, `serve` rejects invalid delegated JSON, and `federate`/`policy lint`/`predict` now enforce stricter input contracts.
    - Proof: `tests/plugin_installed_default_index_test.sh`, `tests/plugin_verify_installed_version_test.sh`, `tests/plugin_registry_invalid_test.sh`, `tests/serve_invalid_json_upstream_test.sh`, `tests/federate_contract_validation_test.sh`, `tests/policy_lint_require_overall_test.sh`, `tests/predict_invalid_history_shape_test.sh`.
  - P1 installer rollback hardening: `install.sh` now supports testable override dirs, preserves the previous installed payload across mid-install failures, and restores systemd/logrotate artifacts if an upgrade aborts.
    - Proof: `tests/install/install_override_layout_test.sh`, `tests/install/install_rollback_prefix_failure_test.sh`, `tests/install/install_rollback_systemd_logrotate_failure_test.sh`, `docs/UPGRADE.md`.
  - P1 audit export hardening: `audit-log --attest` now emits a chain-verified attestation artifact with audit-log SHA256, first/last chain hashes, event counts, overwrite protection, and read-only `--out` files for WORM/object-lock transfer.
    - Proof: `tests/adminops/audit_log_attest_test.sh`, `docs/reference.md`, `docs/QUICK_REFERENCE.md`, `docs/schemas/audit_log.json`.
  - P1 privilege telemetry hardening: wrapper runs now persist per-monitor privilege policy/result/euid telemetry in run state, summary JSON, and `linux-maint report`.
    - Proof: `tests/run/run_privilege_telemetry_test.sh`, `docs/schemas/summary.json`, `docs/schemas/report.json`.
- Resume-from-next-session:
  - Focus on remaining items below in order: security hardening gaps -> operator UX depth -> advanced quality/calibration.

## P0 - Reliability and safety foundation
- `DONE` Strict command contract coverage baseline for key CLI outputs.
  - Proof: multiple command tests under `tests/*_command_test.sh`.
- `DONE` Atomic run locking + stale lock recovery.
  - Proof: `tests/run_lock_test.sh`, `tests/run_lock_stale_meta_test.sh`.
- `PARTIAL` Crash-safe artifact writing (`*.tmp` + atomic rename) coverage.
  - Implemented in several command paths; not yet fully audited for every artifact writer.
- `PARTIAL` End-to-end idempotency checks for repeated runs.
  - Some behavior tested indirectly; no dedicated full idempotency suite yet.
- `DONE` `self-check --strict`.
  - Proof: `tests/core/self_check_strict_test.sh`.

## P1 - Fleet-grade execution engine
- `DONE` Parallel/timeout/retry controls (`--parallel`, `--host-timeout`, `--retry`).
- `DONE` Execution strategy fields (`fail-soft`, `fail-fast`, `quorum`) in run planning.
  - Proof: `tests/run/run_plan_strategy_fields_test.sh`.
- `DONE` Resumable runs (`run --resume`).
  - Proof: `tests/run/run_resume_state_test.sh`.
- `PARTIAL` Inventory backends.
  - Static file path is present; dynamic/cloud adapters (AWS/GCP/Azure) not implemented.
- `DONE` Maintenance windows + drain file gating.
  - Proof: `tests/run/run_maintenance_window_gate_test.sh`, `tests/run_drain_file_plan_test.sh`.
- `NEXT` 1k-host simulation fixture with deterministic bounded runtime.

## P1 - Security hardening
- `PARTIAL` Signed artifacts + verification flow.
  - Some release verification tooling exists; full signing workflow hardening remains.
- `PARTIAL` Secrets policy engine.
  - Redaction exists; dedicated denylist+entropy+context policy engine not fully implemented.
- `PARTIAL` Per-monitor privilege policy (`requires_root`, `allow_sudo`, `no_sudo`).
  - Baseline enforcement in `linux-maint run` via `monitor_privilege_policy.conf`.
  - Run artifacts and reports now include local per-monitor policy/result/euid telemetry.
  - Missing: remote host privilege telemetry and external policy attestation.
- `PARTIAL` Immutable audit log stream for critical actions.
  - Baseline append-only audit stream added (`linux-maint audit-log`), with chained hashes and events for `run`, `doctor --fix`, `pack-logs`, plugin install/update/remove.
  - Added tamper verification command: `linux-maint audit-log --verify` (validates chain integrity).
  - Added portable attestation export: `linux-maint audit-log --attest [--json] [--out FILE]` with SHA256, chain anchors, event counts, and read-only no-overwrite output files for WORM/object-lock transfer.
  - Missing: native write-once filesystem controls and external signer/service integration.
- `NEXT` Optional FIPS-friendly crypto mode checks.
- `DONE` Security posture report command.
  - Proof: `linux-maint security-profile`, `tests/core/security_profile_command_test.sh`.

## P2 - Operator UX (CLI + Menu)
- `DONE` Incident Mode v1 in menu (guided flow baseline).
- `PARTIAL` Persistent profile system (`default/prod/lab`) with overlays.
- `NEXT` Interactive remediator queue with per-host confirm/deny.
- `PARTIAL` Rich TUI dashboard/drilldown improvements (ongoing).
- `PARTIAL` Offline-first operation pack (parts present; not fully productized).
- `NEXT` First-time operator <10 minutes acceptance benchmark.

## P2 - Data and analytics
- `DONE` Run history SQLite prototype (`history --sqlite`).
  - Proof: `tests/core/history_sqlite_test.sh`.
- `DONE` Trend anomaly detection (z-score / rolling baseline) baseline.
  - Proof: `linux-maint trend --anomaly --anomaly-window N --anomaly-z N`, `tests/reporting/trend_anomaly_test.sh`.
- `PARTIAL` Diff intelligence/root-cause hints.
- `DONE` Runtime profiling and slow-monitor warning baseline.
- `PARTIAL` Export pipeline depth.
  - JSON/JSONL/CSV exports are implemented with tests.
  - Missing: richer OpenMetrics histogram buckets/percentiles.
- `DONE` 100k+ record performance validation baseline for `history`/`trend`.
  - Proof: `tests/core/history_large_index_perf_test.sh`, `tests/reporting/trend_large_fixture_perf_test.sh`.
  - Note: this is a fixture-level baseline, not a full multi-node production load benchmark.

## P3 - Plugin and extension ecosystem
- `DONE` Plugin SDK baseline docs and examples.
  - Proof: `docs/PLUGIN_SDK.md`, `plugins/`.
- `PARTIAL` Marketplace index format.
  - Local index format now has trust/compatibility/signature metadata checks via `plugin search --strict` / `plugin lint-index --strict`.
  - Added cryptographic index attestation verification via `plugin verify-index` (`sha256|gpg|cosign`) and strict enforcement hooks.
  - Added trust policy lifecycle baseline (`LM_PLUGIN_TRUST_POLICY_FILE`, revoked/trusted lists, required-policy enforcement).
  - Added consolidated provenance artifact command: `plugin provenance-report` (index attestation + policy context + plugin verify outcomes).
  - Missing: managed remote keyring distribution/provenance service integration.
- `PARTIAL` Plugin lifecycle commands.
  - Implemented: `search/lint-index/install/update/remove/list/verify/init`.
  - Added baseline cryptographic checks: `plugin verify` validates `signature.type=sha256|gpg|cosign`.
  - Added trust-policy enforcement hooks for `plugin verify` and index attestation validation.
  - Missing: remote source update adapters and managed provenance service integration.
- `PARTIAL` Monitor scaffolding generator.
  - Plugin scaffold exists; full monitor scaffold with test/doc templates still pending.
- `NEXT` Plugin sandbox mode (resource/syscall/network restrictions).
- `NEXT` Third-party monitor install/validate in <5 minutes acceptance check.

## P3 - Integrations and automation
- `PARTIAL` Notification providers.
  - Implemented baseline: webhook/slack/teams/email/pagerduty test sender.
  - Missing: production-grade provider adapters/config validation and incident routing templates.
- `PARTIAL` Ticketing integrations (Jira, ServiceNow).
  - Baseline adapters implemented via `linux-maint ticket --provider jira|servicenow` (`--dry-run` friendly).
  - Missing: auth flows, field mapping templates, retries/backoff, and production policy integration.
- `PARTIAL` Config management hooks (Ansible, Puppet, Salt).
  - Baseline command added: `linux-maint cm-hook --provider ansible|puppet|salt` (with `--dry-run`).
  - Missing: authenticated remote execution profiles, result ingestion, and policy-driven retries.
- `DONE` CI quality gate command.
  - Proof: `linux-maint gate --policy`, `tests/advanced/gate_command_test.sh`.
- `DONE` REST API service mode baseline.
  - Proof: `linux-maint serve`, `tests/advanced/serve_command_test.sh`.
  - Hardening: concurrent request handling plus bounded delegated command runtime via `LM_SERVE_CMD_TIMEOUT`.
- `DONE` Pipeline deployment-block acceptance flow documented end-to-end.
  - Proof: `docs/OPERATIONS.md` section "CI deploy gate (block on health regression)".

## P4 - Advanced capabilities
- `DONE` Optional lightweight agent baseline.
  - Proof: `linux-maint agent`, `tests/advanced/agent_command_test.sh`.
  - Hardening: reject `--interval 0` so agent mode cannot spin in a tight loop.
  - Hardening: finite agent runs now preserve delegated `run` failures in their exit code.
- `DONE` Policy-as-code baseline (`policy init/lint/eval`).
  - Proof: `tests/advanced/policy_command_test.sh`.
  - Hardening: `gate`/`policy eval` now fail fast if delegated `status --json` data is unavailable or invalid.
- `DONE` AI-assist baseline (local heuristic hints).
  - Proof: `linux-maint ai-assist`, `tests/advanced/ai_assist_command_test.sh`.
  - Hardening: fail fast if delegated `status --json` data is unavailable or invalid.
- `DONE` Federation baseline (`federate`).
  - Proof: `tests/federate_command_test.sh`.
  - Hardening: unreadable or invalid input snapshots now fail fast with rc=2 instead of being silently skipped.
- `DONE` Predictive score baseline (`predict`).
  - Proof: `tests/advanced/predict_command_test.sh`.
  - Hardening: reject `--last 0` instead of silently degrading to an empty-history result.
  - Hardening: no-history environments now return a valid empty-history prediction instead of failing the command.
  - Hardening: fail fast if delegated `history --json` data is unavailable or invalid.
- `PARTIAL` Advanced acceptance closure:
  - modules are optional and docs include risk boundaries.
  - confidence outputs added to `ai-assist` and `predict`.
  - remaining gaps: calibration quality, feedback loops, and production hardening.

## Cross-cutting quality bar
- `PARTIAL` CLI help/docs updates are consistently done for most new features.
- `DONE` Operator TUI polish:
  - `linux-maint menu` now has a richer gum landing layout, section-level recommended-start panels, `?` help overlay text, `/` command-palette wiring, and a guided support-bundle wizard.
  - Added golden coverage for compact/main and full section menu rendering plus overlay/wizard regressions.
  - Proof: `tests/menu/menu_compact_frame_fixture_test.sh`, `tests/menu/menu_section_frame_fixture_test.sh`, `tests/menu/menu_help_overlay_text_test.sh`, `tests/menu/menu_pack_logs_wizard_test.sh`, `tests/menu/menu_tty_flow_smoke_test.sh`.
- `DONE` CLI/operator copy polish:
  - top-level `linux-maint help` is now workflow-first, grouped by operator task, includes menu-section orientation, and uses clearer examples-by-task instead of a flat command dump.
  - main menu and submenu labels now use shorter, more professional operator wording aligned with the help text.
  - Proof: `tests/menu/help_top_level_structure_test.sh`, `tests/menu/help_repo_usage_test.sh`, `tests/menu/help_menu_structure_test.sh`, `tests/menu/menu_compact_frame_fixture_test.sh`, `tests/menu/menu_section_frame_fixture_test.sh`.
- `DONE` Help + quickstart hardening:
  - normalized key operator `help <command>` pages around consistent sections (`Purpose`, `When to use`, `Key flags`, `Examples`, and mode/exit notes where relevant).
  - added a dedicated `Quickstart` menu path for first setup, current incident triage, and escalation/export workflow.
  - expanded golden coverage for top-level help, `help menu`, and all main menu sub-sections.
  - Proof: `tests/menu/help_command_consistency_test.sh`, `tests/menu/help_top_level_golden_test.sh`, `tests/menu/help_menu_golden_test.sh`, `tests/menu/menu_all_sections_fixture_test.sh`.
- `DONE` Menu onboarding + palette depth:
  - `linux-maint menu` now has a smarter `/` palette with task-word aliases and context-aware ranking, section-specific empty states for missing summary/log/history/config, and a guided first-setup bootstrap wizard with optional baseline capture.
  - updated help/docs so the new bootstrap and smart palette behavior is discoverable from `help menu` and the quick reference.
  - Proof: `tests/menu/menu_palette_rank_test.sh`, `tests/menu/menu_empty_state_preview_test.sh`, `tests/menu/menu_first_setup_wizard_test.sh`, `tests/menu/menu_help_overlay_text_test.sh`, `tests/menu/help_menu_golden_test.sh`.
- `DONE` Fallback menu + command preview polish:
  - `dialog`/`whiptail` menus now render the same context/readiness/recommended-start summary as the richer gum flow instead of a bare prompt.
  - command execution previews now summarize reads, writes, risk, and likely next step before running.
  - Proof: `tests/menu/menu_fallback_prompt_test.sh`, `tests/menu/menu_command_preview_test.sh`, `tests/menu/menu_return_to_main_after_failure_test.sh`.
- `DONE` In-menu action preview + Quickstart shortcuts:
  - gum menus now support visible action previews from inside the menu before selection, and the full section layout shows a recommended action preview card.
  - Quickstart now has direct shortcuts for editing `servers.txt`, opening `hosts.d`, and opening key setup docs.
  - Proof: `tests/menu/menu_action_preview_text_test.sh`, `tests/menu/menu_quickstart_shortcuts_test.sh`, `tests/menu/menu_help_overlay_text_test.sh`, `tests/menu/menu_all_sections_fixture_test.sh`.
- `PARTIAL` JSON schema coverage is incomplete for some newly added commands.
  - Hardening: `report` and `summary` now fail fast instead of silently degrading when `status --json` is broken.
  - Added schema coverage for `export --jsonl` rows and `ticket/cm-hook/audit-log` JSON contracts.
  - Added schema coverage for `plugin verify-index --json` and `plugin verify --json`.
  - Remaining: extend schemas to all advanced optional command JSON outputs.
- `PARTIAL` cancellation-path tests are not present for every new feature.
- `NEXT` Release-note entry automation for each merged feature batch.
- `NEXT` Security review checklist updates for every auth/exec/secrets-touching change.
- `NEXT` CI upgrades:
  - nightly long-run regression job,
  - performance budget checks,
  - flaky test detector/quarantine workflow.

## Next implementation queue (strict order)
1. P1 security: native write-once audit storage controls and external signer/service integration.
2. P1 security: remote host privilege telemetry and external policy attestation.
3. P2 UX: interactive remediator queue (host-by-host confirm/deny with safe defaults).
4. P4 depth: calibration/feedback loop for `ai-assist` and `predict` confidence outputs.
5. P3 hardening (final): managed remote keyring distribution + signed provenance service integration.
