## Core Tests

This directory holds the core command-surface regressions for `linux-maint`, including:

- `config`
- `check`
- `doctor`
- `history` / `run-index`
- `baseline`
- `explain`
- `pack-logs`
- `security-profile`
- `self-check`
- JSON/output hygiene checks tied to those commands

Keep command-contract and operator-facing behavior tests here when they do not belong to a
more specialized area like `reporting/`, `run/`, or `advanced/`.
