# Feature Versioning & Migration TODO

## 🎯 Goal
Migrate all features from unversioned to versioned state, enabling smart updates via System Updater.

## 📋 Phase 1: Basis-Versionierung (Alle Features auf v1.0)

**Status**: ⏳ Not Started  
**Zeitaufwand**: ~2-3 Stunden  
**Priorität**: 🔴 HIGHEST

### Schritt 1.1: Feature-Liste erstellen
- [ ] Liste aller Features erstellen (12 Features):
  - [ ] ai-workspace
  - [ ] bootentry-manager
  - [ ] hackathon-manager
  - [ ] homelab-manager
  - [ ] ssh-client-manager
  - [ ] ssh-server-manager
  - [ ] system-checks
  - [ ] system-config-manager
  - [ ] system-discovery
  - [ ] system-logger
  - [ ] system-updater
  - [ ] vm-manager

### Schritt 1.2: Für jedes Feature - Versionierung hinzufügen

Für **jedes Feature** (in `options.nix` oder `default.nix`):

- [ ] **ai-workspace**
  - [ ] `featureVersion = "1.0"` definieren
  - [ ] `_version` Option hinzufügen (optional, internal)
  - [ ] Test: Feature funktioniert noch

- [ ] **bootentry-manager**
  - [ ] `featureVersion = "1.0"` definieren
  - [ ] `_version` Option hinzufügen
  - [ ] Test: Feature funktioniert noch

- [ ] **hackathon-manager**
  - [ ] `featureVersion = "1.0"` definieren
  - [ ] `_version` Option hinzufügen
  - [ ] Test: Feature funktioniert noch

- [ ] **homelab-manager**
  - [ ] `featureVersion = "1.0"` definieren
  - [ ] `_version` Option hinzufügen
  - [ ] Test: Feature funktioniert noch

- [ ] **ssh-client-manager**
  - [ ] `featureVersion = "1.0"` definieren
  - [ ] `_version` Option hinzufügen
  - [ ] Test: Feature funktioniert noch

- [ ] **ssh-server-manager**
  - [ ] `featureVersion = "1.0"` definieren
  - [ ] `_version` Option hinzufügen
  - [ ] Test: Feature funktioniert noch

- [ ] **system-checks**
  - [ ] `featureVersion = "1.0"` definieren
  - [ ] `_version` Option hinzufügen
  - [ ] Test: Feature funktioniert noch

- [ ] **system-config-manager**
  - [ ] `featureVersion = "1.0"` definieren
  - [ ] `_version` Option hinzufügen
  - [ ] Test: Feature funktioniert noch

- [ ] **system-discovery**
  - [ ] `featureVersion = "1.0"` definieren
  - [ ] `_version` Option hinzufügen
  - [ ] Test: Feature funktioniert noch

- [ ] **system-logger**
  - [ ] `featureVersion = "1.0"` definieren
  - [ ] `_version` Option hinzufügen
  - [ ] Test: Feature funktioniert noch

- [ ] **system-updater**
  - [ ] `featureVersion = "1.0"` definieren
  - [ ] `_version` Option hinzufügen
  - [ ] Test: Feature funktioniert noch

- [ ] **vm-manager**
  - [ ] `featureVersion = "1.0"` definieren
  - [ ] `_version` Option hinzufügen
  - [ ] Test: Feature funktioniert noch

### Schritt 1.3: Template Pattern für Versionierung

**Pattern für `options.nix`** (oder in `default.nix` wenn kein `options.nix` existiert):

```nix
# options.nix
{ lib, ... }:

let
  featureVersion = "1.0";  # Current feature version
in {
  options.features.feature-name = {
    # Version metadata (optional but recommended)
    _version = lib.mkOption {
      type = lib.types.str;
      default = featureVersion;
      internal = true;  # Hidden from users
      description = "Feature version";
    };
    
    # ... rest of options
  };
}
```

**Oder wenn kein `options.nix` existiert, in `default.nix`:**

```nix
# default.nix
let
  featureVersion = "1.0";
  cfg = config.features.feature-name;
in {
  options.features.feature-name = {
    _version = lib.mkOption {
      type = lib.types.str;
      default = featureVersion;
      internal = true;
      description = "Feature version";
    };
    # ... other options
  };
}
```

### Schritt 1.4: Validierung
- [ ] Alle Features haben `featureVersion = "1.0"`
- [ ] Alle Features haben `_version` Option (optional)
- [ ] `nixos-rebuild dry-run` funktioniert für alle Features
- [ ] Keine Breaking Changes (alles sollte noch funktionieren)

---

## 📋 Phase 2: System Updater - Version Checker

**Status**: ⏳ Not Started  
**Zeitaufwand**: ~2-3 Stunden  
**Priorität**: 🔴 HIGH

### Schritt 2.1: Feature Version Collector erstellen

- [ ] Neue Datei: `system-updater/feature-version-check.nix`
- [ ] Funktion: Sammelt alle Feature-Versionen
  ```nix
  # Sammelt: { "system-discovery" = "1.0"; "ssh-client-manager" = "1.0"; ... }
  ```
- [ ] Funktion: Liest `_version` aus jedem Feature
- [ ] Fallback: "unknown" wenn keine Version vorhanden

### Schritt 2.2: Version Registry (für verfügbare Versionen)

- [ ] Entscheiden: Wo werden verfügbare Versionen gespeichert?
  - Option A: Git Tags (`v1.0`, `v2.0`, etc.)
  - Option B: Metadata-Datei (`features/metadata.nix` erweitern)
  - Option C: Feature-spezifische Version-Dateien
- [ ] Implementierung: Version-Registry erstellen/erweitern
- [ ] Funktion: `getLatestVersion featureName` → gibt neueste Version zurück

### Schritt 2.3: Version Comparison Logic

- [ ] Funktion: `compareVersions v1 v2` → `-1`, `0`, `1`
- [ ] Funktion: `needsUpdate currentVersion latestVersion` → `bool`
- [ ] Funktion: `getUpdateStrategy featureName` → `"auto" | "manual" | "current" | "unknown"`

### Schritt 2.4: Command: `ncc check-feature-versions`

- [ ] Script erstellen: `system-updater/scripts/check-versions.nix`
- [ ] Command registrieren in `system-updater/commands.nix`
- [ ] Output: Tabelle mit allen Features
  ```
  Feature              Current    Latest     Status
  system-discovery     1.0        1.0        current
  ssh-client-manager   1.0        2.0        update available (migration: yes)
  ```
- [ ] Integration in `system-updater/default.nix`

---

## 📋 Phase 3: System Updater - Smart Update Logic

**Status**: ⏳ Not Started  
**Zeitaufwand**: ~3-4 Stunden  
**Priorität**: 🟡 MEDIUM

### Schritt 3.1: Migration Detection

- [ ] Funktion: `hasMigration featureName fromVersion toVersion` → `bool`
- [ ] Check: Existiert `migrations/v${fromVersion}-to-v${toVersion}.nix`?
- [ ] Chain-Migration Support: Findet Migration-Chain (v1.0 → v1.1 → v2.0)

### Schritt 3.2: Update Strategy Logic

- [ ] Funktion: `determineUpdateStrategy featureName`:
  - `"unknown"` → Feature ist unversioniert
  - `"current"` → Bereits auf neuester Version
  - `"auto"` → Migration verfügbar, kann auto-update
  - `"manual"` → Update verfügbar, aber keine Migration
- [ ] Integration in Version Checker

### Schritt 3.3: Smart Update Command

- [ ] Script: `system-updater/scripts/smart-update.nix`
- [ ] Command: `ncc update-features [--feature=name] [--dry-run]`
- [ ] Logic:
  1. Check alle Features
  2. Zeige Update-Status
  3. Frage User (wenn nicht `--auto`)
  4. Update Features mit `"auto"` Strategy
  5. Warnung für Features mit `"manual"` Strategy
- [ ] Integration in `system-updater/default.nix`

### Schritt 3.4: Feature Migration Execution

- [ ] Funktion: `executeFeatureMigration featureName fromVersion toVersion`
- [ ] Load Migration Plan aus `migrations/vX-to-vY.nix`
- [ ] Apply Migration:
  - Option Renamings
  - Type Conversions
  - Structure Mappings
- [ ] Update `_version` in User Config
- [ ] Backup vor Migration
- [ ] Validation nach Migration

---

## 📋 Phase 4: Testing & Validation

**Status**: ⏳ Not Started  
**Zeitaufwand**: ~1-2 Stunden  
**Priorität**: 🟡 MEDIUM

### Schritt 4.1: Unit Tests

- [ ] Test: Version Comparison
- [ ] Test: Migration Detection
- [ ] Test: Update Strategy Logic
- [ ] Test: Feature Version Collection

### Schritt 4.2: Integration Tests

- [ ] Test: `ncc check-feature-versions` mit allen Features
- [ ] Test: `ncc update-features --dry-run`
- [ ] Test: Migration Execution (mit Test-Feature)

### Schritt 4.3: Documentation

- [ ] README Update: System Updater erweitern
- [ ] Dokumentation: Wie funktioniert Feature-Versionierung
- [ ] Beispiele: Wie man Features versioniert
- [ ] Migration Guide: Wie man Migrationen erstellt

---

## 📋 Phase 5: Erste Migration (Optional - später)

**Status**: ⏳ Not Started  
**Zeitaufwand**: Variabel  
**Priorität**: 🟢 LOW (nur wenn Breaking Changes kommen)

### Schritt 5.1: Wenn Breaking Change kommt

- [ ] Feature identifizieren das Breaking Change hat
- [ ] Version erhöhen (z.B. v1.0 → v2.0)
- [ ] Migration Plan erstellen: `migrations/v1.0-to-v2.0.nix`
- [ ] Migration testen
- [ ] Dokumentation aktualisieren

---

## 🎯 Quick Start (Erste Schritte)

### Sofort starten:

1. **Wähle ein einfaches Feature** (z.B. `system-checks` oder `system-config-manager`)
2. **Füge Versionierung hinzu**:
   ```nix
   # In options.nix oder default.nix
   let
     featureVersion = "1.0";
   in {
     options.features.system-checks = {
       _version = lib.mkOption {
         type = lib.types.str;
         default = featureVersion;
         internal = true;
       };
       # ... rest
     };
   }
   ```
3. **Test**: `nixos-rebuild dry-run`
4. **Wiederhole für alle Features**

### Nach Phase 1:

- System Updater kann jetzt Versionen checken
- Alle Features sind versioniert
- Bereit für Smart Updates

---

## 📝 Notes

- **Keine Migrationen nötig** für v1.0 (alles startet bei v1.0)
- **Migrationen kommen später** wenn Breaking Changes auftreten
- **System Updater** wird schrittweise erweitert
- **Backward Compatible**: Alte Configs funktionieren weiterhin

---

## ✅ Definition of Done

Phase 1 ist fertig wenn:
- [ ] Alle 12 Features haben `featureVersion = "1.0"`
- [ ] Alle Features haben `_version` Option
- [ ] `nixos-rebuild dry-run` funktioniert
- [ ] Keine Breaking Changes

Phase 2 ist fertig wenn:
- [ ] `ncc check-feature-versions` funktioniert
- [ ] Zeigt alle Feature-Versionen korrekt an
- [ ] Version Registry funktioniert

Phase 3 ist fertig wenn:
- [ ] `ncc update-features` funktioniert
- [ ] Smart Update Logic funktioniert
- [ ] Migration Detection funktioniert

---

**Letzte Aktualisierung**: 2024-01-XX  
**Nächster Schritt**: Phase 1.1 - Feature-Liste erstellen

