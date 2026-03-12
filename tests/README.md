# Test Layout

This directory contains the Bash-first regression suite for `linux-maint`.

## Main groups

- command tests: `*_command_test.sh`
- contract/schema tests: `*_schema_test.sh`, `*_json_test.sh`
- regression and edge-case tests: targeted `*_test.sh`
- area subdirectories for the busiest command surfaces:
  - `run/`
  - `reporting/`
  - `advanced/`
  - `adminops/`
  - `core/`
  - `inspect/`
  - `install/`
  - `release/`
  - `runtime/`
  - `menu/`
  - `wrapper/`
- smoke and aggregate entrypoints:
  - `smoke.sh`
  - `summary_contract.sh`
- helpers:
  - `testlib.sh`
- golden fixtures:
  - `fixtures/`

## Expected usage

- fast local confidence: `make quick-check`
- broader repo smoke: `bash tests/smoke.sh`
- summary/monitor contract checks: `bash tests/summary_contract.sh`

The suite is intentionally shell-heavy so it matches the runtime environment of the toolkit itself.

## Area directories

- `run/`: `linux-maint run` planning, resume, and execution regressions
- `reporting/`: `status`, `report`, `metrics`, `trend`, `export`, `runtimes`, `diff`, `logs`, and report/TUI output fixtures
- `advanced/`: plugin, serve, agent, policy, predict, ai-assist, federate, gate, and related advanced-command tests
- `adminops/`: notify, ticket, audit-log, and cm-hook regressions
- `core/`: config, check, doctor, history, pack-logs, explain, and related core command regressions
- `inspect/`: monitor listing and summary-lint inspection tests
- `install/`: install, init, preflight, upgrade, RPM, installed-mode, and payload-parity tests
- `release/`: tarball and release-discipline verification tests
- `runtime/`: shared library helpers, monitor/runtime checks, summary contract helpers, and monitor-focused regressions
- `menu/`: TUI, menu flow, and help/UX regression tests
- `wrapper/`: wrapper-side artifact, fallback, and failure-path tests
