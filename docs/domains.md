# Domains

NCC CLI is **domain-driven**: `ncc <domain> <action> …`  
Registration: `cli-registry` + each module’s `commands.nix`.

## Core domains (base + management)

| Domain (typical) | Module path | Role |
|------------------|---------------|------|
| `hardware` | `core/base/hardware` | Detect / set CPU GPU RAM platform |
| `packages` | `core/base/packages` | Sets, presets, package lists |
| `desktop` | `core/base/desktop` | Desktop environment |
| `network` | `core/base/network` | NM, WiFi, firewall |
| `user` / users | `core/base/user` | Accounts, roles |
| `boot` | `core/base/boot` | Bootloader |
| `audio` | `core/base/audio` | Audio stack |
| `localization` | `core/base/localization` | Locale / i18n |
| `system` | `core/management/system-manager` | update, checks, backup |
| `modules` | `core/management/module-manager` | enable/discover modules |
| `install` | `core/management/install-wizard` | guided install (also nix-shell) |

Exact verb names: run `ncc` / `ncc <domain>` or read that module’s `CLI.md`.

## Feature domains (optional modules)

| Domain (typical) | Module path |
|------------------|---------------|
| `stacks` / stack-manager | `modules/infrastructure/stack-manager` |
| `vm` | `modules/infrastructure/vm` |
| `bootentry` | `modules/infrastructure/bootentry-manager` |
| `ssh` | `modules/security/ssh-manager` |
| `lock` | `modules/system/lock-manager` |
| `nixify` | `modules/specialized/nixify` |
| `ai` / assistant | `modules/specialized/ncc-assistant` |
| `chronicle` | `modules/specialized/chronicle` |

## Core vs features (GUI catalog)

- **Core** domains stay listed even when disabled (Off badge); commands stay registered so you can re-enable.
- **Features** can be hidden when inactive (GUI preference “Hide inactive features”).

## Related

- CLI shape: [`cli/pattern.md`](./cli/pattern.md)
- Surfaces: [`gui/ui-matrix.md`](./gui/ui-matrix.md)
- New module: [`developing/new-module.md`](./developing/new-module.md)
