# Release Notes v0.2.2

## Version
- Version: 0.2.2
- Date (UTC): 2026-02-24
- Git tag: v0.2.2

## Highlights
- Safer fleet SSH: known_hosts seeding helper plus allowlist guidance for remote commands.
- Stronger contracts: run_index JSON schema and Prometheus contract notes for stable integrations.
- Smoother release flow: docs link check in CI and a release‑prep helper.

## Breaking changes
- None

## New features
- `tools/seed_known_hosts.sh` to pre‑populate `LM_SSH_KNOWN_HOSTS_FILE` for strict mode.
- `docs/schemas/run_index.json` and `tests/run_index_schema_test.sh` for history/run_index validation.
- Prometheus contract notes (label stability, status encoding, top‑N reason behavior).
- `tools/docs_link_check.sh` wired into CI to catch broken internal links.
- `tools/release_prep.sh` and `make release-prep` to bump version/changelog and draft notes.

## Fixes
- None

## Docs
- Operations quickstart now emphasizes installed mode with a fallback repo flow.
- New upgrade/rollback guide (`docs/UPGRADE.md`).
- Top‑10 reasons quick reference added to `docs/REASONS.md` and linked from operator docs.
- SSH allowlist guidance and strict known_hosts seeding steps added to reference/config docs.

## Compatibility / upgrade notes
- No action required.
