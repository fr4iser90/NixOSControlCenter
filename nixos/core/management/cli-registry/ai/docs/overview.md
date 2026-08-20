# cli-registry

Registers ncc command sets from modules' commands.nix.

## Config

- Read/write via `getModuleConfig "cli-registry"` (never hardcoded `config.core.…` paths).
- Template defaults: `template-config.nix` in this module.

## CLI

- Prefer registered `ncc` commands for this module when they exist (`ncc --help` / domain help).
- Tools live in `ai/tools/*.json` only when a safe argv wrapper exists — none required for docs-only packs.

## Ownership

This pack is owned by the module. Delete `cli-registry/` ⇒ pack gone from assistant discovery.
