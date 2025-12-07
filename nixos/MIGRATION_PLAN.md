# Migration Plan: Modulare Config-Struktur

## Übersicht

Migration von zentraler Config-Struktur (`/etc/nixos/configs/`) zu modularen Configs (jedes Modul verwaltet seine eigenen Configs in `user-configs/` mit Symlinks nach `/etc/nixos/configs/`).

## Ziele

1. **Modularität**: Jedes Modul ist selbstständig mit eigenen Configs
2. **Wartbarkeit**: Config-Änderungen sind co-located mit Modul-Code
3. **Einfaches Editieren**: Symlinks in `/etc/nixos/configs/` für zentrale Bearbeitung
4. **Versionierung**: Configs werden mit Modulen versioniert
5. **Migration**: Module können ihre eigenen Configs migrieren

## Phase 1: Vorbereitung & Infrastruktur

### 1.1 Template & Dokumentation
- [x] README.md universell machen (module-name statt feature-name)
- [x] `user-configs/` vs `config.nix` klarstellen
- [ ] Beispiel-Modul nach Template erstellen (Referenz-Implementierung)

### 1.2 Symlink-Management System
- [ ] **Neue Funktion**: `create-config-symlink` in `nixos/core/config/`
  - Erstellt Symlink von `/etc/nixos/configs/` → `module/user-configs/`
  - Prüft ob Config existiert, erstellt Default wenn nicht
  - Wird in `system.activationScripts` aufgerufen

### 1.3 Config-Loading in flake.nix
- [ ] **Anpassung**: `loadConfig` Funktion erweitern
  - ⚠️ **WICHTIG**: Lädt DIREKT aus `./core|features/<module>/user-configs/` (echte Datei)
  - Fallback: `./configs/module-name-config.nix` (Legacy, für Migration)
  - **NICHT**: Symlink prüfen (existiert noch nicht beim flake.nix Ausführen!)
  - Auto-Discovery: Findet alle Module mit `user-configs/` (optional, später)

### 1.4 Migration-Helper
- [ ] **Neue Funktion**: `migrate-config-to-module`
  - Migriert bestehende `/etc/nixos/configs/*-config.nix` → Module `user-configs/`
  - Erstellt Symlinks zurück
  - Backup vor Migration

## Phase 2: Core-Module Migration (Priorität: Hoch)

### 2.1 Desktop Module (Einfach, guter Start)
**Warum zuerst**: Bereits teilweise implementiert, klar abgegrenzt

**Struktur nach Migration**:
```
nixos/core/desktop/
├── user-configs/
│   └── desktop-config.nix  # User-editable (echte Datei)
├── default.nix             # Erstellt Symlink, liest systemConfig.desktop
├── options.nix
├── display-managers/
├── display-servers/
├── environments/
├── audio/
└── themes/

/etc/nixos/configs/
└── desktop-config.nix  # Symlink → core/desktop/user-configs/desktop-config.nix
```

## Konkreter Implementierungsplan: Desktop-Modul

### 🎯 Konzept-Zusammenfassung

**Wie funktioniert das System?**

1. **Echte Datei**: `nixos/core/desktop/user-configs/desktop-config.nix`
   - User-editable Config
   - Wird von `flake.nix` geladen
   - Ist die "Source of Truth"

2. **Symlink**: `/etc/nixos/configs/desktop-config.nix` → zeigt auf echte Datei
   - Wird von `activationScripts` erstellt (nach Build)
   - User editiert hier (bequem, zentral)
   - Änderungen landen automatisch in echte Datei

3. **Ablauf**:
   ```
   flake.nix lädt echte Datei → Build → activationScripts erstellt Symlink → User editiert Symlink → nächstes Rebuild lädt echte Datei
   ```

**Wichtig:**
- `flake.nix` lädt **NIEMALS** den Symlink (existiert noch nicht)
- `flake.nix` lädt **IMMER** die echte Datei (`user-configs/`)
- Symlink ist **NUR** für User-Editing, nicht für Nix

### Schritt 1: Vorbereitung
- [ ] Backup bestehender `desktop-config.nix` (falls vorhanden)
- [ ] Prüfe aktuelle Desktop-Config-Struktur
- [ ] Dokumentiere aktuelle Optionen

### Schritt 2: Verzeichnisstruktur erstellen
```bash
mkdir -p nixos/core/desktop/user-configs
```

### Schritt 3: Default-Config erstellen
**Datei**: `nixos/core/desktop/user-configs/desktop-config.nix`

**Inhalt** (basierend auf aktueller Struktur):
```nix
{
  desktop = {
    enable = false;
    environment = "plasma";
    display = {
      manager = "sddm";
      server = "wayland";
      session = "plasma";
    };
    theme = {
      dark = true;
    };
    audio = "pipewire";
  };
}
```

### Schritt 4: Migration bestehender Config
**Wenn `/etc/nixos/configs/desktop-config.nix` existiert:**
- [ ] Kopiere Inhalt nach `core/desktop/user-configs/desktop-config.nix`
- [ ] Validiere Syntax
- [ ] Test: Config wird korrekt geladen

### Schritt 5: Symlink-Management in default.nix
**Datei**: `nixos/core/desktop/default.nix`

**Änderungen**:
```nix
{ config, lib, pkgs, systemConfig, ... }:
let
  cfg = systemConfig.desktop or {};
  userConfigFile = ./user-configs/desktop-config.nix;
  symlinkPath = "/etc/nixos/configs/desktop-config.nix";
in {
  config = lib.mkMerge [
    {
      # Erstelle Symlink auf Activation
      system.activationScripts.desktop-config-symlink = ''
        mkdir -p "$(dirname "${symlinkPath}")"
        
        # Erstelle Default-Config wenn nicht existiert
        if [ ! -f "${toString userConfigFile}" ]; then
          mkdir -p "$(dirname "${toString userConfigFile}")"
          cat > "${toString userConfigFile}" <<'EOF'
{
  desktop = {
    enable = false;
    environment = "plasma";
    display = {
      manager = "sddm";
      server = "wayland";
      session = "plasma";
    };
    theme = {
      dark = true;
    };
    audio = "pipewire";
  };
}
EOF
        fi
        
        # Erstelle/Update Symlink
        if [ -L "${symlinkPath}" ] || [ -f "${symlinkPath}" ]; then
          # Prüfe ob Symlink auf richtige Datei zeigt
          CURRENT_TARGET=$(readlink -f "${symlinkPath}" 2>/dev/null || echo "")
          EXPECTED_TARGET=$(readlink -f "${toString userConfigFile}" 2>/dev/null || echo "")
          
          if [ "$CURRENT_TARGET" != "$EXPECTED_TARGET" ]; then
            # Backup alte Config falls es eine echte Datei war
            if [ -f "${symlinkPath}" ] && [ ! -L "${symlinkPath}" ]; then
              cp "${symlinkPath}" "${symlinkPath}.backup.$(date +%s)"
            fi
            # Erstelle neuen Symlink
            ln -sfn "${toString userConfigFile}" "${symlinkPath}"
          fi
        else
          # Symlink existiert nicht, erstelle ihn
          ln -sfn "${toString userConfigFile}" "${symlinkPath}"
        fi
      '';
    }
    (lib.mkIf (cfg.enable or false) {
      # Desktop-Implementation (bestehender Code bleibt)
      imports = [ 
        ./display-managers
        ./display-servers
        ./environments
        ./audio
        ./themes
      ];
      
      environment = {
        variables = {
          XKB_DEFAULT_LAYOUT = systemConfig.keyboardLayout or "us";
          XKB_DEFAULT_OPTIONS = systemConfig.keyboardOptions or "";
        };
        sessionVariables = {
          XKB_DEFAULT_LAYOUT = systemConfig.keyboardLayout or "us";
          XKB_DEFAULT_OPTIONS = systemConfig.keyboardOptions or "";
        };
      };

      services.xserver = {
        xkb = {
          layout = systemConfig.keyboardLayout or "us";
          options = systemConfig.keyboardOptions or "";
        };
      };

      services.dbus = {
        enable = true;
        implementation = "broker";
      };

      assertions = [
        {
          assertion = cfg.display.server or "wayland" == "wayland" ||
                      cfg.display.server == "x11" ||
                      cfg.display.server == "hybrid";
          message = "Invalid display server selection: ${cfg.display.server or "none"}";
        }
        {
          assertion = cfg.environment or "plasma" == "plasma" ||
                      cfg.environment == "gnome" ||
                      cfg.environment == "xfce";
          message = "Invalid desktop environment: ${cfg.environment or "none"}";
        }
        {
          assertion = cfg.display.manager or "sddm" == "sddm" ||
                      cfg.display.manager == "gdm" ||
                      cfg.display.manager == "lightdm";
          message = "Invalid display manager: ${cfg.display.manager or "none"}";
        }
      ];
    })
  ];
}
```

### Schritt 6: flake.nix anpassen (WICHTIG!)
**Datei**: `nixos/flake.nix`

#### ⚠️ WICHTIG: Timing-Problem verstehen!

**Das Problem:**
- `flake.nix` läuft **VOR** dem Build (beim `nix eval` / `nix build`)
- `activationScripts` läuft **NACH** dem Build (bei `nixos-rebuild switch`)
- **Symlink existiert noch NICHT**, wenn `flake.nix` läuft!

**Die Lösung:**
- `flake.nix` muss **DIREKT** die echte Datei laden (`user-configs/`)
- Symlink wird **NACH** dem Build erstellt (für User-Editing)
- User editiert Symlink → schreibt in echte Datei → nächstes Rebuild lädt echte Datei

#### Code-Anpassung:

**Aktuell**:
```nix
loadConfig = configName:
  if builtins.pathExists ./configs/${configName}-config.nix
  then import ./configs/${configName}-config.nix
  else {};
```

**Neu** (lädt direkt aus Modul, mit Fallback für alte Configs):
```nix
loadConfig = configName:
  let
    # 1. Prüfe Modul user-configs (echte Datei) - PRIORITÄT
    modulePath = ./core/${configName}/user-configs/${configName}-config.nix;
    # 2. Fallback: Alte Config in /configs/ (für Migration)
    legacyPath = ./configs/${configName}-config.nix;
    # 3. Finde erste existierende (Modul hat Priorität)
    configPath = lib.findFirst (p: builtins.pathExists p) null [modulePath legacyPath];
  in
    if configPath != null
    then import configPath
    else {};
```

**Warum diese Reihenfolge?**
1. **Modul-Config zuerst**: Neue Struktur hat Priorität
2. **Legacy-Config als Fallback**: Unterstützt alte Systeme während Migration
3. **Symlink wird ignoriert**: Existiert noch nicht beim flake.nix Ausführen

#### Ablauf-Diagramm:

```
1. User: nixos-rebuild switch
   ↓
2. flake.nix wird ausgewertet
   ├─ Lädt: ./core/desktop/user-configs/desktop-config.nix (echte Datei)
   ├─ Symlink existiert noch NICHT
   └─ Erstellt systemConfig
   ↓
3. NixOS-System wird gebaut
   ↓
4. activationScripts läuft
   ├─ Erstellt: /etc/nixos/configs/desktop-config.nix (Symlink)
   └─ Symlink zeigt auf: core/desktop/user-configs/desktop-config.nix
   ↓
5. System ist aktiv
   ↓
6. User editiert: /etc/nixos/configs/desktop-config.nix (Symlink)
   └─ Änderungen landen in: core/desktop/user-configs/desktop-config.nix
   ↓
7. Nächstes Rebuild lädt wieder echte Datei (mit Änderungen)
```

#### Zusammenfassung:

- ✅ **flake.nix**: Lädt **direkt** aus `user-configs/` (echte Datei)
- ✅ **activationScripts**: Erstellt **Symlink** nach Build (für User-Editing)
- ✅ **User**: Editiert **Symlink**, der auf echte Datei zeigt
- ✅ **Nächstes Rebuild**: Lädt wieder echte Datei (mit User-Änderungen)

### Schritt 7: Testen
- [ ] `nixos-rebuild switch --flake /etc/nixos#hostname`
- [ ] Prüfe: Symlink wurde erstellt (`ls -la /etc/nixos/configs/desktop-config.nix`)
- [ ] Prüfe: Symlink zeigt auf richtige Datei
- [ ] Test: Desktop-Funktionalität (falls `desktop.enable = true`)
- [ ] Test: User kann Config in `/etc/nixos/configs/` editieren
- [ ] Test: Änderungen werden übernommen nach Rebuild

### Schritt 8: Migration bestehender Systeme
**Wenn `/etc/nixos/configs/desktop-config.nix` bereits existiert:**
- [ ] Backup erstellen
- [ ] Inhalt nach `core/desktop/user-configs/desktop-config.nix` kopieren
- [ ] Alte Datei löschen (Symlink wird erstellt)
- [ ] Rebuild & Test

### Schritt 9: Dokumentation
- [ ] README.md in `core/desktop/` aktualisieren
- [ ] Erkläre neue Struktur
- [ ] Erkläre wo User editieren soll (`/etc/nixos/configs/`)

### Schritt 10: Cleanup (optional)
- [ ] Alte Backup-Dateien entfernen (nach erfolgreichem Test)
- [ ] Code-Kommentare hinzufügen
- [ ] Validierung: Prüfe ob Symlink korrekt ist

## Checkliste: Desktop-Modul Migration

- [ ] **Vorbereitung**
  - [ ] Backup bestehender Config
  - [ ] Verzeichnisstruktur erstellt
  
- [ ] **Implementierung**
  - [ ] `user-configs/desktop-config.nix` erstellt
  - [ ] Default-Config definiert
  - [ ] Symlink-Management in `default.nix` implementiert
  - [ ] Bestehende Config migriert (falls vorhanden)
  
- [ ] **Testing**
  - [ ] Symlink wird erstellt
  - [ ] Symlink zeigt auf richtige Datei
  - [ ] Desktop-Funktionalität funktioniert
  - [ ] User kann Config editieren
  - [ ] Änderungen werden übernommen
  
- [ ] **Dokumentation**
  - [ ] README aktualisiert
  - [ ] Migration dokumentiert
  
- [ ] **Cleanup**
  - [ ] Alte Backups entfernt
  - [ ] Code kommentiert

### 2.2 Hardware Module (Mittel)
**Warum**: Wichtig, aber komplexer (CPU + GPU)

**Schritte**:
1. Erstelle `hardware/user-configs/hardware-config.nix`
2. Migriere bestehende `hardware-config.nix`
3. Erstelle Symlink-Management
4. Test: Hardware-Erkennung funktioniert
5. Update `flake.nix`

**Struktur**:
```
nixos/core/hardware/
├── user-configs/
│   └── hardware-config.nix
├── cpu/
├── gpu/
└── default.nix
```

### 2.3 Network Module (Mittel)
**Schritte**: Analog zu Hardware

### 2.4 System-Manager (Immer aktiv, aber Configs migrieren)
**Schritte**:
1. Erstelle `system-manager/user-configs/` (falls nötig)
2. Migriere Config-Logik
3. Symlink-Management

## Phase 3: Feature-Module Migration (Priorität: Mittel)

### 3.1 System-Logger (Einfach)
**Warum**: Gut strukturiert, klare Configs

**Schritte**:
1. Erstelle `features/system-logger/user-configs/system-logger-config.nix`
2. Migriere Config
3. Symlink-Management
4. Test

### 3.2 Features-Config (Meta-Config)
**Besonderheit**: Enthält Enable/Disable für alle Features

**✅ ENTSCHEIDUNG: Option B** - In `core/system-manager/user-configs/`

**Begründung**: 
- System-Manager verwaltet Features (enable/disable) via Feature-Manager
- System-Manager entscheidet, welche Features an/aus sind
- Logisch: Manager verwaltet seine Configs
- Features managen sich selbst (Implementation), aber System-Manager kontrolliert Enable/Disable

**Struktur**:
```
core/system-manager/
├── user-configs/
│   └── features-config.nix  # Meta-Config: { features = { system-logger = true; ... }; }
└── handlers/
    └── feature-manager.nix  # Editiert system-manager/user-configs/features-config.nix

features/
└── default.nix  # Lädt system-manager/user-configs/features-config.nix (via flake.nix)
```

**Wichtig**: 
- `features/default.nix` lädt die Config von `core/system-manager/user-configs/features-config.nix` (via flake.nix `loadConfig`)
- Feature-Manager editiert `system-manager/user-configs/features-config.nix` (echte Datei)
- Symlink wird von `system-manager/default.nix` erstellt (für User-Editing in `/etc/nixos/configs/`)

**Schritte**:
1. ✅ **ENTSCHEIDUNG**: Option B
2. Erstelle `core/system-manager/user-configs/features-config.nix`
3. Migriere bestehende `features-config.nix` → `core/system-manager/user-configs/`
4. Erstelle Symlink-Management in `core/system-manager/default.nix` (erstellt Symlink nach `/etc/nixos/configs/features-config.nix`)
5. Update `feature-manager.nix` → Editiert `/etc/nixos/core/system-manager/user-configs/features-config.nix`
6. Update `flake.nix` `loadConfig "features"` → Lädt von `core/system-manager/user-configs/features-config.nix`
7. Test: Features werden korrekt enabled/disabled

### 3.3 Weitere Features
- system-checks
- ssh-client-manager
- ssh-server-manager
- vm-manager
- etc.

## Phase 4: Installer Anpassung

### 4.1 Config-Erstellung
**Aktuell**: `shell/scripts/setup/config/data-collection/collect-system-data.sh`
- Erstellt Configs direkt in `/etc/nixos/configs/`
- **Status**: ⚠️ **NOCH NICHT ANGEPASST** - muss noch migriert werden

**Neu**:
1. Erstelle Configs in Modul `user-configs/`
2. Erstelle Symlinks nach `/etc/nixos/configs/`
3. Auto-Discovery: Findet alle Module, erstellt Configs (siehe Phase 7.2)

**Änderungen**:
- [ ] `init_desktop_config()` → Erstellt in `/etc/nixos/core/desktop/user-configs/desktop-config.nix`
  - **Pfad**: `/etc/nixos/core/desktop/user-configs/desktop-config.nix` (im deployed System)
  - **Grund**: Installer kopiert Repo nach `/etc/nixos/`, daher direkt dort erstellen
- [ ] `init_hardware_config()` → Erstellt in `/etc/nixos/core/hardware/user-configs/hardware-config.nix`
- [ ] `init_features_config()` → Erstellt in `/etc/nixos/core/system-manager/user-configs/features-config.nix`
  - **Pfad**: `/etc/nixos/core/system-manager/user-configs/features-config.nix` (im deployed System)
  - **Grund**: System-Manager verwaltet Features (enable/disable), also liegt Config dort (siehe Phase 3.2, Option B)
- [ ] Neue Funktion: `create_config_symlinks()` → Erstellt alle Symlinks nach `/etc/nixos/configs/`
  - Wird NACH Config-Erstellung aufgerufen
  - Erstellt Symlinks von `/etc/nixos/configs/` → `/etc/nixos/core|features/.../user-configs/`

**✅ Klarstellung**: Installer kopiert Repo nach `/etc/nixos/` (siehe `deploy-build.sh`)
- Configs werden direkt in `/etc/nixos/core/.../user-configs/` erstellt
- Symlinks werden nach `/etc/nixos/configs/` erstellt
- Alles im deployed System, kein relativer Pfad nötig

### 4.2 Setup-Flow
```
1. System-Daten sammeln
2. Für jedes Modul:
   a. Erstelle user-configs/module-name-config.nix
   b. Erstelle Symlink /etc/nixos/configs/module-name-config.nix
3. System-Config erstellen (minimal)
4. Build & Switch
```

## Phase 5: Updater Anpassung

### 5.1 Config-Migration
**Aktuell**: `nixos/core/config/config-migration.nix`
- Migriert `system-config.nix` Struktur
- Migriert Configs in `/etc/nixos/configs/`

**Neu**:
1. System-Config-Migration bleibt (zentral)
2. Module-Migration: Jedes Modul migriert seine eigenen Configs
3. Symlink-Management: Prüft/erstellt Symlinks nach Migration

**Änderungen**:
- [ ] Migration erkennt modulare Struktur
- [ ] Ruft Modul-Migrationen auf (falls vorhanden)
- [ ] Erstellt/aktualisiert Symlinks

### 5.2 Feature-Updates
**Aktuell**: `nixos/core/system-manager/scripts/update-features.nix`
- Aktualisiert Features
- Führt Feature-Migrationen aus

**Neu**:
1. Feature-Migration aktualisiert `user-configs/` direkt
2. Symlink bleibt bestehen
3. Backup in `user-configs/` oder zentral

## Phase 6: System-Config-Manager Anpassung

### 6.1 Config-Updates
**Aktuell**: `nixos/features/system-config-manager/default.nix`
- Editiert Configs direkt in `/etc/nixos/configs/`

**Neu**:
1. Editiert `user-configs/` (echte Datei, nicht Symlink)
2. Symlink zeigt automatisch auf aktualisierte Datei
3. Oder: Editiert Symlink, schreibt in echte Datei

**Änderungen**:
- [ ] `updateDesktopConfig` → Editiert `/etc/nixos/core/desktop/user-configs/desktop-config.nix` (echte Datei)
  - **Pfad**: `/etc/nixos/core/desktop/user-configs/desktop-config.nix` (im deployed System)
  - **Grund**: Installer kopiert Repo nach `/etc/nixos/`, daher direkt dort editieren
- [ ] Helper-Funktion: `find_module_config_path(moduleName)` → Findet Modul-Pfad (core vs features)
  - Prüft: `/etc/nixos/core/<module>/user-configs/` → `/etc/nixos/features/<module>/user-configs/`
  - Gibt vollständigen Pfad zurück
- [ ] Prüft ob Symlink existiert, erstellt wenn nicht
- [ ] Backup vor Änderung (`desktop-config.nix.backup.$(date +%s)`)
- [ ] Validiere Syntax nach Änderung (nix-instantiate --parse)
- [ ] **Wichtig**: Editiert echte Datei, nicht Symlink (Symlink zeigt automatisch auf aktualisierte Datei)

## Phase 7: Flake.nix Umstellung

### 7.1 Config-Loading
**Aktuell**:
```nix
loadConfig = configName:
  if builtins.pathExists ./configs/${configName}-config.nix
  then import ./configs/${configName}-config.nix
  else {};
```

**Neu** (⚠️ WICHTIG: Lädt direkt aus Modul, nicht Symlink!):
```nix
loadConfig = configName:
  let
    # Config-Datei-Name: ${configName}-config.nix
    configFileName = "${configName}-config.nix";
    
    # 1. Prüfe Modul user-configs (echte Datei) - PRIORITÄT
    # Durchsuche alle Module in core/ und features/
    # System-Manager ist ein Modul wie jedes andere - features-config.nix liegt dort
    modulePaths = [
      # Standard: Modul-Name = Config-Name (z.B. desktop-config.nix in desktop/)
      ./core/${configName}/user-configs/${configFileName}
      ./features/${configName}/user-configs/${configFileName}
      # Sonderfall: features-config.nix liegt in system-manager (weil System-Manager Features verwaltet)
      ./core/system-manager/user-configs/${configFileName}
    ];
    
    # 2. Fallback: Legacy Config in /configs/ (für Migration)
    legacyPath = ./configs/${configFileName};
    
    # 3. Finde erste existierende (Modul → Legacy)
    configPath = lib.findFirst (p: builtins.pathExists p) null (modulePaths ++ [legacyPath]);
  in
    if configPath != null
    then import configPath
    else {};
```

**Warum kein "specialPath"?**
- System-Manager ist ein Modul wie jedes andere
- `features-config.nix` liegt in `system-manager/user-configs/` (weil System-Manager Features verwaltet)
- Wir prüfen einfach alle möglichen Module-Pfade
- Konsistent mit anderen Configs

**⚠️ WICHTIG**: Symlink wird NICHT geprüft, da er beim flake.nix Ausführen noch nicht existiert!

### 7.2 Auto-Discovery
**Status**: Bereits vorhanden für Features! (siehe `features/default.nix`)

**Bestehendes Auto-Discovery**:
- ✅ Features: `features/default.nix` verwendet `builtins.readDir` für Auto-Discovery
- ✅ Config-Schemas: `core/config/config-schema.nix` verwendet Auto-Discovery
- ✅ Feature-Migrationen: `core/system-manager/handlers/feature-version-check.nix` verwendet Auto-Discovery

**Brauchen wir Auto-Discovery für Configs?**
- **Option A**: Ja, automatisch alle Module mit `user-configs/` finden (analog zu Features)
- **Option B**: Nein, manuell in `optionalConfigs` Liste (aktueller Ansatz)
- **Empfehlung**: **Option A** - Nutze bestehendes Auto-Discovery Pattern (wie Features)

**Warum Auto-Discovery?**
- ✅ Bereits vorhanden für Features (kann als Referenz dienen)
- ✅ Konsistent mit bestehender Architektur
- ✅ Weniger Wartung (neue Module werden automatisch gefunden)
- ✅ Einfacher zu erweitern

**Wie implementieren?**
- Nutze `builtins.readDir` für `core/` und `features/`
- Prüfe ob `user-configs/${moduleName}-config.nix` existiert
- Lade automatisch alle gefundenen Configs
- Reihenfolge: Core → Features (oder alphabetisch)

**Implementierung** (analog zu Features):
```nix
# Finde alle Module mit user-configs/
discoverModuleConfigs = dir:
  let
    modules = builtins.readDir dir;
    findConfigs = name: type:
      if type == "directory" then
        let 
          # Standard: ${moduleName}-config.nix
          standardConfig = dir + "/${name}/user-configs/${name}-config.nix";
          # Sonderfall: features-config.nix in system-manager
          featuresConfig = if name == "system-manager" 
            then dir + "/${name}/user-configs/features-config.nix"
            else null;
        in 
          # Prüfe beide (wenn features-config existiert, nutze es, sonst Standard)
          if featuresConfig != null && builtins.pathExists featuresConfig then ["features"]
          else if builtins.pathExists standardConfig then [name]
          else [];
      else [];
  in
    lib.concatMap (name: findConfigs name modules.${name}) (lib.attrNames modules);

# Auto-load alle gefundenen Configs
allModuleConfigs = discoverModuleConfigs ./core 
                ++ discoverModuleConfigs ./features;

# Ersetze manuelle optionalConfigs Liste durch Auto-Discovery
optionalConfigs = allModuleConfigs;
```

**Entscheidung**: ✅ **Auto-Discovery** (analog zu Features, konsistent)

## Phase 8: Migration von Bestehenden Systemen

### 8.1 Migrations-Script
**Neue Funktion**: `migrate-to-modular-configs`

**Zweck**: Migriert bestehende `/etc/nixos/configs/*-config.nix` → Module `user-configs/`

**⚠️ WICHTIG: Unterschied zu System-Config-Migration**
- **System-Config-Migration** (`ncc-migrate-config`): Migriert `system-config.nix` Struktur (v1→v2, etc.)
- **Modular-Config-Migration** (`migrate-to-modular-configs`): Migriert zentrale Configs → modulare Struktur
- **Das sind zwei verschiedene Migrationen!**

**Wo liegt das Script?**
- **Option A**: Als Command in `core/system-manager/commands.nix` → `ncc-migrate-to-modular`
- **Option B**: In `core/config/migrate-to-modular.nix` (analog zu `config-migration.nix`)
- **Empfehlung**: Option B (co-located mit anderen Config-Migrationen)

**Schritte**:
1. Backup `/etc/nixos/configs/` → `/etc/nixos/configs.backup.$(date +%s)`
2. Für jede Config in `/etc/nixos/configs/*-config.nix`:
   a. Extrahiere Modul-Name (z.B. `desktop-config.nix` → `desktop`)
   b. Finde zugehöriges Modul:
      - Core: `/etc/nixos/core/<module-name>/user-configs/`
      - Feature: `/etc/nixos/features/<module-name>/user-configs/`
      - Features-Config (Sonderfall): `/etc/nixos/core/system-manager/user-configs/` (siehe Phase 3.2, Option B)
   c. Erstelle `user-configs/` Verzeichnis (falls nicht existiert)
   d. Kopiere Config nach `module/user-configs/module-name-config.nix`
   e. Validiere Syntax (nix-instantiate --parse)
   f. Erstelle Symlink: `/etc/nixos/configs/module-name-config.nix` → `module/user-configs/`
3. Prüfe ob alle Symlinks korrekt (`readlink -f`)
4. Test: `nixos-rebuild switch --dry-run` (prüft ob System baut)
5. Optional: Alte Configs löschen (nach erfolgreichem Test)

**Mapping-Tabelle**:
```
desktop-config.nix        → /etc/nixos/core/desktop/user-configs/desktop-config.nix
hardware-config.nix       → /etc/nixos/core/hardware/user-configs/hardware-config.nix
features-config.nix       → /etc/nixos/core/system-manager/user-configs/features-config.nix
  (System-Manager verwaltet Features enable/disable, siehe Phase 3.2, Option B)
system-logger-config.nix → /etc/nixos/features/system-logger/user-configs/system-logger-config.nix
...
```

### 8.2 Rollback-Mechanismus
- Backup vor Migration
- Möglichkeit zurücksetzen
- Dokumentation

## Priorisierung: Welche Module zuerst?

### Phase 1: Quick Wins (Einfach, hoher Impact)
1. ✅ **Desktop** - Bereits teilweise implementiert, klar abgegrenzt
2. ✅ **Features-Config** - Meta-Config, wichtig für alle Features

### Phase 2: Core-Module (Wichtig, mittlerer Aufwand)
3. **Hardware** - Wichtig, aber komplexer
4. **Network** - Wichtig für alle Systeme
5. **System-Manager** - Immer aktiv, aber Configs migrieren

### Phase 3: Feature-Module (Nach Core)
6. **System-Logger** - Gut strukturiert
7. **System-Checks** - Einfach
8. **SSH-Manager** - Klar abgegrenzt
9. **VM-Manager** - Komplexer, später

### Phase 4: Infrastruktur (Parallel möglich)
- Installer-Anpassung
- Updater-Anpassung
- Flake.nix Umstellung

## Beispiel: Desktop-Modul nach Migration

### Vorher:
```
/etc/nixos/
├── configs/
│   └── desktop-config.nix  # User editiert hier
└── core/
    └── desktop/
        └── default.nix     # Liest systemConfig.desktop
```

### Nachher:
```
/etc/nixos/
├── configs/
│   └── desktop-config.nix  # Symlink → core/desktop/user-configs/
└── core/
    └── desktop/
        ├── user-configs/
        │   └── desktop-config.nix  # Echte Datei, User editiert hier
        └── default.nix             # Erstellt Symlink, liest systemConfig.desktop
```

### default.nix (Desktop):
```nix
{ config, lib, pkgs, systemConfig, ... }:
let
  cfg = systemConfig.desktop or {};
  userConfigFile = ./user-configs/desktop-config.nix;
  symlinkPath = "/etc/nixos/configs/desktop-config.nix";
in {
  config = lib.mkMerge [
    {
      # Erstelle Symlink auf Activation
      system.activationScripts.desktop-config-symlink = ''
        mkdir -p "$(dirname "${symlinkPath}")"
        # Erstelle Default-Config wenn nicht existiert
        if [ ! -f "${toString userConfigFile}" ]; then
          mkdir -p "$(dirname "${toString userConfigFile}")"
          cat > "${toString userConfigFile}" <<'EOF'
{
  desktop = {
    enable = false;
    environment = "plasma";
    # ... defaults
  };
}
EOF
        fi
        # Erstelle Symlink
        ln -sfn "${toString userConfigFile}" "${symlinkPath}"
      '';
    }
    (lib.mkIf (cfg.enable or false) {
      # Desktop-Implementation
      imports = [ 
        ./display-managers
        ./display-servers
        # ...
      ];
      # ...
    })
  ];
}
```

## Checkliste pro Modul

Für jedes Modul:
- [ ] Erstelle `user-configs/module-name-config.nix`
- [ ] Migriere bestehende Config (falls vorhanden)
- [ ] Erstelle Symlink-Management in `default.nix`
- [ ] Test: Config wird geladen
- [ ] Test: Symlink funktioniert
- [ ] Test: User kann editieren
- [ ] Update `flake.nix` (optional, wenn Auto-Discovery)
- [ ] Dokumentation aktualisieren

## Risiken & Mitigation

### Risiko 1: Symlinks brechen
**Mitigation**: 
- Prüfung bei jedem `nixos-rebuild switch`
- Auto-Reparatur wenn Symlink fehlt
- Backup vor Änderungen

### Risiko 2: Configs doppelt (Symlink + echte Datei)
**Mitigation**:
- Klare Regel: Symlink zeigt immer auf `user-configs/`
- Prüfung: Symlink muss auf richtige Datei zeigen
- Migration: Entfernt doppelte Configs

### Risiko 3: Module finden Configs nicht
**Mitigation**:
- Fallback-Mechanismus in `loadConfig`
- Auto-Discovery mit Warnung wenn nicht gefunden
- Dokumentation welche Module Configs brauchen

### Risiko 4: Migration bricht bestehende Systeme
**Mitigation**:
- Backup vor jeder Migration
- Rollback-Mechanismus
- Schrittweise Migration (nicht alles auf einmal)
- Test auf Test-Systemen

## Zeitplan (Schätzung)

- **Phase 1** (Infrastruktur): 2-3 Tage
- **Phase 2** (Core-Module): 1-2 Wochen
- **Phase 3** (Feature-Module): 1-2 Wochen
- **Phase 4-6** (Installer/Updater): 1 Woche
- **Phase 7** (Flake.nix): 2-3 Tage
- **Phase 8** (Migration): 2-3 Tage

**Gesamt**: ~4-6 Wochen (je nach Zeitaufwand)

## Nächste Schritte

1. **Sofort**: Template-Beispiel erstellen (Desktop-Modul)
2. **Diese Woche**: Symlink-Management System implementieren
3. **Diese Woche**: Desktop-Modul migrieren (Proof of Concept)
4. **Nächste Woche**: Installer anpassen
5. **Danach**: Weitere Module schrittweise

## ⚠️ Ist das "der Nix Weg"? (Wichtige Klarstellung)

### Was bedeutet Nix-idiomatisch vs. imperativ?

#### ✅ **Nix-idiomatisch**

**Grundprinzip:**
> *Alles soll deklarativ sein. Keine Zustandsänderung zur Laufzeit, keine imperative Manipulation.*

**Ein idiomatischer NixOS-Ansatz bedeutet:**
- Keine Seiten-Effekte
- Kein Schreiben auf das Dateisystem
- Keine Symlinks erzeugen
- Keine Dateien generieren, die der User später bearbeitet
- Alles erfolgt **durch pure Nix-Module**, die der User im Git-Repo ändert
- Systemzustand ergibt sich **allein aus `flake.nix` + Modulen**
- Das System ist *reproducible*, *stateless*, *deterministic*

➡️ **Wenn man ein File ändert → rebuild → fertig.**

**Das ist die "Nix-Religion".**

#### ❌ **Imperativ in Nix**

"Imperativ" bedeutet:
> *Der Computer führt Befehle aus, die den Zustand ändern (z. B. Dateien erzeugen, kopieren, symlinken, überschreiben).*

**Beispiele:**
- In `activationScripts` Symlinks erzeugen
- Dateien in `/etc/nixos/configs/` schreiben
- User-Configs während des Builds generieren
- Config-Files von einem Ort in einen anderen kopieren
- Migrationen ausführen, die reale Dateien anfassen

➡️ **Das ist nicht Nix-idiomatisch.**

**Aber:** Es ist **nicht verboten**, nur **eben nicht das reine NixOS-Paradigma**.

### ⚖️ Was bedeutet pragmatisch?

**Pragmatische Nix-Projekte:**
- Home-Manager (macht auch imperatives Zeug)
- NixOS-Installationsskripte
- Disnix, Morph
- NixOS-Manager, System-Manager
- NixVim (Erzeugt auch Dateien im Home-Verzeichnis)
- **NixOS Control Center** (muss Files erzeugen!)

Diese Tools arbeiten oft mit:
- imperativen Skripten
- Templates
- Migrationen
- Symlinks
- Config-Files, die kopiert/geschrieben werden

➡️ Sie sind **nicht 100% NixOS-idiomatisch**, aber **für Nutzerfreundlichkeit unverzichtbar**.

### 🧠 Wie ordnet sich NixOS Control Center ein?

**Dein Projekt:**
- Ein **NixOS-Management-System**
- Eine **UI/UX für NixOS**
- Installer, Updater, Migrationssystem
- Dynamisches System
- Config-Files, die *nicht zwingend im Git sein müssen*
- Module, die eigene Configs besitzen und diese verwalten

Das ist **nicht das typische NixOS-„Git + Rebuild"-Paradigma**.

Es ist vielmehr eine:
### ✔️ „NixOS-Distribution über NixOS"

➡️ Ähnlich wie: NixOS-Modules, Impermanence-Tools, NixOS-Managers, HM-Plugins etc.

**Das bedeutet:**
- Du **darfst** imperatives Verhalten verwenden
- Es ist **normal**, Symlinks zu erzeugen
- Es ist **normal**, Config-Files zu erstellen
- Es ist **normal**, Migrationen durchzuführen
- Es ist **normal**, einen Installer zu haben, der Dateien erzeugt

Du baust ein System, das **NixOS erweitert**, nicht nur Nix benutzt.

**Das ist nicht „unidiomatisch". Es ist einfach ein anderes Tooling-Level.**

### 🏁 Fazit

**Deine modular-symlink-basierte Architektur ist:**
- ✔️ praxisorientiert
- ✔️ verständlich
- ✔️ perfekt für Tools mit UI
- ✔️ robust und update-freundlich
- ✔️ vergleichbar mit Home-Manager, Impermanence, NixOS-Manager
- ❌ nicht „pure Nix" — aber muss es auch nicht sein

**TL;DR:** „Idiomatisch" bedeutet rein deklarativ ohne Seiteneffekte. Dein System verwendet Symlinks, Migrationen und generierte Dateien — das ist imperativ, aber für einen NixOS-Manager absolut korrekt und pragmatisch.

## Offene Fragen & Entscheidungen

### ✅ Bereits entschieden:

1. **Config-Namen**: `module-name-config.nix` (klar, eindeutig) ✅
2. **Migration**: Schrittweise (Desktop → Hardware → Features) ✅
3. **Backward Compatibility**: Ja, als Fallback in `loadConfig` ✅
4. **Symlink-Strategie**: Symlinks für User-Editing, flake.nix lädt echte Datei ✅
5. **Features-Config Location**: ✅ **Option B** - `core/system-manager/user-configs/features-config.nix` (siehe Phase 3.2)
   - **Begründung**: System-Manager verwaltet Features (enable/disable) via Feature-Manager
   - **Konsequenz**: `flake.nix` `loadConfig "features"` lädt von `core/system-manager/user-configs/features-config.nix`
   - **Konsequenz**: Feature-Manager editiert `system-manager/user-configs/features-config.nix`
   - **Konsequenz**: Symlink wird von `system-manager/default.nix` erstellt

### ⚠️ Noch offen:
   
2. **Auto-Discovery**: ✅ **JA - Nutze bestehendes Pattern** (siehe Phase 7.2)
   - Bereits vorhanden für Features (analog implementieren)
   - Automatisch alle Module mit `user-configs/` finden
   - Ersetzt manuelle `optionalConfigs` Liste
   
3. **Mehrere Configs pro Modul?**
   - **Frage**: Kann ein Modul mehrere Config-Dateien haben?
   - **Option A**: Nur eine Config pro Modul (`module-name-config.nix`)
     - Kategorisierung innerhalb der Config (z.B. `{ desktop = { ... }; audio = { ... }; }`)
   - **Option B**: Mehrere Configs pro Modul (z.B. `desktop-display-config.nix`, `desktop-audio-config.nix`)
     - Komplexer, aber flexibler
   - **Empfehlung**: **Option A** - Eine Config pro Modul, kategorisiert
     - Einfacher zu verwalten
     - Konsistent mit bestehender Struktur
     - Symlink-Strategie bleibt einfach (ein Symlink pro Modul)
   
4. **Installer-Pfade**: ✅ **Im deployed Repo** (`/etc/nixos/core/.../user-configs/`)
   - Installer kopiert Repo nach `/etc/nixos/` (siehe `deploy-build.sh`)
   - Configs werden direkt in `/etc/nixos/core/.../user-configs/` erstellt
   - Kein relativer Pfad nötig
   
5. **System-Config-Manager Pfade**: ✅ **Helper-Funktion nötig** (siehe Phase 6.1)
   - Funktion: `find_module_config_path(moduleName)`
   - Prüft: `/etc/nixos/core/<module>/user-configs/` → `/etc/nixos/features/<module>/user-configs/`
   
6. **Migration-Script**: ✅ **In `core/config/migrate-to-modular.nix`** (siehe Phase 8.1)
   - Co-located mit anderen Config-Migrationen
   - Unterschied zu System-Config-Migration (v1→v2): Das ist eine andere Art von Migration

### 📋 Action Items:

- [x] **Entscheidung**: Features-Config Location - ✅ **Option B** (System-Manager, siehe Phase 3.2)
- [ ] **Implementierung**: Installer anpassen (→ Phase 4) - ⚠️ **NOCH NICHT GEMACHT**
- [ ] **Implementierung**: Migration-Script erstellen (→ Phase 8)
- [ ] **Implementierung**: Helper-Funktion für Modul-Pfad-Resolution (→ Phase 6)
- [ ] **Implementierung**: Feature-Manager anpassen (→ Phase 3.2, Schritt 5)
- [ ] **Implementierung**: `flake.nix` `loadConfig` anpassen (→ Phase 7.1) - Kein specialPath, konsistent
- [ ] **Implementierung**: Symlink-Management in `system-manager/default.nix` (→ Phase 3.2, Schritt 4)
- [ ] **Implementierung**: Auto-Discovery für Configs (→ Phase 7.2) - Nutze bestehendes Pattern
