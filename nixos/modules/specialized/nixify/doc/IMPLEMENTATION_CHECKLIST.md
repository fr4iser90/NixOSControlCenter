# Nixify - Implementierungs-Checkliste

## Übersicht

Diese Checkliste führt durch die komplette Implementierung des Nixify-Moduls.

---

## Phase 1: Core-Modul-Dateien (REQUIRED) ⭐

### 1.1 default.nix

**Status:** ❌ Fehlt

**Aufgaben:**
- [ ] Module-Metadata definieren
  - [ ] role = "optional"
  - [ ] name = "nixify"
  - [ ] description = "Windows/macOS/Linux → NixOS System-DNA-Extractor"
  - [ ] category = "specialized"
  - [ ] subcategory = "migration"
  - [ ] stability = "experimental"
  - [ ] version = "0.1.0"
- [ ] Imports strukturieren
  - [ ] ./options.nix (immer zuerst)
  - [ ] ./config.nix (wenn enabled)
  - [ ] ./commands.nix (wenn enabled)
- [ ] Enable-Check implementieren
- [ ] _module.args definieren

**Referenz:** `nixos/modules/specialized/chronicle/default.nix`

### 1.2 options.nix

**Status:** ❌ Fehlt

**Aufgaben:**
- [ ] Version-Option (_version)
- [ ] Enable-Option (enable)
- [ ] Web-Service-Optionen
  - [ ] webService.enable
  - [ ] webService.port
  - [ ] webService.host
- [ ] Snapshot-Optionen
  - [ ] snapshot.enable

**Referenz:** `nixos/modules/specialized/chronicle/options.nix`

### 1.3 config.nix

**Status:** ❌ Fehlt

**Aufgaben:**
- [ ] Systemd-Service für Web-Service
  - [ ] Service-Definition
  - [ ] Environment-Variablen
  - [ ] Restart-Policy
- [ ] Snapshot-Scripts als Packages
  - [ ] Windows-Script
  - [ ] macOS-Script
  - [ ] Linux-Script (NEU)
- [ ] Integration mit bestehenden Modulen
  - [ ] getModuleApi "module-manager"
  - [ ] getModuleApi "system-manager"

**Referenz:** `nixos/modules/specialized/chronicle/config.nix`

### 1.4 commands.nix

**Status:** ❌ Fehlt

**Aufgaben:**
- [ ] Nixify-Service-Manager-Command
  - [ ] name = "nixify"
  - [ ] scope = "module"
  - [ ] type = "manager"
  - [ ] category = "specialized"
- [ ] CLI-Registry-Integration
  - [ ] cliRegistry.registerCommandsFor
- [ ] Script-Erstellung
  - [ ] pkgs.writeScriptBin

**Referenz:** `nixos/modules/specialized/chronicle/commands.nix`

---

## Phase 2: Dokumentation ✅

### 2.1 Core-Dokumentation

- [x] README.md
- [x] CHANGELOG.md
- [x] doc/NIXIFY_ARCHITECTURE.md
- [x] doc/NIXIFY_WORKFLOW.md
- [x] doc/ARCHITECTURE_CLARIFICATION.md
- [x] doc/DOCUMENTATION_CHECKLIST.md
- [x] doc/MODULE_STRUCTURE_ANALYSIS.md

### 2.2 Zukünftige Dokumentation

- [ ] API.md (wenn Web-Service implementiert)
- [ ] USER_GUIDE.md (für End-User)
- [ ] DEPLOYMENT.md (Deployment-Optionen)
- [ ] SECURITY.md (Security-Best-Practices)
- [ ] TROUBLESHOOTING.md (häufige Probleme)

---

## Phase 3: Snapshot-Scripts

### 3.1 Windows-Script

**Status:** ❌ Fehlt

**Aufgaben:**
- [ ] PowerShell-Script erstellen
- [ ] Programm-Erkennung
  - [ ] Windows Registry
  - [ ] Program Files
  - [ ] AppData
- [ ] System-Einstellungen erfassen
  - [ ] Timezone
  - [ ] Locale
  - [ ] Keyboard-Layout
- [ ] Hardware-Info
  - [ ] CPU
  - [ ] RAM
  - [ ] GPU
- [ ] JSON-Report generieren
- [ ] User-Review-Interface

**Datei:** `snapshot/windows/nixify-scan.ps1`

### 3.2 macOS-Script

**Status:** ❌ Fehlt

**Aufgaben:**
- [ ] Shell-Script erstellen
- [ ] Programm-Erkennung
  - [ ] Applications
  - [ ] Homebrew
  - [ ] Mac App Store
- [ ] System-Einstellungen erfassen
  - [ ] Timezone
  - [ ] Locale
- [ ] Hardware-Info
  - [ ] CPU
  - [ ] RAM
  - [ ] GPU
- [ ] JSON-Report generieren
- [ ] User-Review-Interface

**Datei:** `snapshot/macos/nixify-scan.sh`

### 3.3 Linux-Script ✅ **NEU**

**Status:** ❌ Fehlt

**Aufgaben:**
- [ ] Shell-Script erstellen
- [ ] Distro-Erkennung
  - [ ] /etc/os-release parsen
  - [ ] Distro-ID und Version
- [ ] Package Manager Detection
  - [ ] apt (Ubuntu/Debian)
  - [ ] dnf (Fedora/RHEL)
  - [ ] pacman (Arch)
  - [ ] zypper (openSUSE)
- [ ] Programm-Erkennung
  - [ ] Package Manager Packages
  - [ ] Flatpak
  - [ ] Snap
- [ ] System-Einstellungen erfassen
  - [ ] Timezone
  - [ ] Locale
  - [ ] Desktop Environment
- [ ] Hardware-Info
  - [ ] CPU
  - [ ] RAM
  - [ ] GPU
- [ ] JSON-Report generieren
- [ ] User-Review-Interface

**Datei:** `snapshot/linux/nixify-scan.sh`

**Unterstützte Distros:**
- Ubuntu/Debian (apt)
- Fedora/RHEL (dnf)
- Arch (pacman)
- openSUSE (zypper)
- NixOS (Replikation)

---

## Phase 4: Mapping-Database

### 4.1 Mapping-Database

**Status:** ❌ Fehlt

**Aufgaben:**
- [ ] JSON-Database erstellen
- [ ] Programm-zu-Package-Mapping
- [ ] Programm-zu-Modul-Mapping
- [ ] Desktop-Environment-Mapping
- [ ] Kategorisierung

**Datei:** `mapping/mapping-database.json`

### 4.2 Mapper-Logic

**Status:** ❌ Fehlt

**Aufgaben:**
- [ ] Nix-Mapper-Logic
- [ ] Programm-Lookup
- [ ] Mapping-Validation

**Datei:** `mapping/mapper.nix`

---

## Phase 5: Web-Service

### 5.1 REST API

**Status:** ❌ Fehlt

**Aufgaben:**
- [ ] Go REST API (empfohlen)
- [ ] Endpoints implementieren
  - [ ] GET /download/windows
  - [ ] GET /download/macos
  - [ ] GET /download/linux (NEU)
  - [ ] POST /api/v1/upload
  - [ ] GET /api/v1/config/{session}
  - [ ] POST /api/v1/config/{session}/review
  - [ ] GET /api/v1/config/{session}/download
  - [ ] POST /api/v1/iso/build
  - [ ] GET /api/v1/iso/{session}/download
- [ ] Session-Management
- [ ] Error-Handling

**Datei:** `web-service/api/main.go`

### 5.2 Config-Generator

**Status:** ❌ Fehlt

**Aufgaben:**
- [ ] Nix-Config-Generator
- [ ] Snapshot-Report parsen
- [ ] Programm-Mapping anwenden
- [ ] configs/*.nix Dateien generieren
- [ ] Config-Validierung

**Datei:** `web-service/config-generator/generator.nix`

### 5.3 Handlers

**Status:** ❌ Fehlt

**Aufgaben:**
- [ ] Snapshot-Handler
- [ ] Config-Generation-Handler
- [ ] ISO-Build-Handler

**Datei:** `web-service/handlers/snapshot-handler.go`

---

## Phase 6: ISO-Builder

### 6.1 ISO-Builder

**Status:** ❌ Fehlt

**Aufgaben:**
- [ ] NixOS ISO als Base
- [ ] configs/ Verzeichnis auf ISO einbetten
- [ ] Auto-Installer-Script
- [ ] ISO-Generierung
- [ ] Checksum-Generierung

**Datei:** `iso-builder/iso-builder.nix`

---

## Phase 7: Testing & Validation

### 7.1 Modul-Testing

**Aufgaben:**
- [ ] Modul-Import testen
- [ ] Options-Validierung
- [ ] Config-Validierung
- [ ] Systemd-Service testen
- [ ] CLI-Commands testen

### 7.2 Integration-Testing

**Aufgaben:**
- [ ] Snapshot-Script testen (Windows)
- [ ] Snapshot-Script testen (macOS)
- [ ] Snapshot-Script testen (Linux) (NEU)
- [ ] Web-Service testen
- [ ] Config-Generator testen
- [ ] ISO-Builder testen
- [ ] End-to-End-Test

---

## Phase 8: Deployment

### 8.1 Lokales Deployment

**Aufgaben:**
- [ ] Systemd-Service konfigurieren
- [ ] Port & Host konfigurieren
- [ ] Firewall-Regeln (falls nötig)

### 8.2 Remote-Deployment (Optional)

**Aufgaben:**
- [ ] Docker-Container
- [ ] Cloud-Deployment
- [ ] Reverse-Proxy-Konfiguration

---

## Prioritäten

### P0 (Kritisch - für Modul-Funktionalität)
1. ✅ Dokumentation
2. ❌ default.nix
3. ❌ options.nix
4. ❌ config.nix
5. ❌ commands.nix

### P1 (Wichtig - für Basis-Funktionalität)
6. ❌ Snapshot-Scripts (Windows/macOS/Linux)
7. ❌ Mapping-Database
8. ❌ Web-Service (Basis)

### P2 (Wünschenswert - für vollständige Funktionalität)
9. ❌ Config-Generator
10. ❌ ISO-Builder

### P3 (Optional - für erweiterte Features)
11. ⏳ API-Dokumentation
12. ⏳ User-Guide
13. ⏳ Deployment-Guide

---

## Aktueller Status

### ✅ Abgeschlossen
- Dokumentation komplett
- Architektur definiert
- Workflow dokumentiert
- Struktur analysiert

### ❌ In Arbeit
- Core-Modul-Dateien (default.nix, options.nix, config.nix, commands.nix)

### ⏳ Geplant
- Snapshot-Scripts (Windows/macOS/Linux)
- Mapping-Database
- Web-Service
- ISO-Builder

---

## Nächste Schritte

1. **default.nix erstellen** (P0)
2. **options.nix erstellen** (P0)
3. **config.nix erstellen** (P0)
4. **commands.nix erstellen** (P0)
5. **Modul-Import testen** (P0)
6. **Snapshot-Scripts implementieren** (P1)
7. **Mapping-Database aufbauen** (P1)
8. **Web-Service entwickeln** (P1)

---

**Status: Dokumentation ✅ | Modul-Struktur ❌ | Komponenten ⏳**
