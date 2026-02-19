# Nixify - Modul-Struktur Analyse

## Vergleich mit MODULE_TEMPLATE

### ✅ Aktuell vorhanden

```
nixify/
├── README.md                    ✅ Vorhanden
├── CHANGELOG.md                 ✅ Vorhanden
└── doc/                        ✅ Vorhanden
    ├── DOCUMENTATION_CHECKLIST.md
    ├── NIXIFY_ARCHITECTURE.md
    ├── NIXIFY_WORKFLOW.md
    └── ARCHITECTURE_CLARIFICATION.md
```

### ❌ Fehlend (gemäß MODULE_TEMPLATE)

```
nixify/
├── default.nix                 ❌ FEHLT - Modul-Entry-Point (REQUIRED)
├── options.nix                 ❌ FEHLT - Config-Optionen (REQUIRED)
├── config.nix                  ❌ FEHLT - System-Integration (REQUIRED wenn enabled)
├── commands.nix                ❌ FEHLT - CLI-Commands (OPTIONAL aber empfohlen)
├── api.nix                     ⏳ OPTIONAL - API-Definition
├── CHANGELOG.md                ✅ Vorhanden
│
├── snapshot/                   ❌ FEHLT - Snapshot-Scripts
│   ├── windows/
│   │   └── nixify-scan.ps1
│   ├── macos/
│   │   └── nixify-scan.sh
│   └── linux/                  ❌ FEHLT - Linux-Script (NEU)
│       └── nixify-scan.sh
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
  moduleName = baseNameOf ./. ;  # "nixify"
  cfg = getModuleConfig moduleName;
  
  # Module metadata (REQUIRED)
  metadata = {
    role = "optional";              # "optional" | "core" | "required"
    name = "nixify";                # Unique module identifier
    description = "Windows/macOS/Linux → NixOS System-DNA-Extractor"; # Human-readable
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
    nixifyCfg = cfg;
  };

  # Module imports
  imports = [
    ./options.nix  # Always import options first
    (import ./commands.nix { inherit moduleName; })  # moduleName als Parameter übergeben
  ] ++ (if (cfg.enable or false) then [
    (import ./config.nix { inherit moduleName; })  # moduleName als Parameter übergeben
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
  configPath = metadata.configPath or "systemConfig.modules.specialized.nixify";
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
      description = "Enable Windows/macOS/Linux → NixOS System-DNA-Extractor";
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
  moduleName = moduleName;  # Als Parameter übergeben von default.nix - nur einmal berechnet!
  cfg = getModuleConfig moduleName;
  moduleManager = getModuleApi "module-manager";
  systemManager = getModuleApi "system-manager";
in
lib.mkIf (cfg.enable or false) {
  # Web-Service als systemd-Service
  systemd.services.nixify-service = lib.mkIf cfg.webService.enable {
    enable = true;
    serviceConfig = {
      ExecStart = "${webService}/bin/nixify-service";
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
    snapshotScripts.linux  # NEU
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
  moduleName = moduleName;  # Als Parameter übergeben von default.nix - nur einmal berechnet!
  cfg = getModuleConfig moduleName;
  cliRegistry = getModuleApi "cli-registry";
  
  # Nixify Service Manager Script
  nixifyServiceScript = pkgs.writeScriptBin "ncc-nixify" ''
    #!/usr/bin/env bash
    # Nixify Service Manager
    echo "Nixify - Windows/macOS/Linux → NixOS System-DNA-Extractor"
  '';
in
lib.mkMerge [
  (cliRegistry.registerCommandsFor "nixify" [
    {
      name = "nixify";
      scope = "module";
      type = "manager";
      description = "Windows/macOS/Linux → NixOS System-DNA-Extractor";
      script = "${nixifyServiceScript}/bin/ncc-nixify";
      category = "specialized";
      shortHelp = "nixify - Extract system DNA and generate NixOS configs";
      longHelp = ''
        Nixify helps users migrate from Windows/macOS/Linux to NixOS.
        
        Usage:
          ncc nixify service start    # Start web service
          ncc nixify service status    # Check service status
          ncc nixify list              # List sessions
      '';
    }
  ])
]
```

---

## Vollständige Ziel-Struktur

```
nixos/modules/specialized/nixify/
├── README.md                    ✅ Vorhanden
├── CHANGELOG.md                 ✅ Vorhanden
├── default.nix                 ❌ FEHLT - Erstellen
├── options.nix                 ❌ FEHLT - Erstellen
├── config.nix                  ❌ FEHLT - Erstellen
├── commands.nix                ❌ FEHLT - Erstellen
│
├── doc/                        ✅ Vorhanden
│   ├── DOCUMENTATION_CHECKLIST.md
│   ├── MODULE_STRUCTURE_ANALYSIS.md  ← Diese Datei
│   ├── NIXIFY_ARCHITECTURE.md
│   ├── NIXIFY_WORKFLOW.md
│   └── ARCHITECTURE_CLARIFICATION.md
│
├── snapshot/                   ❌ FEHLT - Erstellen
│   ├── windows/
│   │   └── nixify-scan.ps1
│   ├── macos/
│   │   └── nixify-scan.sh
│   └── linux/                  ❌ FEHLT - Erstellen (NEU)
│       └── nixify-scan.sh
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
- [x] CHANGELOG.md
- [x] doc/NIXIFY_ARCHITECTURE.md
- [x] doc/NIXIFY_WORKFLOW.md
- [x] doc/ARCHITECTURE_CLARIFICATION.md

### Phase 3: Komponenten (später)

- [ ] snapshot/ - Snapshot-Scripts (Windows/macOS/Linux)
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

### Nixify (aktuell)

```
nixify/
├── README.md                   ✅
├── CHANGELOG.md                ✅
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
