# Package sets, recipes & user-presets

Three folders under packages — nothing mixed with **Setup**:

```
packages/components/
  sets/           # one NixOS module each (optional, system-wide)
  recipes/        # system shortcuts → list of sets
  user-presets/   # personal shortcuts → list of package attrs
```

Setup uses different words (see `shell/doc/setup-naming.md`):
**install base**, **host blueprint** — never “preset/profile/recipe” there.

## Layers

| Layer | Path / mechanism | Scope | Optional? |
|---|---|---|---|
| **core** | `base/core.nix` | every machine | no |
| **profile** | `base/desktop.nix` or `server.nix` | by `systemType` | no |
| **set** | `sets/<name>.nix` → `packageModules` | SYSTEM | yes (admin) |
| **recipe** | `recipes/<name>.nix` → expands to sets | SYSTEM | yes (admin) |
| **user-preset** | `user-presets/<name>.nix` → `userPackages` | USER | yes (self) |

## Naming

| Kind | Folder | Name example | File fields |
|---|---|---|---|
| Set | `sets/` | `gaming.nix` | NixOS module |
| Recipe | `recipes/` | `gaming-desktop.nix` | `modules = [ "gaming" "streaming" … ]` |
| User-preset | `user-presets/` | `user-web-tools.nix` | `packages = [ "vscode" … ]` |

Do **not** put `packages =` in recipes or `modules =` in user-presets.

## Recipes (system)

| Name | Expands to |
|---|---|
| gaming-desktop | gaming, streaming, emulation |
| dev-lean | web-dev, system-dev |
| virt-desktop | qemu-vm, virt-manager |
| homelab-server | docker, database, web-server |
| dev-workstation | legacy full stack |

## User-presets

| Name | → userPackages |
|---|---|
| user-web-tools | vscode, node, … |
| user-python-tools | python312, ruff, … |
| user-creative | blender, gimp, … |

## Word “preset”

Avoid for system stuff. Say **recipe** (system) or **user-preset** (account). Old CLI still says `module add <name>` for both.
