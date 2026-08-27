# NixOS Control Center (NCC)

**Declarative NixOS you can actually run** — install and manage hosts with CLI, TUI, and GUI.

Hardware detection, prebuild checks, package presets, and optional modules (SSH, VMs, stacks, …) — from a simple desktop to a tuned setup, still fully editable as NixOS config.

## Screenshots

| Surface | |
|---------|--|
| Install wizard | *TODO* |
| GUI | *TODO* |
| CLI / TUI | *TODO* |

## Features

- **Hardware-aware** — CPU / GPU / RAM / platform detection and prebuild checks
- **Packages & presets** — catalog-driven installs (change config → rebuild)
- **Install wizard** — `nix-shell` → `install` / `install-gui` / `install-fzf`
- **Updates** — `ncc system-update` (local path or git remote), backups, migrations
- **Surfaces** — `ncc` CLI, domain GUIs, TUI where available
- **Modules** — optional features under `nixos/modules/`

Full checklist: [`docs/features.md`](docs/features.md).

## Quick start

```bash
# Bootstrap from this repo (needs Nix)
nix-shell          # install | install-gui | install-fzf | install-dry

# Host already running NCC
ncc system-update --local /path/to/this/repo/nixos
# or
ncc system-update --remote <git-url>
```

See [`docs/install.md`](docs/install.md).

## Documentation

| Doc | |
|-----|--|
| [docs/README.md](docs/README.md) | Index + layout rules |
| [docs/features.md](docs/features.md) | Feature status |
| [docs/domains.md](docs/domains.md) | Domains ↔ modules |
| [docs/gui/ui-matrix.md](docs/gui/ui-matrix.md) | CLI / TUI / GUI |
| [docs/limitations.md](docs/limitations.md) | Known limits |
| [docs/developing/new-module.md](docs/developing/new-module.md) | Add a module |

## License

MIT — see [`LICENSE`](LICENSE).
