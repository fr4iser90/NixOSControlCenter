# Changelog

All notable changes to the Migration Service module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased] - WIP

### Current Status (2026-02-26)

#### ✅ Working
- **ISO Builder**: ISO wird erfolgreich gebaut und unter `~/.local/share/nixify/isos/` gespeichert
- **ISO Naming**: ISO wird korrekt benannt als `nixos-nixify-{desktopEnv}-{version}-{system}.iso`
- **Module Build**: Calamares Module werden korrekt im Nix Store gebaut
- **Module Store**: Module sind im Store vorhanden und können gefunden werden
- **Repository Copy**: NixOS Control Center Repository wird auf ISO kopiert
- **Build Scripts**: `ncc nixify build-iso` funktioniert korrekt
- **modules.conf Creation**: ✅ FIXED - wird jetzt mit Debug-Output und Fehlerbehandlung erstellt
- **modules-search Config**: ✅ FIXED - 'modules' wird zu modules-search hinzugefügt
- **Module Symlinks**: ✅ FIXED - Symlinks in /usr/lib/calamares/modules/ werden erstellt

#### 🔄 Recent Fixes (2026-02-26 11:18)
1. **Enhanced Debug Output**: `postInstall` in overlay zeigt jetzt detaillierte Build-Informationen
2. **Error Handling**: Build schlägt fehl wenn modules.conf oder settings.conf nicht erstellt werden
3. **modules-search**: settings.conf enthält jetzt 'modules' in modules-search Liste
4. **Module Symlinks**: systemd.tmpfiles.rules erstellt Symlinks in /usr/lib/calamares/modules/
5. **Build Verification**: Automatische Validierung der erstellten Dateien während des Builds

#### ⚠️ Testing Required
1. **ISO Build Test**: ISO neu bauen und Debug-Output prüfen
   - Erwartung: Debug-Ausgaben zeigen erfolgreiche modules.conf Erstellung
   - Command: `ncc nixify build-iso plasma6`
   
2. **Live-System Test**: ISO in VM booten und Dateien prüfen
   - `/etc/calamares/modules.conf` muss existieren
   - `/usr/lib/calamares/modules/nixos-control-center/` muss Symlink sein
   - `calamares-nixos-extensions` muss modules.conf enthalten
   
3. **Calamares Module Loading**: Calamares starten und Module testen
   - Calamares muss Custom-Module in UI anzeigen
   - nixos-control-center Modul muss vor Summary erscheinen

#### 📋 Known Issues (Minor)
1. **Result Symlink**: `validate-and-build.sh` erstellte `result` Symlink im nixify-Ordner
   - Fixed: `--no-out-link` Flag hinzugefügt (2026-02-26)

### Next Steps
1. ✅ **DONE**: Fix modules.conf - wird im Live-System unter `/etc/calamares/modules.conf` verfügbar sein
2. ✅ **DONE**: Create Module Symlinks - Symlinks von `/usr/lib/calamares/modules/` zu Store-Pfaden
3. 🔄 **IN PROGRESS**: Test Module Loading - Calamares Module-Loading auf Live-ISO testen
4. ⏳ **TODO**: Document Solution - Lösung in problems.md dokumentieren

### Work in Progress
- **ISO Builder**: ~90% complete (Module-Loading fehlt)
- **Calamares Integration**: ~70% complete (Module-Loading fehlt)
- **Web Service**: Not started
- **Config Generator**: Not started
- **Snapshot Scripts**: Basic structure exists, needs testing

### Planned
- Snapshot-Script für Windows (basic structure exists)
- Snapshot-Script für macOS (basic structure exists)
- Programm-zu-Modul-Mapping-Database
- Web-Service (REST API)
- Config-Generator
- Automatische Installation

---

## [0.1.0] - 2025-01-XX

### Added
- Initial module structure
- Complete architecture documentation
- Workflow documentation
- Module structure analysis

### Documentation
- README.md - Quick Start Guide
- doc/MIGRATION_SERVICE_architecture.md - Complete architecture overview
- doc/MIGRATION_SERVICE_STRUCTURE.md - Repository structure decision
- doc/MIGRATION_SERVICE_WORKFLOW.md - Detailed workflow explanation
- doc/module-structure-analysis.md - Structure analysis vs MODULE_TEMPLATE
- doc/documentation-checklist.md - Documentation completeness checklist

### Status
- **Phase:** Planning & Documentation ✅
- **Next:** Core module files (default.nix, options.nix, config.nix, commands.nix)
- **Stability:** Experimental (pre-implementation)

---

## Version History

### 0.2.0 (WIP - Current)
- ISO Builder implementation started
- Calamares module integration in progress
- Module structure implemented
- Build scripts functional
- **Blocking**: Calamares module loading not working

### 0.1.0 (2025-01-XX)
- Planning phase complete
- Documentation complete
- Module structure defined
- Ready for implementation
