# cli-formatter

Shared CLI formatting (colors, badges, tables) for other modules.

## Config

- Read/write via `getModuleConfig "cli-formatter"` (never hardcoded `config.core.…` paths).
- Template defaults: `template-config.nix` in this module.

## CLI

- Prefer registered `ncc` commands for this module when they exist (`ncc --help` / domain help).
- **Copy rules:** see `doc/COPY.md` — GUI plain language; CLI clear; `-v` for full technical detail.
- Tools live in `ai/tools/*.json` only when a safe argv wrapper exists — none required for docs-only packs.

## Ownership

This pack is owned by the module. Delete `cli-formatter/` ⇒ pack gone from assistant discovery.
