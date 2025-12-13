# KOMPLETTER IMPLEMENTATIONSPLAN: Zentrales Module-Management

## 🎯 ZIEL: Zentrale Kontrolle über ALLE Module (Template wird angepasst)

## 📋 ALLE BETROFFENEN DATEIEN:

### 1. `core/management/module-manager/lib/discovery.nix` - ERSTELLEN
**AUFGABE:** Discovery-Funktion implementieren
**INHALT:**
```nix
# Module Discovery Logic
discoverAllModules = basePath: let
  # Rekursiv alle Module in core/ und features/ finden
  # Rückgabe: Liste von { name, category, path }
in discoverAllModules;
```

### 1b. `core/management/module-manager/lib/default.nix` - ERWEITERN
**AUFGABE:** Discovery-Funktion exportieren
**INHALT:**
```nix
{
  # Bestehende Exports...
  inherit (import ./discovery.nix) discoverAllModules;
}
```

### 2. `core/management/module-manager/config.nix` - ERWEITERN
**AUFGABE:** Zentrale Import- und Enable-Logik
**INHALT:**
```nix
# 1. discoverAllModules aufrufen
# 2. module-manager-config.nix lesen
# 3. Aktivierte Module filtern
# 4. Module importieren
# 5. enable-Optionen für alle Module setzen
```

### 3. `core/management/module-manager/module-manager-config.nix` - ERSTELLEN
**AUFGABE:** Zentrale Konfiguration für ALLE Module
**INHALT:**
```nix
{
  core = {
    system.audio.enable = true;
    management.logging.enable = true;
    infrastructure.cli-formatter.enable = true;
  };
  features = {
    security."ssh-client-manager".enable = true;
    infrastructure.homelab-manager.enable = false;
    infrastructure.vm-manager.enable = false;
  };
}
```

### 4. `core/management/module-manager/commands.nix` - ERWEITERN
**AUFGABE:** GUI für Module-Management
**INHALT:**
```bash
ncc module-manager:
- Zeigt alle discovered Module mit Status
- Erlaubt toggeln von enable/disable
- Aktualisiert module-manager-config.nix
- Fzf-basierte interaktive Auswahl
```

### 5. `features/default.nix` - LEER LASSEN
**AUFGABE:** Nichts tun - Module-Manager macht alles
**INHALT:**
```nix
# LEER - Module-Manager macht ALLE Imports zentral
{ ... }: {}
```

### 6. ALLE MODULE ANPASSEN (für zentrale Kontrolle):

#### `features/security/ssh-client-manager/options.nix`:
- `enable` Option hinzufügen (wird von module-manager gesetzt)
- `_version` hinzufügen

#### `features/security/ssh-client-manager/commands.nix`:
- `mkIf cfg.enable` hinzufügen

#### `features/security/ssh-client-manager/config.nix`:
- `mkIf cfg.enable` hinzufügen

#### ALLE anderen Module auch anpassen!

## 🔄 ARBEITSABLAUF:

1. **flake.nix** importiert `./core` (module-manager wird geladen)
2. **module-manager/config.nix** läuft:
   - Discovered alle Module aus `core/` und `features/`
   - Liest `module-manager-config.nix`
   - Importiert nur aktivierte Module
   - Setzt `enable = true` für aktivierte Module
3. **Aktivierte Module** laufen mit voller Funktionalität
4. **`ncc module-manager`** erlaubt GUI-basierte Verwaltung

## ✅ ARCHITEKTUR:

- ✅ **Zentrale Kontrolle** über module-manager
- ✅ **Auto-Discovery** aller Module
- ✅ **GUI-Verwaltung** mit `ncc module-manager`
- ✅ **Zero-maintenance:** Neue Module automatisch gefunden
- ✅ **Template angepasst:** Für unser Use-Case optimiert

## 🎮 NCC MODULE-MANAGER GUI:

```
=== Module Manager ===
Discovered Modules (auto-discovery):

Core Modules:
✓ system.audio                    (enabled)
✓ management.logging              (enabled)
✓ infrastructure.cli-formatter    (enabled)

Feature Modules:
✓ security.ssh-client-manager     (enabled)
○ infrastructure.homelab-manager  (disabled)
○ infrastructure.vm-manager       (disabled)

Actions: (t)oggle [number] (q)uit
>
```

## 📋 IMPLEMENTATIONSSCHRITTE:

1. **Discovery-Funktion** in `lib/default.nix` implementieren
2. **config.nix** erweitern um Import- und Enable-Logik
3. **module-manager-config.nix** erstellen mit allen Modulen
4. **commands.nix** für GUI implementieren
5. **Alle Module** für zentrale Kontrolle anpassen
6. **Testen** mit ssh-client-manager

## ⚠️ WICHTIG:

- **Template wird angepasst** für zentrale Kontrolle
- **features/default.nix** bleibt LEER
- **Module-Manager** macht ALLES zentral
- **Neue Module** werden automatisch discovered
