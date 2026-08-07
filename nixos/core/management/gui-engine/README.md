# NCC GUI Engine (Qt / PySide6)

Shared chrome for domain GUIs (`ncc_gui`): shell, theme, catalog, remote/target,
generic page. **Domain pages are not here** — each module owns `ui/gui/page.py`.

## Access (module guidelines)

```nix
gui = getModuleApi "gui-engine";
cli = getModuleApi "cli-registry";

# Launchers (always pass config so registered pages are aggregated)
domainGui = gui.domainGui pkgs config;  # ncc-domain-gui
rootGui = gui.rootGui pkgs config;      # ncc-gui (root shell)

# Register this module’s rich page (directory must contain page.py)
cli.registerGuiPage "homelab" ./ui/gui

# Sidebar section (root shell: Core / Features)
cli.registerGuiDomain "homelab" {
  label = "Homelab";
  description = "…";
  enabled = cfg.enable or false;
  group = "features";  # or "core" for base/management
};
```

**Do not** put domain pages under `gui-engine/python/ncc_gui/pages/`.
**Do not** `import …/gui-engine/…` via relative paths from other modules.

## Layout

| Location | Responsibility |
|----------|----------------|
| `gui-engine` | Shell, Target bar, theme, dialogs, `remote`, generic fallback |
| `<module>/ui/gui/page.py` | Domain-specific Qt page (`create_page` / `Page`) |
| `cli-registry.registerGuiPage` | Discovery hook so the engine can aggregate pages |
| `registerGuiDomain.group` | Sidebar section: `core` \| `features` |
| `assets/ncc-icon.{svg,png}` | App icon (window, sidebar, desktop entry `ncc`) |
