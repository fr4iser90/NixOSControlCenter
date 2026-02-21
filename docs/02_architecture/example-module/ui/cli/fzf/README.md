# fzf-basierte CLI-Menus

## Purpose
fzf-Menus aus Scripts extrahiert - Scripts bleiben clean!

## Struktur
- `menu.nix`: fzf Menu-Definition
- `actions.nix`: Action-Handler
- `helpers.nix`: fzf-spezifische Utilities

## Verwendung

```nix
# In commands.nix
let
  fzfMenu = import ./ui/cli/fzf/menu.nix { inherit lib pkgs cfg; };
in
  # Register command
```

## Beispiel
```bash
# Script ruft fzf Menu auf
ncc example-module  # → fzf Menu wird angezeigt
```
