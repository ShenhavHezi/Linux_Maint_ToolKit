# Release Notes v0.3.1

- Version: 0.3.1
- Date (UTC): 2026-03-02
- Git tag: v0.3.1

[Release history](README.md) · [Upgrade guide](../UPGRADE.md)

## Highlights
- Hardened run reliability and strict validation paths for safer repeatable operations.
- Added policy/security automation baseline commands for CI and operational gates.
- Expanded plugin and notification integration baseline.
- Introduced P4 advanced optional modules as explicit opt-in commands.

## Reliability and safety
- Improved run resume behavior and stale-lock metadata recovery.
- Added stricter validation gate with `linux-maint self-check --strict`.
- Expanded run-planning and maintenance/drain controls coverage in tests.

## Security and policy
- Added `linux-maint security-profile` with strict mode checks.
- Added `linux-maint gate --policy <file>` for CI/deploy gating decisions.
- Added `linux-maint policy init|lint|eval` helper workflow.

## Plugins and integrations
- Added plugin baseline lifecycle (`list`, `search`, `init`, `install`, `verify`, `remove`).
- Added plugin SDK baseline docs and example structure.
- Added notification command baseline for `webhook|slack|teams|email` (with `--dry-run` support).

## Advanced optional modules (P4 baseline)
- `linux-maint serve` (local REST API mode)
- `linux-maint agent` (lightweight loop runner)
- `linux-maint federate` (multi-status aggregation)
- `linux-maint ai-assist` (local heuristic hints from status artifacts)
- `linux-maint predict` (history-based risk scoring baseline)

These features are optional and operator-invoked; they do not alter default run/report flow unless explicitly used.

## Tests added/expanded
- `tests/security_profile_command_test.sh`
- `tests/gate_command_test.sh`
- `tests/plugin_command_test.sh`
- `tests/plugin_init_test.sh`
- `tests/notify_command_test.sh`
- `tests/serve_command_test.sh`
- `tests/agent_command_test.sh`
- `tests/policy_command_test.sh`
- `tests/federate_command_test.sh`
- `tests/ai_assist_command_test.sh`
- `tests/predict_command_test.sh`
- Additional run reliability tests (`run_resume_state`, `run_lock_stale_meta`, maintenance/drain/strategy plan checks)

## Documentation
- Updated quick reference and command reference for new command surfaces.
- Added plugin SDK documentation and plugin index examples.
- Converted project roadmap `ToDoList.txt` into a session tracking board (`DONE/PARTIAL/NEXT`).

## Upgrade notes
- Backward-compatible release; no schema-breaking changes are intended in this version.
- For advanced modules, start with local/dry-run usage and controlled rollout.
