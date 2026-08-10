# Setup vs Packages — naming (do not mix)

| Domain | Term | Path | Meaning |
|---|---|---|---|
| **Setup** | **install base** | `modes/install-bases/` | Starter for systemType (Desktop / Server / From Scratch) |
| **Setup** | **install starter** | UI list (`INSTALL_STARTERS`) | Optional overlay (e.g. Homelab on Server) |
| **Setup** | **host blueprint** | `modes/host-blueprints/` | Named machine template (`fr4iser-home`, `fr4iser-strix-halo`, …) |
| **Setup** | **device target** | UI list → blueprint map | Hardware starter (Jetson Nano, Strix Halo → blueprint file) |
| **Packages** | **set** | `packages/.../sets/` | One optional system module |
| **Packages** | **recipe** | `packages/.../recipes/` | Shortcut → several sets |
| **Packages** | **user-preset** | `packages/.../user-presets/` | Shortcut → your `userPackages` |
| **Packages** | **base (core/profile)** | `packages/.../base/` | Always-on core + desktop\|server extras |

Forbidden collisions: do **not** call setup things “preset/profile/recipe/set”.
Loader script: `config/apply-install-template.sh` (`apply_install_template`).
Wire token: `LOAD_BLUEPRINT:` (legacy `LOAD_PROFILE:` still accepted).
