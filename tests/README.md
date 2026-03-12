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
  - `inspect/`
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
- `reporting/`: `diff`, `logs`, and closely related output fixtures
- `advanced/`: `gate` and adjacent advanced-command contract tests
- `inspect/`: monitor listing and summary-lint inspection tests
