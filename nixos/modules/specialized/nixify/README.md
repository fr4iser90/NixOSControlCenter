# Nixify - System-DNA-Extractor → NixOS-Config-Generator

**Nixify** extrahiert System-State von Windows/macOS/Linux und generiert daraus deklarative NixOS-Configs.

> **Wichtig:** Das Modul läuft auf NixOS. Die Snapshot-Scripts laufen auf den Ziel-Systemen (Windows/macOS/Linux).

## Struktur

```
nixify/
├── README.md
├── CHANGELOG.md
├── default.nix                    # Modul-Entry (FEHLT)
├── options.nix                     # Config-Optionen (FEHLT)
├── config.nix                      # System-Integration (FEHLT)
├── commands.nix                    # CLI-Commands (FEHLT)
│
├── snapshot/                       # Snapshot-Scripts
│   ├── windows/
│   │   └── nixify-scan.ps1
│   ├── macos/
│   │   └── nixify-scan.sh
│   └── linux/                      # NEU
│       └── nixify-scan.sh
│
├── mapping/                        # Programm-Mapping
│   ├── mapping-database.json
│   └── mapper.nix
│
├── web-service/                     # Web-Service
│   ├── api/
│   │   └── main.go
│   ├── config-generator/
│   │   └── generator.nix
│   └── handlers/
│       └── snapshot-handler.go
│
├── iso-builder/                    # ISO-Builder
│   └── iso-builder.nix
│
└── doc/                            # Dokumentation
    ├── NIXIFY_ARCHITECTURE.md
    ├── NIXIFY_WORKFLOW.md
    ├── ARCHITECTURE_CLARIFICATION.md
    └── ...
```

## Quick Start

### Auf NixOS-System (Service starten)

```bash
# Modul aktivieren in Config:
systemConfig.modules.specialized.nixify = {
  enable = true;
  webService = {
    enable = true;
    port = 8080;
    host = "0.0.0.0";
  };
};

# Rebuild & Service starten
sudo nixos-rebuild switch
ncc nixify service start
```

### Auf Ziel-System (Windows/macOS/Linux)

**Windows:**
1. Script herunterladen: `curl http://nixos-ip:8080/download/windows -o nixify-scan.ps1`
2. Ausführen: `powershell -ExecutionPolicy Bypass -File nixify-scan.ps1`
3. Report wird automatisch hochgeladen

**macOS:**
1. Script herunterladen: `curl http://nixos-ip:8080/download/macos -o nixify-scan.sh`
2. Ausführen: `chmod +x nixify-scan.sh && ./nixify-scan.sh`
3. Report wird automatisch hochgeladen

**Linux:**
1. Script herunterladen: `curl http://nixos-ip:8080/download/linux -o nixify-scan.sh`
2. Ausführen: `chmod +x nixify-scan.sh && ./nixify-scan.sh`
3. Report wird automatisch hochgeladen

**Unterstützte Linux-Distros:**
- Ubuntu/Debian (apt)
- Fedora/RHEL (dnf)
- Arch (pacman)
- openSUSE (zypper)
- NixOS (Replikation)

**Wichtig:** Kein `ncc` auf Ziel-Systemen nötig! Nur standalone Scripts.

## Development

### Dokumentation

**Essential:**
- **Architektur:** `doc/NIXIFY_ARCHITECTURE.md` - Komplette Architektur-Übersicht (konsolidiert)
- **Workflow:** `doc/NIXIFY_WORKFLOW.md` - Detaillierter Workflow
- **System-Trennung:** `doc/ARCHITECTURE_CLARIFICATION.md` - ⚠️ Wichtig! System-Trennung erklärt

**Development:**
- **Struktur-Analyse:** `doc/MODULE_STRUCTURE_ANALYSIS.md` - Vergleich mit MODULE_TEMPLATE
- **Implementierung:** `doc/IMPLEMENTATION_CHECKLIST.md` - Implementierungs-Checkliste

**Optional:**
- **Dokumentation:** `doc/DOCUMENTATION_CHECKLIST.md` - Dokumentations-Status
- **Zusammenfassung:** `doc/SUMMARY.md` - Dokumentations-Übersicht
- **Naming:** `doc/NAMING_ANALYSIS.md` - Warum "nixify"?

### Commands (auf NixOS)

```bash
ncc nixify service start    # Web-Service starten
ncc nixify service status   # Service-Status
ncc nixify service stop     # Service stoppen
ncc nixify list             # Alle Sessions auflisten
ncc nixify show <session>   # Session-Details
ncc nixify download <id>    # Config/ISO herunterladen
```

### Status

- **Phase:** Planning & Documentation ✅
- **Next:** Core module files (default.nix, options.nix, config.nix, commands.nix)
- **Stability:** Experimental (pre-implementation)

### Architektur

Siehe `doc/ARCHITECTURE_CLARIFICATION.md` für detaillierte Erklärung der System-Trennung.

Siehe `CHANGELOG.md` für Versions-Historie.
