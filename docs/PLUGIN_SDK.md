# Plugin SDK

Use this page when you want to build, verify, or distribute a `linux-maint` plugin.

This is the local-directory plugin model used by the current project.

## What a plugin is

A plugin is a directory with metadata and payload files that `linux-maint plugin ...` can install, verify, update, and remove.

The current model is intentionally simple:

- local directory source
- JSON manifest
- optional trust and attestation metadata
- compatibility checks against the CLI version

## Minimal manifest

Each plugin directory should include `plugin.json`:

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

## Typical workflow

### 1. Create the plugin directory

Add your plugin files and `plugin.json`.

### 2. Install it

```bash
linux-maint plugin install ./my_plugin
```

### 3. Verify it

```bash
linux-maint plugin verify my_plugin --json
```

### 4. Update or remove it

```bash
linux-maint plugin update my_plugin --source ./my_plugin
linux-maint plugin remove my_plugin
```

## Useful commands

- `linux-maint plugin list [--json]`
- `linux-maint plugin search [--index FILE] [--json] [--strict]`
- `linux-maint plugin lint-index [--index FILE] [--json] [--strict]`
- `linux-maint plugin verify-index [--index FILE] [--json] [--strict]`
- `linux-maint plugin provenance-report [--index FILE] [--out FILE] [--json] [--strict]`
- `linux-maint plugin install <source_dir> [--name NAME] [--force]`
- `linux-maint plugin update <name> [--source DIR] [--index FILE] [--force]`
- `linux-maint plugin verify <name> [--json]`
- `linux-maint plugin remove <name>`

## Paths and defaults

Plugin root defaults:

- repo mode: `./plugins`
- installed mode: `/var/lib/linux_maint/plugins`

Marketplace index defaults:

- repo mode: `./plugins/index.json`
- installed mode: `/usr/local/share/linux_maint/plugins/index.json`

Override plugin root with:

- `LM_PLUGIN_DIR`

## Trust and verification

Supported signature and attestation models:

- `sha256`
- `gpg`
- `cosign`

Useful policy controls:

- `LM_PLUGIN_TRUST_POLICY_FILE=/etc/linux_maint/plugin_trust_policy.json`
- `LM_PLUGIN_REQUIRE_TRUST_POLICY=1`
- `LM_PLUGIN_REQUIRE_ATTEST=1`

Trust policy supports trusted and revoked material for:

- SHA-256 digests
- GPG fingerprints
- Cosign key digests

Template:

- `etc/linux_maint/plugin_trust_policy.json.example`

## Behavior that matters operationally

- `plugin list` and `plugin remove` fail fast on a corrupt registry
- forced install/update uses staging so a failed replacement should preserve the previous plugin
- installed-mode compatibility checks use the packaged `VERSION` file when available
- `plugin provenance-report` consolidates index verification, trust policy context, and installed plugin verification results

## When to use strict mode

Use strict index and trust flows when:

- plugins come from multiple sources
- you need provenance gates in CI or packaging
- you want hard failure on missing or invalid attestation

## Related docs

- [reference.md](reference.md) for exact plugin command behavior
- [../CONTRIBUTING.md](../CONTRIBUTING.md) for repo contribution workflow
