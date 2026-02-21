# TUI Engine Integration

## Purpose
Bubble Tea-basierte TUI via tui-engine

## Struktur
- `menu.nix`: TUI Menu-Definition (verwendet tui-engine)
- `actions.nix`: TUI Action-Handler (ruft CLI commands auf)
- `helpers.nix`: TUI-spezifische Utilities

## Verwendung

```nix
# In menu.nix
let
  tuiEngine = getModuleApi "tui-engine";
  tui = tuiEngine.templates."5panel".createTUI
    "Title"
    [ "Menu Items" ]
    actions.getList
    actions.getSearch
    actions.getDetails
    actions.getActions;
in
  tui
```

## Beispiel
```bash
# TUI wird über tui-engine gestartet
ncc example-module tui  # → Bubble Tea TUI wird angezeigt
```
