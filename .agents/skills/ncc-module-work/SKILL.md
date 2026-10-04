---
name: ncc-module-work
description: >-
  Edit or add NCC NixOS modules using discovery helpers only (getModuleConfig /
  getModuleApi), correct docs layout, and migrations when hosts need cleanup.
  Use when changing nixos/core or nixos/modules, options, commands, config.nix,
  migrations, or template-config.
---

# NCC module work

## Identity & config (law)

```nix
moduleName = baseNameOf ./.;
cfg = getModuleConfig moduleName;
other = getModuleConfig "network";
api = getModuleApi "cli-registry";
```

- Options/config: `options.${metadata.configPath}` / `config.${metadata.configPath}`
- **Never** hardcode `config.core.…` or `systemConfig.core.…`
- **Never** read `cfg = systemConfig.${configPath};` (dotted key = one attr → hard error)
- Cross-module: `getModuleApi` / `getModuleConfig` only — no relative imports of peer trees under `nixos/modules/`

Laws: [AGENTS.md](../../../AGENTS.md) (discovery section)

## Docs

One home: `<module>/doc/**/*.md`. README/CHANGELOG stubs at module root only.  
No `ai/docs/`, no root `cli.md`. Gate: `tests/gates/validate-docs-layout.sh`.

## Migrations (only when hosts break without cleanup)

Bump `_module.metadata.version` / `_version` **and** add:

- Code cleanup: `<module>/migrations/vFROM-to-vTO.nix` with `removeRelativePaths`
- Cross-module rename/merge: destination `migrations/plan-*.nix`

Do **not** bump for docs-only / additive defaults / internal refactors.  
Central `plans.nix` stays `plans = []`.  
Laws: [AGENTS.md](../../../AGENTS.md) (migrations) · details in skill below / `docs/developing/new-module.md`

## New module checklist

Follow [docs/developing/new-module.md](../../../docs/developing/new-module.md).  
Copy a small real module (e.g. `lock-manager`), don’t invent a parallel template tree.

## Finish

```bash
bash tests/run-gates.sh   # exit 0 required
```
