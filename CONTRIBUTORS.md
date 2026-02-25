# Contributors Guide

Thanks for improving Linux_Maint_ToolKit. This is a lightweight Bash-first project; keep changes minimal and reversible.

## Workflow
1. Create a focused change set (one feature or fix).
2. Update tests and docs for any behavior changes.
3. Run `make lint` and `make test` (or `make ci-local`).
4. Open a PR with a clear summary and testing notes.

## Testing expectations
- Contract tests must pass: summary lint, JSON schema, and smoke suite.
- Avoid introducing new runtime dependencies.
- New CLI flags require help text updates and doc examples.

## Release flow (maintainers)
- Update `VERSION`, `CHANGELOG.md`, and add release notes under `docs/release_notes/`.
- Use `tools/release.sh` to generate tarball + checksum.
- Verify with `linux-maint verify-release`.

## Quick commands
```bash
make lint
make test
make ci-local
```
