# Package Structure Redesign - Komplett Neu Gedacht

## Problem mit der aktuellen Struktur

Die aktuelle Struktur ist **inkonsistent und verwirrend**:

```
❌ gaming/          → Warum ist "gaming" ein Modul?
   ├── streaming.nix
   └── emulation.nix

❌ development/     → Warum ist "development" ein Modul?
   ├── web.nix      → Aber es gibt auch server/web.nix?!
   └── game.nix

❌ server/          → Warum ist "server" ein Modul?
   ├── docker.nix
   └── web.nix      → Was ist der Unterschied zu development/web.nix?
```

**Probleme:**
1. **Inkonsistente Hierarchie**: `gaming/streaming` vs `server/docker` - warum unterschiedliche Ebenen?
2. **Verwirrende Namen**: `development/web.nix` vs `server/web.nix` - was ist der Unterschied?
3. **Falsche Kategorisierung**: "gaming" ist kein Modul, es ist ein **Use-Case**!
4. **Redundanz**: Warum gibt es `development/web.nix` UND `server/web.nix`?

## Professionelle Ansätze - Wie machen es die Profis?

### 1. **NixOS Community Configs**
- Organisiert nach **Features**, nicht nach Kategorien
- Flache Struktur: `docker.nix`, `database.nix`, `gaming.nix`
- Jedes Feature ist selbstständig

### 2. **Enterprise Config Management**
- **Rollen-basiert**: `roles/gaming-desktop.nix`, `roles/dev-workstation.nix`
- **Feature-basiert**: `features/streaming.nix`, `features/docker.nix`
- **Preset-basiert**: `presets/gaming-desktop.nix` kombiniert Features

### 3. **Home Manager Approach**
- Flache Feature-Liste
- User wählt Features, nicht Kategorien
- Keine verschachtelten Module

## Neuer Ansatz: Feature-First Architecture

### Konzept: Features statt Module

**Jedes Feature ist ein eigenständiges Modul** - keine verschachtelten Kategorien mehr!

```
nixos/packages/
├── base/
│   ├── desktop.nix      # Minimale Desktop-Basis
│   ├── server.nix       # Minimale Server-Basis
│   └── homelab.nix      # Minimale Homelab-Basis
│
├── features/            # 🎯 FLACHE STRUKTUR - Alle Features gleichwertig
│   │
│   ├── # Gaming Features (Gruppe in metadata.nix)
│   ├── streaming.nix    # Gaming Streaming (Desktop/Homelab)
│   ├── emulation.nix    # Retro Gaming Emulation (Desktop/Homelab)
│   │
│   ├── # Development Features (Gruppe in metadata.nix)
│   ├── game-dev.nix     # Game Development Tools (Desktop/Server)
│   ├── web-dev.nix      # Web Development (Desktop/Server)
│   ├── python-dev.nix   # Python Development (Desktop/Server)
│   │
│   ├── # Virtualization Features (Gruppe in metadata.nix) 🎯
│   ├── docker.nix       # Docker Container (root, für Swarm/OCI)
│   ├── docker-rootless.nix  # Docker Container (rootless, sicherer)
│   ├── podman.nix       # Podman Container (alternative zu Docker)
│   ├── qemu-vm.nix      # QEMU/KVM Virtual Machines
│   ├── virt-manager.nix # Virtualization Management GUI (Desktop)
│   │
│   ├── # Server Features (Gruppe in metadata.nix)
│   ├── database.nix     # Database Services (PostgreSQL, MySQL)
│   ├── web-server.nix   # Web Server (nginx, apache)
│   ├── mail-server.nix  # Mail Server (Server)
│   │
│   └── # Weitere Features...
│
├── presets/             # 🎯 Vordefinierte Feature-Kombinationen
│   ├── gaming-desktop.nix
│   │   # Aktiviert: streaming, emulation, game-dev
│   ├── dev-workstation.nix
│   │   # Aktiviert: web-dev, python-dev, game-dev
│   ├── homelab-server.nix
│   │   # Aktiviert: docker-rootless, database, web-server
│   └── gaming-server.nix
│       # Aktiviert: docker, database, streaming (Hybrid!)
│
└── metadata.nix         # 🎯 Feature-Metadaten
    # Definiert: systemTypes, dependencies, conflicts
```

## Feature-Metadaten System

```nix
# nixos/packages/metadata.nix
{
  features = {
    # Gaming Features
    streaming = {
      systemTypes = [ "desktop" "homelab" ];
      group = "gaming";  # 🎯 Logische Gruppierung für Organisation
      description = "Gaming streaming tools (OBS, etc.)";
      dependencies = [];
    };
    
    emulation = {
      systemTypes = [ "desktop" "homelab" ];
      group = "gaming";
      description = "Retro gaming emulation";
      dependencies = [];
    };
    
    # Development Features
    game-dev = {
      systemTypes = [ "desktop" "server" "homelab" ];
      group = "development";
      description = "Game development tools (engines, IDEs)";
      dependencies = [];
    };
    
    web-dev = {
      systemTypes = [ "desktop" "server" "homelab" ];
      group = "development";
      description = "Web development tools (Node, npm, IDEs)";
      dependencies = [];
    };
    
    python-dev = {
      systemTypes = [ "desktop" "server" "homelab" ];
      group = "development";
      description = "Python development environment";
      dependencies = [];
    };
    
    # Virtualization Features (Gruppe!)
    docker = {
      systemTypes = [ "server" "homelab" ];
      group = "virtualization";  # 🎯 Docker ist Teil von Virtualization
      description = "Docker with root (for Swarm/OCI)";
      conflicts = [ "docker-rootless" ];
    };
    
    docker-rootless = {
      systemTypes = [ "desktop" "server" "homelab" ];
      group = "virtualization";  # 🎯 Docker ist Teil von Virtualization
      description = "Rootless Docker (safer, default)";
      conflicts = [ "docker" ];
    };
    
    podman = {
      systemTypes = [ "desktop" "server" "homelab" ];
      group = "virtualization";
      description = "Podman container runtime (alternative to Docker)";
      conflicts = [ "docker" "docker-rootless" ];
    };
    
    qemu-vm = {
      systemTypes = [ "desktop" "server" "homelab" ];
      group = "virtualization";
      description = "QEMU/KVM virtual machines";
      dependencies = [];
    };
    
    virt-manager = {
      systemTypes = [ "desktop" ];
      group = "virtualization";
      description = "Virtualization management GUI (requires qemu-vm)";
      dependencies = [ "qemu-vm" ];
    };
    
    # Server Features
    database = {
      systemTypes = [ "server" "homelab" ];
      group = "server";
      description = "Database services (PostgreSQL, MySQL)";
      dependencies = [];
    };
    
    web-server = {
      systemTypes = [ "server" "homelab" ];
      group = "server";
      description = "Web server (nginx, apache)";
      dependencies = [];
    };
    
    mail-server = {
      systemTypes = [ "server" ];
      group = "server";
      description = "Mail server";
      dependencies = [];
    };
  };
  
  # Helper: Get all features in a group
  getFeaturesByGroup = group:
    lib.filterAttrs (name: meta: meta.group == group) features;
  
  # Helper: Get all virtualization features
  virtualizationFeatures = getFeaturesByGroup "virtualization";
}
```

## Neue Konfigurationsstruktur

### Profil-Konfiguration (Vereinfacht)

```nix
# Vorher (kompliziert und redundant):
{
  systemType = "desktop";
  packageModules = {
    gaming = { streaming = true; emulation = true; };
    development = { game = true; web = true; };
    server = { docker = false; web = false; };  # ❌ Redundant!
  };
}

# Nachher (sauber und klar):
{
  systemType = "desktop";
  # Option 1: Features direkt
  features = [ "streaming" "emulation" "game-dev" "web-dev" ];
  
  # Option 2: Preset verwenden
  preset = "gaming-desktop";
  
  # Option 3: Preset + zusätzliche Features
  preset = "dev-workstation";
  additionalFeatures = [ "python-dev" ];
}
```

### Preset-Definitionen

```nix
# nixos/packages/presets/gaming-desktop.nix
{
  description = "Gaming Desktop mit Streaming und Emulation";
  systemTypes = [ "desktop" ];
  features = [
    "streaming"      # OBS, etc.
    "emulation"      # Retro gaming
    "game-dev"       # Game engines
  ];
}

# nixos/packages/presets/dev-workstation.nix
{
  description = "Development Workstation";
  systemTypes = [ "desktop" ];
  features = [
    "web-dev"        # Node, npm, IDEs
    "python-dev"     # Python environment
    "game-dev"       # Game development
  ];
}

# nixos/packages/presets/homelab-server.nix
{
  description = "Homelab Server";
  systemTypes = [ "server" "homelab" ];
  features = [
    "docker-rootless"  # Containerization
    "database"         # Databases
    "web-server"       # Web server
  ];
}

# nixos/packages/presets/gaming-server.nix (Hybrid!)
{
  description = "Gaming Server mit Desktop-UI";
  systemTypes = [ "desktop" "server" ];  # Hybrid!
  features = [
    "streaming"        # Desktop-Feature
    "docker"           # Server-Feature
    "database"         # Server-Feature
  ];
}
```

## Implementierung: Neue default.nix

```nix
# nixos/packages/default.nix
{ config, lib, pkgs, systemConfig, ... }:

let
  metadata = import ./metadata.nix;
  
  # Lade Preset wenn gesetzt
  presetConfig = if systemConfig.preset or null != null then
    import (./presets + "/${systemConfig.preset}.nix")
  else null;
  
  # Kombiniere Preset-Features + zusätzliche Features
  allFeatures = 
    (presetConfig.features or [])
    ++ (systemConfig.additionalFeatures or [])
    ++ (systemConfig.features or []);
  
  # Filtere Features nach systemType
  validFeatures = lib.filter (feature:
    let meta = metadata.features.${feature} or {};
    in lib.elem systemConfig.systemType (meta.systemTypes or [])
  ) allFeatures;
  
  # Prüfe Conflicts
  checkConflicts = features:
    let
      conflicts = lib.flatten (map (f:
        metadata.features.${f}.conflicts or []
      ) features);
      hasConflict = lib.any (f: lib.elem f conflicts) features;
    in
      if hasConflict then
        throw "Feature conflict detected in: ${lib.concatStringsSep ", " features}"
      else features;
  
  # Finale Feature-Liste
  finalFeatures = checkConflicts validFeatures;
  
  # Lade Feature-Module
  featureModules = map (feature:
    ./features/${feature}.nix
  ) finalFeatures;
  
in {
  imports = 
    # Base für systemType
    [ (import ./base/${systemConfig.systemType}.nix) ]
    # Feature-Module
    ++ featureModules;
}
```

## Vorteile der neuen Struktur

### ✅ Klarheit
- Jedes Feature ist gleichwertig (flache Struktur)
- Logische Gruppierung in Metadaten (nicht in Dateisystem)
- Klare Namen: `docker.nix`, `docker-rootless.nix` statt verschachtelt

### ✅ Flexibilität
- Features können beliebig kombiniert werden
- Presets für häufige Kombinationen
- Hybrid-Systeme möglich (Desktop + Server Features)
- Gruppierung nur für Organisation, nicht für Loading

### ✅ Wartbarkeit
- Neue Features einfach hinzufügen: `features/mein-feature.nix`
- Keine verschachtelten Strukturen im Dateisystem
- Logische Gruppierung in `metadata.nix` (z.B. "virtualization")
- Features können zu Gruppen gehören, bleiben aber flach

### ✅ Installer-Integration
- User wählt Preset ODER Features
- Automatische systemType-Filterung
- Conflict-Prüfung (z.B. docker vs docker-rootless)
- Gruppierung kann für UI-Organisation genutzt werden

## Migrationsplan

### Phase 1: Feature-Umstrukturierung
1. Erstelle `features/` Verzeichnis
2. Verschiebe/Spalte Module auf:
   - `gaming/streaming.nix` → `features/streaming.nix`
   - `gaming/emulation.nix` → `features/emulation.nix`
   - `development/game.nix` → `features/game-dev.nix`
   - `development/web.nix` → `features/web-dev.nix`
   - `development/virtualization.nix` → `features/qemu-vm.nix` + `features/virt-manager.nix`
   - `server/docker.nix` → `features/docker.nix`
   - `server/docker-rootless.nix` → `features/docker-rootless.nix`
   - `server/database.nix` → `features/database.nix`
   - `server/web.nix` → `features/web-server.nix`
   - etc.

### Phase 2: Metadaten-System
1. Erstelle `metadata.nix` mit allen Features
2. Definiere `systemTypes` für jedes Feature
3. Definiere `conflicts` wo nötig

### Phase 3: Preset-System
1. Erstelle `presets/` Verzeichnis
2. Definiere häufige Presets
3. Teste Preset-Loading

### Phase 4: Neue default.nix
1. Implementiere neue Logik
2. Feature-Filterung nach systemType
3. Conflict-Prüfung
4. Preset-Support

### Phase 5: Profil-Migration
1. Konvertiere Profile zu neuer Struktur
2. Entferne redundante `server.* = false`
3. Nutze Presets wo möglich

### Phase 6: Installer-Update
1. Update Installer für Feature-Auswahl
2. Preset-Auswahl hinzufügen
3. Beschreibungen aktualisieren

## Beispiel: Gaming Desktop Profil

### Vorher (alt):
```nix
{
  systemType = "desktop";
  packageModules = {
    gaming = { streaming = true; emulation = true; };
    development = { game = true; };
    server = { docker = false; web = false; };  # ❌
  };
}
```

### Nachher (neu):
```nix
{
  systemType = "desktop";
  preset = "gaming-desktop";
  # Oder explizit:
  # features = [ "streaming" "emulation" "game-dev" ];
}
```

## Offene Fragen

1. **Feature-Namen**: 
   - `streaming` vs `gaming-streaming`?
   - `web-dev` vs `web-development`?
   - → **Empfehlung**: Kurze, klare Namen (ohne Präfix)

2. **Base-Pakete**:
   - Sollen Base-Pakete auch Features sein?
   - → **Empfehlung**: Nein, Base bleibt separat

3. **Dependencies**:
   - Sollen Features andere Features abhängen können?
   - → **Empfehlung**: Ja, z.B. `virt-manager` benötigt `qemu-vm`

4. **Hybrid-Systeme**:
   - Wie mit Desktop+Server Features umgehen?
   - → **Empfehlung**: Presets erlauben mehrere systemTypes

5. **Gruppierung**:
   - Soll Gruppierung nur in Metadaten sein oder auch im Dateisystem?
   - → **Empfehlung**: Nur in Metadaten! Dateisystem bleibt flach
   - → **Vorteil**: Docker und QEMU sind beide "virtualization", aber gleichwertig

## Fazit

Die neue Struktur ist:
- ✅ **Einfacher**: Flache Feature-Liste
- ✅ **Klarer**: Keine verwirrenden Hierarchien
- ✅ **Flexibler**: Beliebige Feature-Kombinationen
- ✅ **Professioneller**: Wie es die Community macht
- ✅ **Wartbarer**: Einfach zu erweitern

**Nächster Schritt**: Implementierung starten? 🚀

