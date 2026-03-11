# Command Contract Checklist

Use this checklist before merging changes that affect operator-facing or machine-facing command output.

Primary scope:

- `linux-maint status`
- `linux-maint report`
- `linux-maint summary`
- `linux-maint diff`

## Use this checklist when

- text layout changes
- JSON shape changes
- filtering behavior changes
- ANSI/color behavior changes
- exit behavior changes
- new fields are added to automation output

## Cross-cutting checks

- [ ] Machine-readable outputs (`--json`, `--prom`, CSV, summary lines) stay ANSI-free and parser-safe
- [ ] `NO_COLOR=1` disables color reliably
- [ ] `LM_FORCE_COLOR=1` affects only human/table views
- [ ] No debug or progress noise is added to stdout for machine-facing commands
- [ ] New user-facing fields are documented in [reference.md](reference.md) and [QUICK_REFERENCE.md](QUICK_REFERENCE.md) when appropriate
- [ ] If JSON keys or types change, bump the matching `*_json_contract_version` and update the schema under `docs/schemas/`

## `status`

- [ ] Default output still includes `totals:` and `problems:`
- [ ] `--summary` still includes `overall=`
- [ ] `--summary --table` still includes the `STATUS  MONITOR` header
- [ ] `--compact` still omits the large section headers
- [ ] `--json` still validates against `docs/schemas/status.json`
- [ ] `--prom` stays parseable and ANSI-free
- [ ] `--strict` fails clearly when summary or JSON input is malformed

Suggested tests:

- `tests/status_contract_test.sh`
- `tests/status_summary_test.sh`
- `tests/status_json_schema_test.sh`
- `tests/status_json_compat_test.sh`
- `tests/status_last_color_test.sh`
- `tests/status_prom_test.sh`
- `tests/json_output_clean_test.sh`

## `report`

- [ ] Header `=== linux-maint report ===` still prints and `mode=` remains present
- [ ] `--compact` still includes a `totals:` line
- [ ] `--table` still includes the `STATUS  MONITOR` header and totals table
- [ ] `--json` still validates against `docs/schemas/report.json`
- [ ] ANSI behavior still matches `NO_COLOR` and `LM_FORCE_COLOR`

Suggested tests:

- `tests/report_command_test.sh`
- `tests/report_short_test.sh`
- `tests/json_output_clean_test.sh`

## `summary`

- [ ] Output still includes `overall=`
- [ ] Output stays single-line
- [ ] `NO_COLOR=1` stays ANSI-free
- [ ] No extra stdout lines are introduced

Suggested tests:

- `tests/summary_command_test.sh`
- `tests/json_output_clean_test.sh`

## `diff`

- [ ] State-file driven comparison still works from the active state dir
- [ ] Delta reporting remains stable for new failures, recovered items, and still-bad rows
- [ ] ANSI appears only when color is enabled
- [ ] Human readability changes do not leak into machine outputs

Suggested tests:

- `tests/diff_color_test.sh`
- `tests/summary_diff_canonicalization_test.sh`
