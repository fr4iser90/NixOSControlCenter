# AI Knowledge: NixOSControlCenter (principles only — no module inventory)

## Purpose
NixOSControlCenter (NCC) — NixOS system management with CLI, modular config, dual-layout
systemConfig, and optional modules. **Module inventory is never hand-maintained here.**

## Law: Discovery only

- **Inventory SSOT:** live `ncc modules list --json` (runtime discovery)
- **Tool:** `list_modules` → same call; fails if `ncc` is unavailable (no packaged JSON)
- **Per-module AI:** `<module>/ai/{manifest,tools,docs,skills,domains,context}` — delete the module → pack gone
- **Forbidden:** listing module names/paths in this file, install modes named after modules, or central skill dumps

If a module is missing from chat knowledge, it is missing from the tree or lacks an `ai/` pack — do not invent it.

---

## Repo layout (stable buckets — not a module list)

```
NixOSControlCenter/
├── nixos/
│   ├── core/          # domain "core" — discovered modules under base/ + management/
│   ├── modules/       # domain "modules" — optional / application modules
│   ├── custom/        # user modules — never overwritten on update
│   └── (runtime on host) systemConfig via /etc/nixos — not in git
├── docs/              # legacy / templates (e.g. MODULE_TEMPLATE) — not live inventory
└── shell/             # devShell entry
```

Exact module folders = discovery. Category path = `nixos/<category with dots→slashes>`.

---

## Config System: v0 → v1 → v2 (dual layout)

| Version | Config Location | Entry Point | Status |
|---------|----------------|-------------|--------|
| v0 (legacy) | `/etc/nixos/system-config.nix` (flat) | flake imports system-config.nix | DEPRECATED |
| v1 | `/etc/nixos/systemConfig/**/config.nix` | config-loader discover/merge | supported (layout=split) |
| v2 (current) | **monolith** `/etc/nixos/systemConfig.nix` **or** split leaves | config-loader layout detect | **ACTIVE** |

### Layouts (v2)
- **monolith (default for new installs):** one nested file `/etc/nixos/systemConfig.nix`
- **split:** leaf files under `/etc/nixos/systemConfig/**/config.nix`
- Convert: `ncc config-layout detect|convert --to monolith|split`
- Writers go through `config-facade` (`ncc_write_module_config`)

### Key Rules
- **configVersion** + **layout** live under the system-manager module config (short name via discovery)
- **No live dual layout** — convert removes the other form after backup
- **template-config.nix** = defaults; merged via `getModuleConfig`
- Cross-module: `getModuleConfig` / `getModuleApi` by **short name** — never hardcoded `config.core.…` paths

### Migration Flow
1. v0 → v1: flat → split leaves
2. v1 → v2: inject `configVersion` / `layout`
3. Layout convert: `ncc-config-layout convert --to monolith|split`

---

## Update Flow (`ncc system-update`)

High level: validate → migrate if needed → sync flake tree → prebuild checks → `nixos-rebuild`.
Details live in the **system-manager** module (handlers + components) — open that tree; do not duplicate file lists here.

---

## Module Loading Chain

```
flake.nix
  └─► discovery (core + modules)
        └─► getModuleConfig / getModuleApi (short names)
              └─► template-config.nix ⊔ systemConfig
```

---

## Critical Patterns & Conventions

### Nix `''` String Escaping (CRITICAL for LLM)
Inside Nix indented strings (`''...''`):
- `${...}` = Nix interpolation
- `''${...}` = literal `${...}` in output (for bash)
- `'''` = literal `'`

**Mistake:** `${SOME_BASH_VAR}` inside Nix `''` → Nix interpolates.  
**Fix:** `''${SOME_BASH_VAR}`.

### Module shape (template)
```
module-name/
├── default.nix + options.nix + template-config.nix   # required for discovery
├── config.nix / commands.nix / api.nix               # optional
└── ai/                                               # optional assistant pack
```

Use `baseNameOf ./.` for `moduleName` — never hardcode.

### Passwords / backups / prebuild
Owned by the modules that implement them (user checks, system-manager). Prefer reading those modules over copying procedures into this file.

---

## Platform notes

- NixOS + bash scripts via `pkgs.writeShellScriptBin` / `writeText`
- jq 1.6+, openssl, pciutils as used by checks
- Host paths: `/etc/nixos/systemConfig.nix` or `systemConfig/**`

---

## Common Issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| `unexpected '='` in bash-in-Nix | Unescaped `${VAR%…}` | `''${VAR%…}` |
| Module missing from `list_modules` | No `default.nix`+`options.nix` or not under nixos/core\|modules | Fix discovery gate |
| Stale skill about a module | Skill was central dump | Move to that module's `ai/skills/` |
