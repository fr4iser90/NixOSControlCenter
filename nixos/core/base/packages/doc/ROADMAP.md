# Package System Roadmap

## 🎯 Ziel

Migration von Legacy `packageModules` (alles systemweit) zu modernem System mit automatischer system/user Trennung basierend auf Smart Defaults.

---

## 📋 Phase 1: V2 - Smart Mapping (Aktuell)

### Entscheidungen

**✅ Keine UI/Installer-Fragen**
- Installer bleibt smooth (wie aktuell)
- User wählt nur Features: `setup desktop gaming web-dev`
- Keine zusätzlichen Fragen nach system/user

**✅ Smart Mapping im Modul**
- Package Module Sets definieren `system`/`user` Packages
- Automatische Zuordnung basierend auf Scope-Philosophie
- Keine User-Interaktion nötig

**✅ Optional später anpassbar**
- Später Move-Command möglich: `ncc package move vesktop --to-system`
- Nicht jetzt implementieren
- Erst wenn Bedarf entsteht

### Implementierungsschritte

- [ ] **Package Module Sets erweitern**
  - [ ] `components/sets/gaming.nix` → `packages = { system = [...]; user = [...]; }`
  - [ ] `components/sets/web-dev.nix` → `packages = { system = [...]; user = [...]; }`
  - [ ] Alle 15 Module-Sets umstrukturieren
  - [ ] Legacy-Fallback: `environment.systemPackages` beibehalten

- [ ] **default.nix erweitern**
  - [ ] Package Module Sets automatisch extrahieren
  - [ ] System Packages aggregieren
  - [ ] User Packages aggregieren (für aktuellen User)
  - [ ] Legacy Support beibehalten (alles systemweit wenn nicht definiert)

- [ ] **Config-Struktur**
  - [ ] System Packages: `configs/core/base/packages/config.nix`
  - [ ] User Packages: `configs/users/{username}/packages.nix`
  - [ ] Installer erstellt modulare Configs automatisch

- [ ] **Setup-Scripts aktualisieren**
  - [ ] V2 API unterstützen
  - [ ] Legacy weiterhin unterstützen (mit Warning)
  - [ ] Keine zusätzlichen Fragen

### Scope-Philosophie

**Systemweit (system):**
- Performance-Tools (mangohud, goverlay)
- Infra/CLI Tools (docker, nginx, postgresql)
- System-Services
- Development-Tools (git, vim, etc.)

**User-spezifisch (user):**
- Desktop Apps (vesktop, discord, slack)
- Launcher (heroic, lutris)
- IDEs (vscode, idea)
- Persönliche Tools

**Default-Regel:**
- Wenn unsicher → `system` (Default Fallback)
- Desktop Apps → `user`
- Infra/CLI/System Tools → `system`

---

## 📋 Phase 2: V3 - Clean Removal (Zukunft)

### Vorbereitung

- [ ] **Deprecation Warnings**
  - [ ] `packageModules` zeigt Warning in V2
  - [ ] Dokumentation aktualisieren
  - [ ] Migration-Guide erstellen

- [ ] **Migration aller Configs**
  - [ ] Automatisch via Tool: `ncc package migrate-legacy`
  - [ ] Oder manuell migrieren
  - [ ] Alle Configs auf V2 umstellen

### Cleanup

- [ ] **Legacy-Code entfernen**
  - [ ] `packageModules` Option entfernen
  - [ ] Legacy-Logik aus `default.nix` entfernen
  - [ ] Package Module Sets aufräumen (Legacy-Fallback entfernen)
  - [ ] Setup-Scripts bereinigen

---

## 🏗️ Architektur-Entscheidungen

### Warum keine UI-Fragen?

**Problem mit UI-Fragen:**
- Unnötige kognitive Last
- Entscheidung ohne Kontext
- UX wird nerdig statt smooth
- Installer wird kompliziert

**Lösung: Smart Defaults**
- Automatisch basierend auf Package-Typ
- Optional später anpassbar
- Installer bleibt clean

### Warum Mapping im Modul?

**Vorteile:**
- Scope ist Teil der Modul-Definition
- Nicht Teil der User-Interaktion
- Sauberes Design
- Evolutionär erweiterbar

**Alternative (verworfen):**
- ❌ UI-Fragen im Installer
- ❌ Metadaten-Magie
- ❌ Komplexe CLI jetzt

---

## 📝 Beispiel-Implementierung

### Package Module Set (V2)

```nix
# components/sets/gaming.nix
{
  packages = {
    # Systemweit (Performance-Tools)
    system = with pkgs; [
      mangohud    # Performance-Overlay
      goverlay    # GUI-Tool
    ];
    
    # User-spezifisch (Apps/Launcher)
    user = with pkgs; [
      vesktop     # Discord-Client
      heroic      # Epic/GOG Launcher
      lutris      # Gaming Launcher
    ];
  };
  
  # Legacy-Support (alles systemweit)
  environment.systemPackages = with pkgs; [
    mangohud goverlay vesktop heroic lutris
  ];
}
```

### default.nix Verarbeitung

```nix
# default.nix
let
  # Package Module Sets laden
  moduleModules = map (mod: ./components/sets/${mod}.nix) allModules;
  
  # Automatisch extrahieren
  extractPackages = module: {
    system = module.packages.system or [];
    user = module.packages.user or [];
  };
  
  allExtracted = map extractPackages moduleModules;
  
  # System Packages (automatisch)
  systemFromModules = lib.concatLists (map (m: m.system) allExtracted);
  
  # User Packages (automatisch, für aktuellen User)
  currentUser = builtins.getEnv "USER" or "root";
  userFromModules = lib.concatLists (map (m: m.user) allExtracted);
  
in {
  environment.systemPackages = systemPkgs ++ systemFromModules;
  home-manager.users.${currentUser}.home.packages = 
    userPkgs.${currentUser} or [] ++ userFromModules;
}
```

---

## ✅ Checkliste

### Phase 1 (V2)
- [ ] Alle Package Module Sets umstrukturieren
- [ ] default.nix erweitern
- [ ] Config-Struktur implementieren
- [ ] Setup-Scripts aktualisieren
- [ ] Tests durchführen
- [ ] Dokumentation aktualisieren

### Phase 2 (V3)
- [ ] Deprecation Warnings
- [ ] Migration-Tool erstellen
- [ ] Alle Configs migrieren
- [ ] Legacy-Code entfernen
- [ ] Finale Tests
- [ ] Release Notes

---

## 🔗 Verwandte Dokumente

- [Analyse](./ANALYSE_PACKAGE_STORAGE.md) - Detaillierte Analyse des aktuellen Zustands
- [Architektur](./ARCHITECTURE.md) - System-Architektur
- [Usage](./USAGE.md) - Verwendungsbeispiele
```
