# install-wizard

Install/migrate wizard: presets, blueprints, writers → systemConfig.

## Config

- Read/write via `getModuleConfig "install-wizard"` (never hardcoded `config.core.…` paths).
- Template defaults: `template-config.nix` in this module.

## CLI

- Prefer registered `ncc` commands for this module when they exist (`ncc --help` / domain help).
- Tools live in `ai/tools/*.json` only when a safe argv wrapper exists — none required for docs-only packs.

## Ownership

This pack is owned by the module. Delete `install-wizard/` ⇒ pack gone from assistant discovery.
