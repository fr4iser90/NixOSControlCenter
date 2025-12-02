# Package Structure Analysis & Improvement Proposal

## Aktuelle Probleme

### 1. **Fehlende SystemType-Filterung**
- **Problem**: Im Desktop-Modus werden auch Server-Module geladen (z.B. `server.docker = false` in Desktop-Profilen)
- **Ursache**: `nixos/packages/default.nix` lädt alle Module aus `packageModules`, unabhängig vom `systemType`
- **Auswirkung**: Unnötige Konfiguration, Verwirrung, potenzielle Konflikte

### 2. **Unklare Modul-Kategorisierung**
- **Problem**: Module sind nicht klar als "desktop-only", "server-only" oder "universal" markiert
- **Aktuell**: 
  - `gaming/` → Desktop-only
  - `development/` → Universal (kann auf Desktop und Server sein)
  - `server/` → Server-only
- **Fehlt**: Explizite Metadaten, welche Module für welchen `systemType` relevant sind

### 3. **Redundante Konfiguration in Profilen**
- **Problem**: Profile müssen explizit `server.docker = false` setzen, obwohl es ein Desktop-Profil ist
- **Beispiel**: `fr4iser-home` hat `server.docker = false`, obwohl `systemType = "desktop"`

### 4. **Fehlende Preset-Struktur**
- **Problem**: Keine vordefinierten Presets für häufige Kombinationen
- **Aktuell**: User muss jedes Modul einzeln konfigurieren
- **Wünschenswert**: Presets wie "Gaming Desktop", "Development Workstation", "Homelab Server"

## Aktuelle Struktur

```
nixos/packages/
├── base/
│   ├── desktop.nix      # Basis-Pakete für Desktop
│   ├── server.nix       # Basis-Pakete für Server
│   └── homelab.nix      # Basis-Pakete für Homelab
├── modules/
│   ├── development/     # Universal (Desktop + Server)
│   │   ├── default.nix
│   │   ├── game.nix
│   │   ├── python.nix
│   │   ├── system.nix
│   │   ├── virtualization.nix
│   │   └── web.nix
│   ├── gaming/          # Desktop-only
│   │   ├── default.nix
│   │   ├── emulation.nix
│   │   └── streaming.nix
│   └── server/          # Server-only
│       ├── default.nix
│       ├── database.nix
│       ├── docker.nix
│       ├── docker-rootless.nix
│       ├── mail.nix
│       ├── virtualization.nix
│       └── web.nix
└── default.nix          # Haupt-Logik
```

## Vorschlag: Verbesserte Struktur

### Option 1: SystemType-basierte Filterung (Empfohlen)

**Konzept**: Module werden automatisch nach `systemType` gefiltert

```nix
# nixos/packages/modules/metadata.nix
{
  # Definiere welche Module für welchen systemType verfügbar sind
  moduleSystemTypes = {
    gaming = [ "desktop" "homelab" ];  # Gaming nur für Desktop/Homelab
    development = [ "desktop" "server" "homelab" ];  # Universal
    server = [ "server" "homelab" ];  # Server-Module nur für Server/Homelab
  };
}
```

**Vorteile**:
- Automatische Filterung
- Keine redundante Konfiguration in Profilen
- Klare Trennung

**Nachteile**:
- Etwas komplexere Logik
- Neue Module müssen Metadaten haben

### Option 2: Explizite Modul-Kategorien

**Konzept**: Module werden in `desktop/`, `server/`, `universal/` organisiert

```
nixos/packages/
├── base/
│   ├── desktop.nix
│   ├── server.nix
│   └── homelab.nix
├── modules/
│   ├── desktop/         # Nur für Desktop
│   │   ├── gaming/
│   │   └── multimedia/
│   ├── server/          # Nur für Server
│   │   ├── docker/
│   │   ├── database/
│   │   └── mail/
│   └── universal/       # Für alle SystemTypes
│       ├── development/
│       └── virtualization/
```

**Vorteile**:
- Sehr klare Struktur
- Einfache Filterung nach Verzeichnis

**Nachteile**:
- Große Umstrukturierung nötig
- Module können nicht einfach verschoben werden

### Option 3: Preset-System (Kombiniert mit Option 1)

**Konzept**: Vordefinierte Presets für häufige Kombinationen

```nix
# nixos/packages/presets/default.nix
{
  "gaming-desktop" = {
    description = "Gaming Desktop mit Streaming und Emulation";
    systemTypes = [ "desktop" ];
    modules = {
      gaming = { streaming = true; emulation = true; };
      development = { game = true; };
    };
  };
  
  "development-workstation" = {
    description = "Development Workstation mit Web- und Game-Dev";
    systemTypes = [ "desktop" ];
    modules = {
      development = { web = true; game = true; };
    };
  };
  
  "homelab-server" = {
    description = "Homelab Server mit Docker und Datenbanken";
    systemTypes = [ "server" "homelab" ];
    modules = {
      server = { docker = "rootless"; database = true; };
    };
  };
}
```

## Empfohlene Lösung: Hybrid-Ansatz

### 1. SystemType-Metadaten für Module

```nix
# nixos/packages/modules/metadata.nix
{
  moduleMetadata = {
    gaming = {
      systemTypes = [ "desktop" "homelab" ];
      description = "Gaming-related packages and tools";
    };
    development = {
      systemTypes = [ "desktop" "server" "homelab" ];
      description = "Development tools and IDEs";
    };
    server = {
      systemTypes = [ "server" "homelab" ];
      description = "Server-specific services and tools";
    };
  };
}
```

### 2. Automatische Filterung in default.nix

```nix
# nixos/packages/default.nix
let
  moduleMetadata = import ./modules/metadata.nix;
  
  # Filtere Module basierend auf systemType
  filterModulesBySystemType = systemType: modules:
    lib.filterAttrs (moduleName: moduleConfig:
      let meta = moduleMetadata.moduleMetadata.${moduleName} or {};
      in lib.elem systemType (meta.systemTypes or [])
    ) modules;
  
  # Nur relevante Module laden
  relevantModules = filterModulesBySystemType systemConfig.systemType systemConfig.packageModules;
in {
  imports = 
    [ (basePackages.${systemConfig.systemType}) ]
    ++ (loadModules relevantModules);
}
```

### 3. Preset-System für häufige Kombinationen

```nix
# nixos/packages/presets/default.nix
{
  presets = {
    "gaming-desktop" = {
      description = "Gaming Desktop mit Streaming und Emulation";
      systemTypes = [ "desktop" ];
      packageModules = {
        gaming = { streaming = true; emulation = true; };
        development = { game = true; };
      };
    };
    
    "development-workstation" = {
      description = "Development Workstation";
      systemTypes = [ "desktop" ];
      packageModules = {
        development = { web = true; game = true; python = true; };
      };
    };
    
    "homelab-server" = {
      description = "Homelab Server";
      systemTypes = [ "server" "homelab" ];
      packageModules = {
        server = { docker = "rootless"; database = true; web = true; };
      };
    };
  };
}
```

### 4. Vereinfachte Profil-Konfiguration

**Vorher** (redundant):
```nix
{
  systemType = "desktop";
  packageModules = {
    gaming = { streaming = true; emulation = true; };
    development = { game = true; web = true; };
    server = { docker = false; web = false; };  # ❌ Redundant!
  };
}
```

**Nachher** (sauber):
```nix
{
  systemType = "desktop";
  packageModules = {
    gaming = { streaming = true; emulation = true; };
    development = { game = true; web = true; };
    # server-Module werden automatisch ignoriert ✅
  };
}
```

## Implementierungsplan

### Phase 1: Metadaten-System
1. Erstelle `nixos/packages/modules/metadata.nix`
2. Definiere `systemTypes` für jedes Modul
3. Update `default.nix` mit Filterung

### Phase 2: Preset-System
1. Erstelle `nixos/packages/presets/default.nix`
2. Definiere häufige Presets
3. Integriere Presets in Installer

### Phase 3: Profil-Bereinigung
1. Entferne redundante `server.* = false` aus Desktop-Profilen
2. Teste, dass nur relevante Module geladen werden

### Phase 4: Dokumentation
1. Dokumentiere Modul-SystemTypes
2. Dokumentiere Preset-Verwendung
3. Update Installer-Beschreibungen

## Vorteile der Lösung

✅ **Automatische Filterung**: Keine redundante Konfiguration nötig
✅ **Klare Struktur**: Module sind klar kategorisiert
✅ **Preset-System**: Schnelle Konfiguration für häufige Fälle
✅ **Rückwärtskompatibel**: Bestehende Profile funktionieren weiterhin
✅ **Erweiterbar**: Neue Module einfach hinzufügbar

## Offene Fragen

1. **Soll `development` wirklich universal sein?** 
   - Oder gibt es Desktop-spezifische Dev-Tools (z.B. IDEs mit GUI)?
   - Sollte `development` in `desktop/development` und `server/development` aufgeteilt werden?

2. **Wie mit Hybrid-Systemen umgehen?**
   - Systeme die sowohl Desktop als auch Server-Funktionen haben
   - Z.B. "Gaming Server" mit Desktop-UI aber Server-Services

3. **Preset-Vererbung?**
   - Können Presets andere Presets erweitern?
   - Z.B. `gaming-desktop` erweitert `base-desktop`

