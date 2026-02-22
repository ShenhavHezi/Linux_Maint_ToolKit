# AGENTS.md — Linux-Maint-ToolBox (RHEL 9)

Target: RHEL 9. Offline/dark-site friendly. Bash only.
No new runtime dependencies.

## Non-negotiables
- Preserve machine outputs: JSON/summary must stay clean.
- Any progress UI must go to stderr.
- Preserve summary contract keys (parse-safe): monitor=... host=... status=... reason=...
- Prefer minimal patches; no refactors unless requested.
- Any behavior/output change requires: tests update + docs update.
- Keep docs under `docs/` (release notes are archived in `docs/`, not `dist/`).
- Update `ToDoList.txt` when behavior or operator-facing docs change.

## Required local tests (before declaring DONE)
- bash tests/smoke.sh
- bash tests/summary_contract.sh (when touching summary/json/monitor output)
