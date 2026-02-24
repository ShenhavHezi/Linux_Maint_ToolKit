# Development

Contributor-facing notes that do not belong on the README.

## Tests

```bash
bash tests/smoke.sh
bash tests/summary_contract.sh  # when touching summary/json/monitor output
```

## Release workflow

- Checklist: `docs/RELEASE_CHECKLIST.md`
- Template: `docs/RELEASE_TEMPLATE.md`
- Draft release workflow: `.github/workflows/release_notes.yml`
- Release notes archive: `docs/release_notes/release_notes_v*.md`

## Repo tools

- Release verification: `tools/release_check.sh`
- Tarball build: `tools/make_tarball.sh`
