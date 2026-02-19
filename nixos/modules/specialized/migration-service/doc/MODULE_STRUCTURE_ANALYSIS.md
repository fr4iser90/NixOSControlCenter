# Migration Service - Modul-Struktur Analyse

## Vergleich mit MODULE_TEMPLATE

### ✅ Aktuell vorhanden

```
migration-service/
├── README.md                    ✅ Vorhanden
└── doc/                        ✅ Vorhanden
    ├── DOCUMENTATION_CHECKLIST.md
    ├── MIGRATION_SERVICE_ARCHITECTURE.md
    ├── MIGRATION_SERVICE_STRUCTURE.md
    └── MIGRATION_SERVICE_WORKFLOW.md
```

### ❌ Fehlend (gemäß MODULE_TEMPLATE)

```
migration-service/
├── default.nix                 ❌ FEHLT - Modul-Entry-Point (REQUIRED)
├── options.nix                 ❌ FEHLT - Config-Optionen (REQUIRED)
├── config.nix                  ❌ FEHLT - System-Integration (REQUIRED wenn enabled)
├── commands.nix                ❌ FEHLT - CLI-Commands (OPTIONAL aber empfohlen)
├── api.nix                     ⏳ OPTIONAL - API-Definition
├── CHANGELOG.md                ⏳ EMPFOHLEN - Version-Historie
│
├── snapshot/                   ❌ FEHLT - Snapshot-Scripts
│   ├── windows/
│   │   └── migration-snapshot.ps1
│   └── macos/
│       └── migration-snapshot.sh
│
├── mapping/                    ❌ FEHLT - Programm-Mapping
│   ├── mapping-database.json
│   └── mapper.nix
│
├── web-service/                ❌ FEHLT - Web-Service
│   ├── api/
│   │   └── main.go
│   ├── config-generator/
│   │   └── generator.nix
│   └── handlers/
│       └── snapshot-handler.go
│
├── iso-builder/                ❌ FEHLT - ISO-Builder
│   └── iso-builder.nix
│
├── lib/                        ⏳ OPTIONAL - Utility-Funktionen
│   └── default.nix
│
└── systemd.nix                 ⏳ OPTIONAL - Systemd-Services
```

---

## Erforderliche Dateien (gemäß MODULE_TEMPLATE)

### 1. `default.nix` - REQUIRED ⭐

**Zweck:** Modul-Entry-Point mit Metadata

**Pattern:**
```nix
{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:

with lib;

let
  moduleName = baseNameOf ./. ;  # "migration-service"
  cfg = getModuleConfig moduleName;
  
  # Module metadata (REQUIRED)
  metadata = {
    role = "optional";              # "optional" | "core" | "required"
    name = "migration-service";     # Unique module identifier
    description = "Windows/macOS → NixOS Migration Service"; # Human-readable
    category = "specialized";        # "core" | "base" | "security" | "infrastructure" | "specialized"
    subcategory = "migration";      # Specific subcategory
    stability = "experimental";     # "stable" | "experimental" | "deprecated" | "beta" | "alpha"
    version = "0.1.0";              # SemVer: MAJOR.MINOR.PATCH
  };
in
{
  # REQUIRED: Export metadata for discovery system
  _module.metadata = metadata;
  
  _module.args = {
    migrationServiceCfg = cfg;
    moduleName = moduleName;
  };

  # Module imports
  imports = [
    ./options.nix  # Always import options first
  ] ++ (if (cfg.enable or false) then [
    ./config.nix
    ./commands.nix
  ] else []);
}
```

### 2. `options.nix` - REQUIRED ⭐

**Zweck:** Config-Optionen definieren

**Pattern:**
```nix
{ lib, getCurrentModuleMetadata, ... }:

let
  metadata = getCurrentModuleMetadata ./.;
  configPath = metadata.configPath or "systemConfig.modules.specialized.migration-service";
  moduleVersion = "0.1.0";
in
{
  options.${configPath} = {
    # Version metadata (REQUIRED)
    _version = lib.mkOption {
      type = lib.types.str;
      default = moduleVersion;
      internal = true;
      description = "Module version";
    };

    # Enable option (REQUIRED for optional modules)
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Windows/macOS → NixOS Migration Service";
    };

    # Web-Service configuration
    webService = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable web service for migration";
      };
      
      port = lib.mkOption {
        type = lib.types.port;
        default = 8080;
        description = "Web service port";
      };
      
      host = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "Web service host (0.0.0.0 for all interfaces)";
      };
    };

    # Snapshot configuration
    snapshot = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable snapshot scripts";
      };
    };
  };
}
```

### 3. `config.nix` - REQUIRED wenn enabled ⭐

**Zweck:** System-Integration (systemd, packages, etc.)

**Pattern:**
```nix
{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:

let
  moduleName = baseNameOf ./.;
  cfg = getModuleConfig moduleName;
  moduleManager = getModuleApi "module-manager";
  systemManager = getModuleApi "system-manager";
in
lib.mkIf (cfg.enable or false) {
  # Web-Service als systemd-Service
  systemd.services.migration-web-service = lib.mkIf cfg.webService.enable {
    enable = true;
    serviceConfig = {
      ExecStart = "${webService}/bin/migration-web-service";
      Restart = "always";
    };
    environment = {
      PORT = toString cfg.webService.port;
      HOST = cfg.webService.host;
    };
  };
  
  # Snapshot-Scripts bereitstellen
  environment.systemPackages = lib.mkIf cfg.snapshot.enable [
    snapshotScripts.windows
    snapshotScripts.macos
  ];
}
```

### 4. `commands.nix` - OPTIONAL aber empfohlen ⭐

**Zweck:** CLI-Commands registrieren

**Pattern:**
```nix
{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:

with lib;

let
  moduleName = baseNameOf ./.;
  cfg = getModuleConfig moduleName;
  cliRegistry = getModuleApi "cli-registry";
  
  # Migration Service Manager Script
  migrationServiceScript = pkgs.writeScriptBin "ncc-migration-service" ''
    #!/usr/bin/env bash
    # Migration Service Manager
    echo "Migration Service - Windows/macOS → NixOS"
  '';
in
lib.mkMerge [
  (cliRegistry.registerCommandsFor "migration-service" [
    {
      name = "migration-service";
      scope = "module";
      type = "manager";
      description = "Windows/macOS → NixOS Migration Service";
      script = "${migrationServiceScript}/bin/ncc-migration-service";
      category = "specialized";
      shortHelp = "migration-service - Migrate from Windows/macOS to NixOS";
      longHelp = ''
        Migration Service helps users migrate from Windows/macOS to NixOS.
        
        Usage:
          ncc migration-service snapshot    # Generate system snapshot
          ncc migration-service status      # Check service status
      '';
    }
  ])
]
```

---

## Vollständige Ziel-Struktur

```
nixos/modules/specialized/migration-service/
├── README.md                    ✅ Vorhanden
├── default.nix                 ❌ FEHLT - Erstellen
├── options.nix                 ❌ FEHLT - Erstellen
├── config.nix                  ❌ FEHLT - Erstellen
├── commands.nix                ❌ FEHLT - Erstellen
├── CHANGELOG.md                ⏳ EMPFOHLEN - Erstellen
│
├── doc/                        ✅ Vorhanden
│   ├── DOCUMENTATION_CHECKLIST.md
│   ├── MODULE_STRUCTURE_ANALYSIS.md  ← Diese Datei
│   ├── migration-service-architecture.md
│   ├── migration-service-structure.md
│   └── migration-service-workflow.md
│
├── snapshot/                   ❌ FEHLT - Erstellen
│   ├── windows/
│   │   └── migration-snapshot.ps1
│   └── macos/
│       └── migration-snapshot.sh
│
├── mapping/                    ❌ FEHLT - Erstellen
│   ├── mapping-database.json
│   └── mapper.nix
│
├── web-service/                ❌ FEHLT - Erstellen
│   ├── api/
│   │   └── main.go
│   ├── config-generator/
│   │   └── generator.nix
│   └── handlers/
│       └── snapshot-handler.go
│
├── iso-builder/                ❌ FEHLT - Erstellen
│   └── iso-builder.nix
│
└── lib/                        ⏳ OPTIONAL - Später
    └── default.nix
```

---

## Implementierungs-Checkliste

### Phase 1: Core-Modul-Dateien (REQUIRED)

- [ ] **default.nix** erstellen
  - [ ] Metadata definieren
  - [ ] Imports strukturieren
  - [ ] Enable-Check implementieren

- [ ] **options.nix** erstellen
  - [ ] Version-Option
  - [ ] Enable-Option
  - [ ] Web-Service-Optionen
  - [ ] Snapshot-Optionen

- [ ] **config.nix** erstellen
  - [ ] Systemd-Service für Web-Service
  - [ ] Snapshot-Scripts als Packages
  - [ ] Integration mit bestehenden Modulen

- [ ] **commands.nix** erstellen
  - [ ] Migration-Service-Manager-Command
  - [ ] Snapshot-Subcommand
  - [ ] CLI-Registry-Integration

### Phase 2: Dokumentation

- [x] README.md
- [x] doc/MIGRATION_SERVICE_ARCHITECTURE.md
- [x] doc/MIGRATION_SERVICE_STRUCTURE.md
- [x] doc/MIGRATION_SERVICE_WORKFLOW.md
- [ ] CHANGELOG.md (empfohlen)

### Phase 3: Komponenten (später)

- [ ] snapshot/ - Snapshot-Scripts
- [ ] mapping/ - Programm-Mapping
- [ ] web-service/ - Web-Service
- [ ] iso-builder/ - ISO-Builder

---

## Vergleich mit anderen Modulen

### Chronicle (Referenz)

```
chronicle/
├── default.nix                 ✅
├── options.nix                 ✅
├── config.nix                  ✅
├── commands.nix                ✅
├── systemd.nix                 ✅
├── CHANGELOG.md                ✅
├── README.md                   ✅
└── (viele Submodule)
```

### AI-Workspace (Referenz)

```
ai-workspace/
├── default.nix                 ✅
├── options.nix                 ✅
└── (Submodule-Struktur)
```

### Hackathon (Referenz)

```
hackathon/
├── default.nix                 ✅
├── options.nix                 ✅
└── (Scripts)
```

### Migration-Service (aktuell)

```
migration-service/
├── README.md                   ✅
└── doc/                        ✅
    └── (Dokumentation)
```

**→ Fehlen: default.nix, options.nix, config.nix, commands.nix**

---

## Nächste Schritte

1. **Core-Dateien erstellen** (default.nix, options.nix, config.nix, commands.nix)
2. **CHANGELOG.md** erstellen (empfohlen)
3. **Struktur validieren** gegen MODULE_TEMPLATE
4. **Test-Import** durchführen
5. **Dokumentation aktualisieren**

---

## Zusammenfassung

### ✅ Dokumentation: Vollständig
- README.md ✅
- Architektur-Dokumentation ✅
- Workflow-Dokumentation ✅
- Struktur-Dokumentation ✅

### ❌ Modul-Dateien: Fehlen
- default.nix ❌
- options.nix ❌
- config.nix ❌
- commands.nix ❌

### ⏳ Komponenten: Später
- snapshot/ ⏳
- mapping/ ⏳
- web-service/ ⏳
- iso-builder/ ⏳

**Status: Dokumentation komplett, Modul-Struktur muss noch erstellt werden!**
