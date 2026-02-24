# Release Notes v0.2.3

## Version
- Version: 0.2.3
- Date (UTC): 2026-02-24
- Git tag: v0.2.3

## Highlights
- Trend reporting now supports date filters, CSV export, and optional caching.
- Inventory export can reuse recent cached data for faster runs.
- CI and community DX upgrades: fast lane workflow + issue/PR templates.

## Breaking changes
- None

## New features
- `linux-maint trend` adds `--since/--until` date filters and `--csv`/`--export` output modes.
- Optional trend cache (`LM_TREND_CACHE`, `LM_TREND_CACHE_TTL`) with filter-aware reuse.
- `linux-maint report` and `linux-maint trend` support `--redact` for human output.
- `linux-maint run-index` command for stats and pruning (`--stats`, `--prune`, `--keep`).
- Inventory export cache (`LM_INVENTORY_CACHE`, `LM_INVENTORY_CACHE_TTL`, `LM_INVENTORY_CACHE_DIR`).
- CI fast-lane workflow and expanded bash compatibility matrix (Ubuntu 18.04, CentOS 7 allow-fail).
- New GitHub issue templates and PR template for cleaner contributions.

## Fixes
- Expanded log redaction patterns (AWS keys, private key headers) with tests.
- Trend cache now respects filters and avoids stale reuse.

## Docs
- Added Prometheus textfile example and sample systemd timer for scraping.
- Added support policy and least-privilege sudo/SSH guidance.
- Added development quickstart, artifact checksum verification, and install-mode notes.
- Updated reference/config docs for trend filters and inventory cache.

## Compatibility / upgrade notes
- No action required. Optional caches are off by default.

## Checksums (if releasing a tarball)
- SHA256SUMS:
