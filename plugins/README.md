# Plugins Directory

This directory contains plugin source metadata and examples.

## Files

- `index.json` — source-controlled plugin catalog used by `plugin search` and packaging.
- `registry.example.json` — example local registry format.
- `examples/` — plugin examples and scaffolds.

## Runtime state

`registry.json` is intentionally **not** tracked in git.

It is local runtime state created or updated by plugin lifecycle commands such as:

- `linux-maint plugin install`
- `linux-maint plugin update`
- `linux-maint plugin remove`

Keeping the live registry out of source control avoids treating machine-local plugin state as product source.

