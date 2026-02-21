# UI-Architektur (Multi-Interface Support)

Module können mehrere UI-Formen unterstützen:

## Struktur

```
ui/
├── cli/          # CLI-Interfaces (fzf, gum, etc.)
├── tui/          # TUI Engine Integration (Bubble Tea)
├── gui/          # Desktop GUIs (Plasma, GNOME, etc.)
└── web/          # Web-Interface (optional, wie nixify)
```

## UI-Typen

### 1. CLI (`ui/cli/`)
- **fzf**: fzf-basierte Menus (aus Scripts extrahiert!)
- **interactive**: Andere CLI-Interfaces (gum, etc.)

**Wichtig**: Scripts enthalten nur reine Commands, UI-Logik in `ui/cli/`

### 2. TUI (`ui/tui/`)
- Nutzt `tui-engine` API für Bubble Tea Interfaces
- Module definieren nur Content (`menu.nix`, `actions.nix`)
- Engine stellt Templates bereit

### 3. GUI (`ui/gui/`)
- **plasma**: KDE Plasma GUI (QML)
- **gnome**: GNOME GUI (GTK4/Python)
- **generic**: Generic GUI (Qt/GTK)
- **shared**: Shared GUI Components

**Optional**: Nur wenn Modul GUI benötigt

### 4. Web (`ui/web/`)
- **api**: REST API Backend (Go, wie nixify)
- **frontend**: Frontend (React/Vue/etc.)
- **docker**: Docker für Web-Service

**Optional**: Nur wenn Modul Web-Service benötigt

## Best Practices

1. **fzf aus Scripts extrahieren**: Scripts bleiben clean
2. **TUI via Engine**: Nutze `tui-engine` API
3. **GUI optional**: Nur wenn nötig
4. **Web optional**: Nur wenn nötig (wie nixify)
5. **Docker einsortieren**: `docker/` oder `ui/web/docker/` statt Root
