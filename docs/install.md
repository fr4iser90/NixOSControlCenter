# Install

## Requirements

- Nix (flake-capable) on the install host
- Root for writing the live NixOS config (wizard escalates via `nix-shell`)
- Hardware covered by NCC prebuild checks (CPU / GPU / memory / platform)

## Bootstrap from this repo

```bash
git clone https://github.com/fr4iser90/NixOSControlCenter
cd NixOSControlCenter
nix-shell                 # starts install as root
```

| Command | Meaning |
|---------|---------|
| `nix-shell` | Full install wizard |
| `NCC_DRY_RUN=1 nix-shell` | Dry-run (no write) |
| `NCC_INSTALL_SHELL_ONLY=1 nix-shell` | Shell only, no auto-start |
| `install` / `install-gui` / `install-fzf` | Explicit UI mode |
| `install-dry` | Dry-run alias |

Wizard: `nixos/core/management/install-wizard/`.

## Update an existing NCC host

```bash
ncc system-update --local /path/to/NixOSControlCenter/nixos
# or
ncc system-update --remote <git-url>
```

Dev gates **before** you deploy from a checkout:

```bash
bash tests/run-gates.sh
```

## Related

- Product overview: [root README](../README.md)
- Limits: [`limitations.md`](./limitations.md)
- Features checklist: [`features.md`](./features.md)
