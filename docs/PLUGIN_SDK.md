# Plugin SDK (Baseline)

This baseline plugin model is local-directory based.

## Manifest
A plugin directory should include `plugin.json`:

```json
{
  "name": "my_plugin",
  "version": "0.1.0",
  "description": "what this plugin provides"
}
```

## Commands
- `linux-maint plugin list [--json]`
- `linux-maint plugin search [--index FILE] [--json]`
- `linux-maint plugin install <source_dir> [--name NAME] [--force]`
- `linux-maint plugin verify <name> [--json]`
- `linux-maint plugin remove <name>`

## Notes
- In repo mode, plugin root defaults to `./plugins`.
- In installed mode, plugin root defaults to `/var/lib/linux_maint/plugins`.
- Override plugin root with `LM_PLUGIN_DIR`.
