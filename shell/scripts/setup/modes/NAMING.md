# Setup vs Packages — naming (do not mix)

| Domain | Term | Path | Meaning |
|---|---|---|---|
| **Setup** | **install base** | `modes/install-bases/` | Starter for systemType (Desktop / Server) |
| **Setup** | **host blueprint** | `modes/host-blueprints/` | Named machine template (`fr4iser-home`, …) |
| **Setup** | **device target** | UI list only | Hardware starter (Jetson Nano → blueprint) |
| **Packages** | **set** | `packages/.../sets/` | One optional system module |
| **Packages** | **recipe** | `packages/.../recipes/` | Shortcut → several sets |
| **Packages** | **user-preset** | `packages/.../user-presets/` | Shortcut → your `userPackages` |
| **Packages** | **base (core/profile)** | `packages/.../base/` | Always-on core + desktop\|server extras |

Forbidden collisions: do **not** call setup things “preset/profile/recipe/set”.
Loader script: `config/apply-install-template.sh` (`apply_install_template`).
Wire token: `LOAD_BLUEPRINT:` (legacy `LOAD_PROFILE:` still accepted).
