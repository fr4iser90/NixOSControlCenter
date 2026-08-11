# Setup vs Packages — naming (do not mix)

| Domain | Term | Path | Meaning |
|---|---|---|---|
| **Setup** | **install base** | `modes/install-bases/` | Starter for systemType (Desktop / Server / From Scratch) |
| **Setup** | **install starter** | UI list (`INSTALL_STARTERS`) | Optional overlay (e.g. Homelab on Server) |
| **Setup** | **host blueprint** | `modes/host-blueprints/` | Named machine template (`fr4iser-home`, `fr4iser-strix-halo`, …) |
| **Setup** | **device target** | `host-blueprints/*` + `deviceTarget.enable` | Discovered hardware starter (label → same file). Add match rules in the blueprint; no list wiring. |
| **Packages** | **set** | `packages/.../sets/` | One optional system module |
| **Packages** | **recipe** | `packages/.../recipes/` | Shortcut → several sets |
| **Packages** | **user-preset** | `packages/.../user-presets/` | Shortcut → your `userPackages` |
| **Packages** | **base (core/profile)** | `packages/.../base/` | Always-on core + desktop\|server extras |

Forbidden collisions: do **not** call setup things “preset/profile/recipe/set”.
Loader script: `config/apply-install-template.sh` (`apply_install_template`).
Wire token: `LOAD_BLUEPRINT:` (legacy `LOAD_PROFILE:` still accepted).

## Device targets (discovery)

Hardware starters are **not** listed in `setup-options`. Put this in a host-blueprint file:

```nix
deviceTarget = {
  enable = true;
  label = "My Board";
  description = "Shown in the wizard";
  match = {
    arch = [ "x86_64" ];           # optional AND filter
    lspci = [ "Some Chip" ];       # OR probes
    filesAny = [ "/sys/…" ];
    textAny = [ "marker" ];
  };
};
```

Discovery: `ui/gui/device_discover.py` (+ bash `load_discovered_device_targets`).  
`fr4iser-home` without `deviceTarget` stays Advanced-only.
