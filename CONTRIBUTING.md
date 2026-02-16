# Contributing to linux-maint

Thanks for contributing!

This repo is a working Linux maintenance toolkit. Please keep changes small, safe, and compatible.

## Development workflow

### Lint

Run ShellCheck using the repo configuration (`.shellcheckrc`):

```bash
make lint
```

Notes:
- `.shellcheckrc` is the single source of truth.
- Do **not** globally exclude `SC2086`.
- If a warning is intentional, disable it **locally** in code with a `# shellcheck disable=...` comment.

### Tests

```bash
make test
```

This runs the same core checks as CI (summary contract + smoke).

## Monitor output contract (summary lines)

Each monitor should emit at least one machine-parseable summary line:

```text
monitor=<name> host=<target> status=<OK|WARN|CRIT|UNKNOWN|SKIP> node=<runner> [reason=<token>] [key=value ...]
```

- Use `lm_summary()` from `lib/linux_maint.sh`.
- For non-OK statuses (`WARN|CRIT|UNKNOWN|SKIP`), include `reason=<token>`.
- See:
  - `docs/reference.md` (full contract)
  - `docs/REASONS.md` (reason vocabulary)

## Exit codes

Project standard:
- `0` = OK
- `1` = WARN
- `2` = CRIT
- `3` = UNKNOWN/ERROR

The wrapper returns the worst exit code across executed monitors.

## Adding or changing a monitor

1. Add the script under `monitors/`.
2. Source the shared library:

   ```bash
   . "${LINUX_MAINT_LIB:-/usr/local/lib/linux_maint.sh}" || exit 1
   ```

3. Ensure the monitor emits `monitor=` summary lines via `lm_summary()` on **all** paths (including early exits).
4. If the monitor is gated by optional config/baselines, prefer `status=SKIP reason=config_missing|baseline_missing` and document expected files in `docs/reference.md`.
5. Add/adjust tests under `tests/` when practical (contract tests are preferred).

## Docs and changelog expectations

Use these files intentionally to reduce merge conflicts:
- Update `ToDoList.txt` only when roadmap scope/priority/status truly changes.
- Update `summarize.txt` only for meaningful capability/architecture snapshots (not routine fixes).
- If summarize autogen markers are touched, run `python3 tools/gen_summarize.py`.

## Git hooks (optional)

This repo includes optional git hooks under `.githooks/`.

```bash
git config core.hooksPath .githooks
```
