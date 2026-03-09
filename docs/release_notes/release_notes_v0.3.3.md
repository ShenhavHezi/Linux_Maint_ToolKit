# Release Notes v0.3.3

- Version: 0.3.3
- Date (UTC): 2026-03-09
- Git tag: v0.3.3

## Highlights
- Hardened repo-mode behavior so config, logs, history, readiness checks, support bundles, and operator commands consistently honor repo-local paths and overrides.
- Added fail-fast validation and explicit contract/version coverage across the remaining machine-facing CLI surfaces.
- Stabilized advanced and integration commands including `serve`, `agent`, `predict`, `ai-assist`, `federate`, plugin install/update flows, outbound `curl` helpers, and audit-log concurrency.
- Reworked `linux-maint menu` into a stronger operations console with Quickstart, dashboard context, guided incident flow, smart palette/search, action previews, and better fallback backends.

## Repo-mode and operator reliability
- Fixed repo-mode wrapper/runtime path handling:
  - writable default logfile behavior
  - repo fallback config propagation via `LM_CFG_DIR`
  - monitor-side config path consistency for cert/network/backup checks
  - clean summary host counters and corrected early-exit rc reporting
- Hardened read-only operator paths so they no longer create directories or mutate repo-local state during inspection flows.
- Made repo/install guidance mode-aware across:
  - `doctor`
  - `verify-install`
  - `preflight`
  - `init`
  - `run --plan`
  - `status`
  - `history`
  - `pack-logs`
  - `help`, `explain`, and related operator docs

## Command contracts and failure handling
- Added or tightened explicit versioned JSON contracts for:
  - `check`
  - `config`
  - `doctor`
  - `self-check`
  - `security-profile`
  - `trend`
  - `runtimes`
  - `export`
  - `history`
  - `run-index`
- Hardened fail-fast behavior so commands no longer emit plausible partial output after invalid upstream state:
  - `gate`
  - `report`
  - `summary`
  - `metrics`
  - `ai-assist`
  - `predict`
  - `federate`
- Fixed read/write error handling for:
  - `run-index --prune`
  - corrupt `history` index lines
  - `check` exit propagation
  - `pack-logs` gpg prerequisite and symlink packaging paths

## Advanced commands and integrations
- Hardened plugin lifecycle behavior:
  - force-install/update rollback safety
  - preserved installed plugin on failed replacement
- Added bounded timeouts for outbound `curl` paths in:
  - `notify`
  - `ticket`
- Serialized audit hash-chain writes so concurrent appenders no longer break verification.
- Hardened advanced optional commands:
  - `serve` threaded execution and command timeout behavior
  - Python 3.6-safe subprocess text handling for Ubuntu 18.04
  - `agent` interval validation and non-zero delegated failure propagation
  - `predict` validation for empty/invalid history and invalid `--last`
  - `ai-assist` invalid status handling
  - `federate` invalid/unreadable input failure handling

## Menu and CLI overhaul
- Reorganized `linux-maint menu` into task-based sections:
  - `Quickstart`
  - `Overview`
  - `Run`
  - `Investigate`
  - `Repair`
  - `Export`
  - `Docs`
- Added a stronger landing dashboard with:
  - repo/install context
  - readiness summary
  - top reason/problem hints
  - recommended next actions
- Added deeper guided operator flows:
  - first setup bootstrap
  - current incident triage
  - escalation/support bundle workflow
- Added smart palette/search aliases and ranking for task words like:
  - `first run`
  - `triage`
  - `bundle`
  - `report`
  - `logs`
  - `doctor`
- Added action previews across the menu:
  - risk
  - reads
  - writes
  - likely next step
- Added Quickstart shortcuts for:
  - direct `servers.txt` editing
  - `hosts.d` overview
  - key setup docs
- Brought `dialog`/`whiptail` flows closer to the richer `gum` presentation and tightened return-to-main behavior after failed commands.
- Normalized top-level and operator help into a more consistent workflow-first shape and added broader golden coverage for menu/help rendering.

## CI, compatibility, and test coverage
- Fixed CI regressions in ShellCheck, root-compat tests, and Ubuntu/Debian compatibility jobs.
- Restored Python 3.6 compatibility where needed for the compat matrix.
- Fixed `verify-release` to accept tarballs with root `./BUILD_INFO` and `./VERSION` entries emitted by `make_tarball.sh`.
- Added broad regression coverage across:
  - repo-mode path behavior
  - command-contract/error-path handling
  - serve/agent/predict/ai-assist/federate behavior
  - support bundle packaging
  - menu fixtures, goldens, shortcuts, overlays, palette ranking, empty states, and Quickstart flows

## Compatibility notes
- No intended schema-breaking release; existing contract versions remain stable where output shapes did not require a bump.
- This release is stricter about invalid upstream state and corrupt artifacts. Commands that previously degraded to partial success may now exit non-zero with explicit errors.
- Repo-mode operators should see fewer installed-path leaks, fewer accidental side effects from read-only commands, and a more guided first-run/menu experience.
