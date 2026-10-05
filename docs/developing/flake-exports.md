# Import NCC modules into another flake

NCC is **one flake** (`nixos/`). It exports each feature as `nixosModules.<name>`
plus `ncc-runtime` — same idea as home-manager: one input, import only what you need.

## Flake input

```nix
{
  inputs.ncc.url = "github:fr4iser90/NixOSControlCenter?dir=nixos";
  # Optional: pin NCC’s nixpkgs to yours
  # inputs.ncc.inputs.nixpkgs-stable.follows = "nixpkgs";
}
```

Use `?dir=nixos`. Do not use a GitHub `/tree/main/…` URL, and do not point at a
single module folder (modules are not separate flakes).

## Example host

```nix
outputs = { self, nixpkgs, ncc, ... }:
let
  system = "x86_64-linux";
  pkgs = nixpkgs.legacyPackages.${system};

  # Your own NCC config leaves (not someone else’s host tree)
  systemConfig = {
    modules.specialized.ncc-assistant = {
      enable = true;
      endpoint = "http://localhost:11434/v1";
    };
  };
in {
  nixosConfigurations.example = nixpkgs.lib.nixosSystem {
    inherit system;
    specialArgs = ncc.lib.mkNccSpecialArgs {
      inherit (pkgs) lib;
      inherit systemConfig;
    };
    modules = [
      ncc.nixosModules.ncc-runtime          # required
      ncc.nixosModules.ncc-assistant        # pick features by name
      # ncc.nixosModules.lock-manager
      {
        system.stateVersion = "26.05";
        # … normal NixOS config (filesystems, users, …)
      }
    ];
  };
};
```

## What each line does

| You write | Effect |
|-----------|--------|
| `inputs.ncc.url = …` | Downloads/locks the flake (does **not** enable modules) |
| `ncc.nixosModules.ncc-runtime` | Management stack (discovery, CLI/GUI helpers, …) |
| `ncc.nixosModules.<feature>` | That feature’s module only |
| `systemConfig.modules…enable = true` | Turns the feature on |

List exports:

```bash
nix flake show github:fr4iser90/NixOSControlCenter?dir=nixos
# or from a clone: nix flake show ./nixos
```

## Requirements

- Set `specialArgs` with **`mkNccSpecialArgs`** (modules need `systemConfig` / `getModuleConfig` / `getModuleApi`).
- Import **`ncc-runtime`** before feature modules.
- Configure with **`systemConfig`** leaves (NCC schema), not vanilla `services.*`.
- Repo must be reachable (public GitHub, or auth for private clones).

See also: [ncc-assistant usage](../nixos/modules/specialized/ncc-assistant/doc/usage.md).
