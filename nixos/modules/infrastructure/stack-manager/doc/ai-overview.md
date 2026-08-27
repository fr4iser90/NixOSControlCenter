# stack-manager

Catalog Docker stacks (create/fetch/update); Swarm via stack-manager.swarm.

## Config

- Read/write via `getModuleConfig "stack-manager"` (never hardcoded `config.core.…` paths).
- Template defaults: `template-config.nix` in this module.

## CLI

- Prefer registered `ncc` commands for this module when they exist (`ncc --help` / domain help).
- Tools live in `ai/tools/*.json` only when a safe argv wrapper exists — none required for docs-only packs.

## Ownership

This pack is owned by the module. Delete `stack-manager/` ⇒ pack gone from assistant discovery.
