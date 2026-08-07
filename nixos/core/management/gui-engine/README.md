# NCC GUI Engine (Qt / PySide6)

Shared chrome for domain GUIs (`ncc_gui`). Mirror of `tui-engine` for desktop.

## Access (module guidelines)

```nix
gui = getModuleApi "gui-engine";

# Shared Python tree
pkg = gui.package pkgs;          # { src, pythonEnv, pythonPath }

# Launchers
domainGui = gui.domainGui pkgs;  # ncc-domain-gui
rootGui = gui.rootGui pkgs;      # ncc-gui (root shell)
```

**Do not** `import …/gui-engine/package.nix` via relative paths from other modules.

## Status

Packages, Network, Lock, AI have richer pages under `ncc_gui.pages.<id>`;
other domains use the generic page until a custom page exists.
