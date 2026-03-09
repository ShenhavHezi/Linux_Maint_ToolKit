# Plugin SDK (Baseline)

This baseline plugin model is local-directory based.

## Manifest
A plugin directory should include `plugin.json`:

```json
{
  "name": "my_plugin",
  "version": "0.1.0",
  "description": "what this plugin provides",
  "trust": "community",
  "compatibility": {
    "min_cli_version": "0.3.0"
  },
  "signature": {
    "type": "sha256",
    "target": "plugin.json",
    "value": "PUT_SHA256_HEX_HERE",
    "file": "plugin.json.asc",
    "key": "cosign.pub"
  }
}
```

## Commands
- `linux-maint plugin list [--json]`
- `linux-maint plugin search [--index FILE] [--json] [--strict]`
- `linux-maint plugin lint-index [--index FILE] [--json] [--strict]`
- `linux-maint plugin verify-index [--index FILE] [--json] [--strict]`
- `linux-maint plugin provenance-report [--index FILE] [--out FILE] [--json] [--strict]`
- `linux-maint plugin install <source_dir> [--name NAME] [--force]`
- `linux-maint plugin update <name> [--source DIR] [--index FILE] [--force]`
- `linux-maint plugin verify <name> [--json]`
- `linux-maint plugin remove <name>`

## Notes
- In repo mode, plugin root defaults to `./plugins`.
- In installed mode, plugin root defaults to `/var/lib/linux_maint/plugins`.
- Override plugin root with `LM_PLUGIN_DIR`.
- Forced plugin installs/updates are staged into a temporary directory and only swapped into place after the copy succeeds, so a failed replacement should preserve the previously installed plugin.
- `plugin search --strict` and `plugin lint-index --strict` fail on invalid marketplace metadata.
- Marketplace index attestation is supported via top-level `attestation`:
  - `type=sha256` with `target` and `value`
  - `type=gpg` with `target` and signature `file` (default `<target>.asc`)
  - `type=cosign` with `target`, signature `file` (default `<target>.sig`), and `key`
- `plugin verify-index --strict` verifies attestation and fails on invalid signatures.
- `LM_PLUGIN_REQUIRE_ATTEST=1` enforces attestation presence in strict search/lint/verify-index flows.
- Trust policy lifecycle (rotation/revocation):
  - `LM_PLUGIN_TRUST_POLICY_FILE=/etc/linux_maint/plugin_trust_policy.json`
  - `LM_PLUGIN_REQUIRE_TRUST_POLICY=1` fails strict flows when policy file is missing.
  - policy supports:
    - `sha256.trusted_digests` / `sha256.revoked_digests`
    - `gpg.trusted_fingerprints` / `gpg.revoked_fingerprints`
    - `cosign.trusted_key_sha256` / `cosign.revoked_key_sha256`
  - template: `etc/linux_maint/plugin_trust_policy.json.example`
- `plugin verify` performs SHA-256 verification when `signature.type=sha256` (default target: `plugin.json`, configurable with `signature.target`).
- `plugin verify` also supports:
  - `signature.type=gpg` with optional `signature.file` (default: `<target>.asc`).
  - `signature.type=cosign` with `signature.file` (default: `<target>.sig`) and `signature.key`.
- `plugin verify` also applies trust policy revocation/allow lists when `LM_PLUGIN_TRUST_POLICY_FILE` is set.
- `plugin provenance-report` emits a consolidated compliance artifact:
  - index attestation verification result
  - trust-policy file path/hash context
  - per-installed-plugin `plugin verify` outcomes
