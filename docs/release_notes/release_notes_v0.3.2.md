# Release Notes v0.3.2

- Version: 0.3.2
- Date (UTC): 2026-03-02
- Git tag: v0.3.2

[Release history](README.md) · [Upgrade guide](../UPGRADE.md)

## Highlights
- Expanded plugin supply-chain hardening with marketplace attestation verification and trust-policy enforcement.
- Added tamper-detection verification for audit log hash-chain integrity.
- Added provenance/compliance reporting for plugin trust and signature outcomes.
- Expanded export/integration contracts with `export --jsonl` and new JSON schema coverage.

## Security and trust hardening
- Added `linux-maint plugin verify-index`:
  - verifies top-level marketplace `attestation` metadata.
  - supports `attestation.type=sha256|gpg|cosign`.
  - strict mode fails when attestation validation fails.
- Added trust-policy lifecycle enforcement:
  - `LM_PLUGIN_TRUST_POLICY_FILE` (default `/etc/linux_maint/plugin_trust_policy.json`).
  - `LM_PLUGIN_REQUIRE_TRUST_POLICY=1` (strict mode requires trust policy file).
  - trusted/revoked lists for:
    - SHA-256 digests
    - GPG signer fingerprints
    - Cosign public-key hashes
- Added trust-policy checks to both:
  - `plugin verify-index --strict`
  - `plugin verify <name>`
- Added `linux-maint audit-log --verify` and `--verify --json`:
  - validates `prev_hash`/`chain_hash` integrity across events.
  - exits non-zero on tamper/parse mismatch.

## Provenance and compliance artifact
- Added `linux-maint plugin provenance-report`:
  - aggregates index attestation verification.
  - captures trust-policy file context (path/existence/hash).
  - evaluates installed plugins via `plugin verify --json`.
  - emits summary (`plugins_ok/plugins_failed/index_ok/overall_ok`).
  - supports:
    - `--json` for automation
    - `--out FILE` for persisted artifact
    - `--strict` to fail CI gates on provenance issues

## Export and integration contract improvements
- Added `linux-maint export --jsonl` for stream-friendly row export.
- Added JSON contract output and schema validation for:
  - `ticket --json`
  - `cm-hook --json`
  - `audit-log --json`
  - `plugin verify-index --json`
  - `plugin verify --json`
- Added schema for JSONL row contract:
  - `docs/schemas/export_jsonl_row.json`

## Operator-facing templates and docs
- Added trust-policy template:
  - `etc/linux_maint/plugin_trust_policy.json.example`
- Updated:
  - `docs/PLUGIN_SDK.md`
  - `docs/reference.md`
  - `docs/QUICK_REFERENCE.md`
  - `docs/ARTIFACTS.md`
  - `ToDoList.txt` session checkpoint and queue state

## Test coverage added
- `tests/export_jsonl_test.sh`
- `tests/export_jsonl_schema_test.sh`
- `tests/ticket_json_schema_test.sh`
- `tests/cm_hook_json_schema_test.sh`
- `tests/audit_log_json_schema_test.sh`
- `tests/audit_log_verify_tamper_test.sh`
- `tests/plugin_verify_index_attestation_test.sh`
- `tests/plugin_trust_policy_test.sh`
- `tests/plugin_verify_trust_policy_test.sh`
- `tests/plugin_verify_index_json_schema_test.sh`
- `tests/plugin_verify_json_schema_test.sh`
- `tests/plugin_provenance_report_test.sh`
- plus smoke wiring updates for all above

## Compatibility notes
- Backward compatible command surfaces; new capabilities are opt-in.
- Strict policy environment flags (`LM_PLUGIN_REQUIRE_ATTEST`, `LM_PLUGIN_REQUIRE_TRUST_POLICY`) can intentionally fail previously permissive flows until policy/attestation is configured.
