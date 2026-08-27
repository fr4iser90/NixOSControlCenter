# GUI

Domain GUIs are **PySide6** pages hosted by **gui-engine**.

## How a domain gets a GUI

1. `ui/gui/page.py` implementing a `DomainPage` (see `gui-engine/doc/page-template.md`)
2. Register in `commands.nix`:

```nix
(cliRegistry.registerGuiDomain "network" { … group = "core"; … })
(cliRegistry.registerGuiPage "network" ./ui/gui)
```

## What exists today

See [`ui-matrix.md`](./ui-matrix.md) (GUI column). Core examples: hardware, packages, desktop, network, user, system-manager, module-manager, install-wizard. Features: stacks, vm, lock-manager, ncc-assistant, …

## Docs in-tree

| File | Topic |
|------|--------|
| `nixos/core/management/gui-engine/doc/page-template.md` | Copy-paste page |
| `gui-engine/doc/gui-design.md` | UX rules |
| `gui-engine/doc/performance.md` | Hot path / reload |

## Catalog behavior

- Core domains remain in the sidebar when disabled (Off badge)
- Features may be hidden when inactive (chrome pref)
- Tests for catalog invariants: `tests/validate-gui-catalog.sh` (via `run-gates.sh`)
