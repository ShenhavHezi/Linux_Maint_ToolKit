# Custom Monitors

Use this page when you want to add a new monitor without breaking the toolkit’s summary contract.

For contributor rules and test expectations, also use [../CONTRIBUTING.md](../CONTRIBUTING.md).

## When to create a custom monitor

Create a new monitor when:

- you need a check that does not fit an existing monitor
- the output should participate in the normal wrapper summary flow
- the result should appear in `status`, `report`, `diff`, exports, and support bundles

Do not create a separate monitor when a small extension to an existing monitor is enough.

## Recommended workflow

### 1. Generate a scaffold

```bash
tools/new_monitor.sh my_custom_monitor
```

### 2. Implement the check

Edit the script under `monitors/` and keep the logic narrow:

- collect what you need
- emit summary lines
- send detail to stderr or logs, not stdout

### 3. Test it directly

```bash
bash monitors/my_custom_monitor.sh
```

### 4. Test it through the wrapper

```bash
linux-maint run --only my_custom_monitor
```

## Summary contract

Every monitor must emit at least one summary line through `lm_summary`:

```bash
lm_summary "my_custom_monitor" "$host" "OK"
```

Required fields:

- `monitor`
- `host`
- `status`
- `node`

Important rules:

- non-OK paths should include `reason=...`
- one target host should produce one logical summary result per run
- stdout should remain summary-safe
- avoid whitespace in emitted values

## Config portability

When your monitor uses config files, resolve them through `LM_CFG_DIR`:

```bash
CONFIG_FILE="${LM_CFG_DIR:-/etc/linux_maint}/my_targets.txt"
```

That keeps the monitor working in:

- repo mode
- installed mode
- CI and temp test roots

## Common helper patterns

Per-host loop:

```bash
for host in $(lm_hosts); do
  lm_summary "my_custom_monitor" "$host" "OK"
done
```

Dependency guard:

```bash
lm_require_cmd "my_custom_monitor" "localhost" awk || exit $?
```

## What makes a good monitor

A good monitor:

- has one clear purpose
- degrades clearly when config or dependencies are missing
- uses stable `reason=` tokens
- works in repo mode and installed mode
- does not depend on interactive output

## Testing checklist

- add tests under `tests/` when behavior or contracts change
- run `linux-maint lint-summary <summary_log>` on generated output when helpful
- prefer contract tests over brittle text-only assertions

## Related docs

- [reference.md](reference.md) for the full summary contract
- [REASONS.md](REASONS.md) for stable reason token vocabulary
- [../CONTRIBUTING.md](../CONTRIBUTING.md) for contributor workflow
