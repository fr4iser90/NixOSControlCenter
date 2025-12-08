# Analyse: System-Update Probleme - KORRIGIERT

**Datum**: 2025-12-07
**Status**: KRITISCH - system-update entfernt ALLES ohne Version-Prüfung

---

## HAUPTPROBLEM: system-update entfernt ALLES ohne Version-Prüfung

### Was passiert aktuell:

```bash
# system-update.nix Zeile 305-317:
sudo rm -rf "$NIXOS_DIR/core"      # ← LÖSCHT ALLES!
sudo cp -r "$SOURCE_DIR/core" "$NIXOS_DIR/"  # ← Kopiert neu
```

### Problem:
1. **KEINE Version-Prüfung**: `system-update` prüft NICHT ob Module versioniert sind
2. **Löscht ALLES**: `rm -rf` entfernt komplette Verzeichnisse
3. **Überschreibt ALLES**: `cp -r` kopiert alles neu, auch wenn keine Änderung
4. **User-Configs verloren**: Werden zwar gesichert, aber Restore schlägt fehl

---

## Was SOLLTE passieren:

### Regel 1: Versionierte Module
- **Nur migrieren wenn Version sich ändert** (Standard)
- **Migration forcieren möglich** (z.B. `--force-migration` Flag für Dev/Testing)
- **User-Configs NIEMALS überschreiben** (auch bei forcierter Migration)
- **Migration-Pläne verwenden** (wie Feature-Migration)
- **Wichtig**: Auch bei forcierter Migration bleiben User-Configs unberührt

### Regel 2: Nicht-versionierte Dateien
- **Nur hinzufügen wenn nicht vorhanden**
- **NICHT überschreiben wenn existiert**
- **User-Änderungen respektieren**

### Regel 3: User-Configs
- **NIEMALS überschreiben**
- **NIEMALS löschen**
- **Nur erstellen wenn nicht vorhanden**

---

## Aktueller Fehler-Ablauf:

```
1. system-update startet
   ↓
2. Findet user-configs/ Verzeichnisse
   ↓
3. Erstellt Backup in TMP_BACKUP
   ↓
4. LÖSCHT core/ komplett: rm -rf "$NIXOS_DIR/core"
   ↓
5. Kopiert core/ neu: cp -r "$SOURCE_DIR/core"
   ↓
6. Versucht Restore: "Restored 0 of 0" (Subshell-Problem)
   ↓
7. user-configs/ existieren NICHT mehr
   ↓
8. Build: createDefaultConfig erstellt Defaults (Englisch)
   ↓
9. User-Configs sind weg, Defaults überschreiben alles
```

---

## Was RICHTIG wäre:

```
1. system-update startet
   ↓
2. Für jedes Modul in core/:
   a) Prüfe ob options.nix existiert (SOURCE)
   b) Prüfe ob user-configs/ existiert (TARGET)
   c) **Fall 1: Modul hat Version (SOURCE hat options.nix)**
      - Prüfe Version in options.nix (SOURCE)
      - Prüfe Version in user-configs/*-config.nix (TARGET)
      - Wenn Version unterschiedlich ODER `--force-migration` gesetzt:
        → Führe Migration aus (wie Feature-Migration)
        → **Überschreibe user-configs/ NICHT** (auch bei forcierter Migration)
        → Migration aktualisiert nur Modul-Code, User-Configs bleiben unberührt
      - Wenn Version gleich UND keine forcierte Migration:
        → Überspringe Modul komplett (nur Code aktualisieren, user-configs/ unberührt)
   d) **Fall 2: Modul hat KEINE Version (Stufe 0 → Stufe 1 Migration)**
      - Modul existiert in TARGET, aber hat keine options.nix
      - **Einmaliger Übergang**: Monolithisch → Modular
      - Migriere von Stufe 0 → Stufe 1:
        → Lese alte `system-config.nix` (monolithisch)
        → Extrahiere Modul-Config (z.B. `desktop.*` → `desktop-config.nix`)
        → Erstelle `user-configs/MODULE-config.nix` aus system-config.nix
        → Erstelle `options.nix` mit Version 1.0
        → Kopiere Modul-Code
        → **Komplett ersetzen** (Übergang zur modularen Struktur)
        → User-Configs werden aus system-config.nix erstellt
   ↓
3. Für neue Module (nicht in TARGET):
   → Kopiere komplett (inkl. options.nix, user-configs/)
   → Erstelle Default nur wenn user-configs/ nicht existiert
   ↓
4. Für nicht-versionierte Dateien (außerhalb Module):
   → Kopiere nur wenn nicht vorhanden
   → Überschreibe NICHT
```

---

## Problem-Details:

### Problem 1: Keine Version-Prüfung
**Aktuell:**
- `system-update` prüft KEINE Versionen
- Löscht ALLES ohne zu prüfen
- Kopiert ALLES neu ohne zu prüfen

**Sollte sein:**
- Prüfe `_version` in `options.nix` (SOURCE)
- Prüfe `_version` in `user-configs/*-config.nix` (TARGET)
- Nur migrieren wenn Version unterschiedlich

### Problem 2: User-Configs werden gelöscht
**Aktuell:**
- `rm -rf "$NIXOS_DIR/core"` löscht ALLES
- Auch `user-configs/` werden gelöscht
- Backup wird erstellt, aber Restore schlägt fehl

**Sollte sein:**
- `user-configs/` NIEMALS löschen
- Nur Modul-Code aktualisieren
- User-Configs bleiben unberührt

### Problem 3: Restore schlägt fehl
**Aktuell:**
- `USER_CONFIGS_COUNT` wird in Subshell erhöht
- Variable ist außerhalb `0`
- Restore wird übersprungen

**Sollte sein:**
- Restore sollte gar nicht nötig sein
- `user-configs/` sollten nie gelöscht werden

---

## Lösung-Ansatz:

### 1. Version-basierte Updates + Stufe 0 → 1 Migration
```bash
# Für jedes Modul:
if [ -f "$SOURCE_DIR/core/MODULE/options.nix" ]; then
  # Modul hat Version (Stufe 1+)
  SOURCE_VERSION=$(grep 'moduleVersion =' "$SOURCE_DIR/core/MODULE/options.nix")
  
  if [ -f "$NIXOS_DIR/core/MODULE/user-configs/MODULE-config.nix" ]; then
    # TARGET hat user-configs/
    TARGET_VERSION=$(grep '_version' "$NIXOS_DIR/core/MODULE/user-configs/MODULE-config.nix")
    
    if [ "$SOURCE_VERSION" != "$TARGET_VERSION" ] || [ "$FORCE_MIGRATION" = "true" ]; then
      # Migration nötig (z.B. 1.0 → 2.0) ODER forciert
      migrate_module "$MODULE" "$SOURCE_VERSION" "$TARGET_VERSION"
      # WICHTIG: migrate_module überschreibt user-configs/ NICHT
      # Nur Modul-Code wird aktualisiert, User-Configs bleiben unberührt
    else
      # Keine Änderung, nur Code aktualisieren
      update_module_code "$MODULE"  # user-configs/ unberührt
    fi
  else
    # TARGET hat keine user-configs/ → erstelle aus Default
    create_user_configs "$MODULE"
  fi
else
  # Modul hat KEINE Version (Stufe 0)
  if [ -d "$NIXOS_DIR/core/MODULE" ]; then
    # Modul existiert in TARGET → Migriere Stufe 0 → 1
    # Einmaliger Übergang: Monolithisch → Modular
    migrate_stage0_to_stage1 "$MODULE" "$SYSTEM_CONFIG_FILE"
    # migrate_stage0_to_stage1:
    # 1. Liest system-config.nix (monolithisch)
    # 2. Extrahiert MODULE.* Config
    # 3. Erstellt user-configs/MODULE-config.nix
    # 4. Erstellt options.nix mit Version 1.0
    # 5. Kopiert Modul-Code
    # 6. Komplett ersetzt (Übergang zur modularen Struktur)
  else
    # Neues Modul ohne Version → kopiere komplett
    cp -r "$SOURCE_DIR/core/MODULE" "$NIXOS_DIR/core/"
  fi
fi
```

### 2. User-Configs schützen
```bash
# user-configs/ NIEMALS löschen
# Statt rm -rf core/:
# - Kopiere nur neue/geänderte Dateien
# - Überspringe user-configs/ komplett
# - Überschreibe existierende Dateien nur wenn Version sich ändert
```

### 3. Selektives Kopieren
```bash
# Statt: cp -r "$SOURCE_DIR/core" "$NIXOS_DIR/"
# Besser:
for module in "$SOURCE_DIR/core"/*; do
  if [ -d "$module/user-configs" ]; then
    # Modul hat user-configs/
    # Kopiere nur Code, nicht user-configs/
    rsync -av --exclude='user-configs' "$module" "$NIXOS_DIR/core/"
  else
    # Modul ohne user-configs/
    # Kopiere komplett
    cp -r "$module" "$NIXOS_DIR/core/"
  fi
done
```

---

## Kritische Erkenntnis:

**system-update sollte NICHT sein:**
- ❌ Komplettes Löschen und Neu-Kopieren
- ❌ Überschreiben ohne Version-Prüfung
- ❌ User-Configs löschen

**system-update sollte sein:**
- ✅ Version-basierte Migration (Stufe 1+ → höhere Version)
- ✅ **Migration forcieren möglich** (`--force-migration` Flag für Dev/Testing)
- ✅ **User-Configs NIEMALS anfassen** (auch bei forcierter Migration)
- ✅ Stufe 0 → Stufe 1 Migration (Module ohne Version migrieren)
- ✅ Selektives Kopieren (nur geänderte Dateien)
- ✅ Nur neue Module hinzufügen
- ✅ Nur bei Version-Änderung migrieren (oder wenn forciert)
- ✅ Module ohne Version NICHT löschen, sondern migrieren

---

## Zusammenfassung:

**Root Cause:**
- `system-update` ist zu aggressiv
- Löscht ALLES ohne Version-Prüfung
- Sollte nur versionierte Module migrieren
- Sollte User-Configs NIEMALS anfassen

**Fix-Strategie:**
1. Version-Prüfung implementieren (Stufe 1+)
2. **Migration forcieren implementieren** (`--force-migration` Flag):
   - Ermöglicht Migration auch ohne Version-Änderung
   - **User-Configs bleiben IMMER unberührt** (auch bei forcierter Migration)
   - Nützlich für Dev/Testing
3. **Stufe 0 → Stufe 1 Migration implementieren** (einmaliger Übergang):
   - Lese `system-config.nix` (monolithisch)
   - Extrahiere Module-Configs (desktop.*, hardware.*, etc.)
   - Erstelle `user-configs/*-config.nix` aus system-config.nix
   - Erstelle `options.nix` mit Version 1.0
   - **Komplett ersetzen** (Übergang zur modularen Struktur)
   - Kurzfristig für Dev: Übergangs-Phase
4. Selektives Kopieren statt komplettes Ersetzen (nur für Stufe 1+)
5. **User-Configs komplett schützen** (IMMER, auch bei forcierter Migration)
6. Migration nur bei Version-Änderung ODER wenn forciert (Stufe 1+)
7. Module ohne Version NICHT löschen, sondern auf Stufe 1 migrieren

---

## Wichtige Regel: User-Configs bleiben IMMER unberührt

**Kritische Regel für ALLE Migrationen:**
- ✅ **User-Configs NIEMALS überschreiben** (auch bei forcierter Migration)
- ✅ **User-Configs NIEMALS löschen**
- ✅ **Migration aktualisiert nur Modul-Code**, nicht User-Configs
- ✅ **Auch bei `--force-migration`**: User-Configs bleiben unberührt

**Migration forcieren (`--force-migration`):**
- Ermöglicht Migration auch ohne Version-Änderung
- Nützlich für Dev/Testing
- **ABER**: User-Configs bleiben trotzdem unberührt
- Nur Modul-Code wird aktualisiert

**Beispiel:**
```bash
sudo ncc system-update --force-migration
# → Migriert alle Module (auch wenn Version gleich)
# → User-Configs bleiben unberührt
# → Nur Modul-Code wird aktualisiert
```

---

**Erstellt**: 2025-12-07
**Status**: Korrigierte Analyse - system-update muss komplett umgebaut werden

