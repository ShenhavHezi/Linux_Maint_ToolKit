# Command contract checklist (status / report / summary / diff)

Purpose: keep operator-facing output stable and machine-parseable.

Use this checklist any time you change output formatting, filters, JSON shape, or exit behavior for:
- `linux-maint status`
- `linux-maint report`
- `linux-maint summary`
- `linux-maint diff`

## Cross-cutting checks
- [ ] Outputs that are machine-parseable (`--json`, `--prom`, CSV, summary lines) never include ANSI/control chars.
- [ ] `NO_COLOR=1` reliably disables ANSI; `LM_FORCE_COLOR=1` enables ANSI for table/human views only.
- [ ] No extra stdout noise (debug/progress) is added to these commands.
- [ ] Any new output fields are documented in `docs/reference.md` and `docs/QUICK_REFERENCE.md` if user-facing.
- [ ] If JSON keys/types change, bump the related `*_json_contract_version` and update the schema in `docs/schemas/`.

## `status` checklist
- [ ] Default output still includes `totals:` and a `problems:` header.
- [ ] `--summary` includes `overall=`.
- [ ] `--summary --table` includes the `STATUS  MONITOR` header.
- [ ] `--compact` omits the large section headers.
- [ ] `--json` validates against `docs/schemas/status.json` and keeps `status_json_contract_version` in sync.
- [ ] `--prom` remains parseable and ANSI-free.
- [ ] `--strict` fails non-zero with a clear error if summary/JSON are malformed.

Suggested tests:
- `tests/status_contract_test.sh`
- `tests/status_summary_test.sh`
- `tests/status_json_schema_test.sh`
- `tests/status_json_compat_test.sh`
- `tests/status_last_color_test.sh`
- `tests/status_prom_test.sh`
- `tests/json_output_clean_test.sh`

## `report` checklist
- [ ] Header `=== linux-maint report ===` still prints and `mode=` is present.
- [ ] `--compact` includes a `totals:` line.
- [ ] `--table` includes the `STATUS  MONITOR` header and totals table.
- [ ] `--json` validates against `docs/schemas/report.json` and keeps `report_json_contract_version` in sync.
- [ ] ANSI behavior matches `NO_COLOR` and `LM_FORCE_COLOR` expectations.

Suggested tests:
- `tests/report_command_test.sh`
- `tests/report_short_test.sh`
- `tests/json_output_clean_test.sh`

## `summary` checklist
- [ ] Output includes `overall=` and stays single-line.
- [ ] `NO_COLOR=1` produces ANSI-free output.
- [ ] No extra lines are printed to stdout.

Suggested tests:
- `tests/summary_command_test.sh`
- `tests/json_output_clean_test.sh`

## `diff` checklist
- [ ] Uses last summary monitor-lines from state dir and reports deltas consistently.
- [ ] ANSI is present only when color is enabled, and never when `NO_COLOR=1`.
- [ ] Output remains human-readable without impacting machine outputs.

Suggested tests:
- `tests/diff_color_test.sh`
- `tests/summary_diff_canonicalization_test.sh`
