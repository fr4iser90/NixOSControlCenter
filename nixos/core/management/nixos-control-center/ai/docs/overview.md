# nixos-control-center

Main NCC control-center entry / aggregation.

## Config

- Read/write via `getModuleConfig "nixos-control-center"` (never hardcoded `config.core.…` paths).
- Template defaults: `template-config.nix` in this module.

## CLI

- Prefer registered `ncc` commands for this module when they exist (`ncc --help` / domain help).
- Tools live in `ai/tools/*.json` only when a safe argv wrapper exists — none required for docs-only packs.

## Ownership

This pack is owned by the module. Delete `nixos-control-center/` ⇒ pack gone from assistant discovery.
