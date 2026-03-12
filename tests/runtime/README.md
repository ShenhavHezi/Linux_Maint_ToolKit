## Runtime Tests

This directory holds runtime and monitor-facing regressions, including:

- shared library helper checks (`lm_*`, host parsing, temp-file behavior)
- monitor dependency and failure-mode tests
- summary contract helper tests
- SSH/runtime option enforcement
- inventory/runtime support checks

Use this area for tests that validate the shell runtime environment and monitor helper behavior
rather than a specific top-level `linux-maint` command surface.
