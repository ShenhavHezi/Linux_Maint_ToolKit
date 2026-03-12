# Maintainer Rules

Target: RHEL 9. Offline/dark-site friendly. Bash only.
No new runtime dependencies.

## Non-negotiables

- Preserve machine outputs: JSON and summary output must stay clean.
- Any progress UI must go to stderr.
- Preserve summary contract keys: `monitor=... host=... status=... reason=...`
- Prefer minimal patches; avoid broad refactors unless they are intentional and tested.
- Any behavior or output change requires matching tests and docs updates.
- Keep docs under `docs/` and release notes under `docs/release_notes/`, not `dist/`.
- Update [ROADMAP.md](/home/shenhav/Linux_Maint_ToolKit/docs/ROADMAP.md) when maintainer planning materially changes.

## Required local tests

- `bash tests/smoke.sh`
- `bash tests/summary_contract.sh` when touching summary, JSON, or monitor output
