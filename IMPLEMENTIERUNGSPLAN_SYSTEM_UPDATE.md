# Implementierungsplan: system-update korrigieren

**Datum**: 2025-12-07
**Basis**: `ANALYSE_PROBLEME_KORRIGIERT.md`
**Status**: Plan - Noch nicht implementiert

---

## 🎯 Ziele

1. **Version-basierte Migration**: Nur migrieren wenn Version sich ändert
2. **Stufe 0 → 1 Migration**: Einmaliger Übergang Monolithisch → Modular
3. **User-Configs schützen**: NIEMALS überschreiben oder löschen
4. **Migration forcieren**: `--force-migration` Flag für Dev/Testing
5. **Selektives Kopieren**: Nur geänderte Dateien, nicht alles ersetzen

---

## 📋 Phase 1: Version-Prüfung implementieren

### 1.1 Helper-Funktionen erstellen

**Datei**: `nixos/core/system-manager/lib/version-helpers.nix`

```nix
{ pkgs, lib, ... }:

rec {
  # Prüfe ob Modul versioniert ist (hat options.nix)
  hasVersion = modulePath: builtins.pathExists "${modulePath}/options.nix";
  
  # Extrahiere Version aus options.nix
  getSourceVersion = modulePath:
    let
      optionsFile = "${modulePath}/options.nix";
    in
      if builtins.pathExists optionsFile then
        # Grep moduleVersion = "X.Y"
        # ...
      else
        "unknown";
  
  # Extrahiere Version aus user-configs/*-config.nix
  getTargetVersion = modulePath: configName:
    let
      configFile = "${modulePath}/user-configs/${configName}-config.nix";
    in
      if builtins.pathExists configFile then
        # Grep _version = "X.Y"
        # ...
      else
        "unknown";
  
  # Vergleiche Versionen
  compareVersions = v1: v2:
    # lib.versionOlder oder String-Vergleich
    # ...
}
```

### 1.2 Version-Prüfung in system-update integrieren

**Datei**: `nixos/core/system-manager/handlers/system-update.nix`

- Importiere `version-helpers.nix`
- Für jedes Modul: Prüfe Versionen
- Entscheide: Migration nötig? Skip? Force?

---

## 📋 Phase 2: Stufe 0 → 1 Migration implementieren

### 2.1 Migration-Handler erstellen

**Datei**: `nixos/core/system-manager/handlers/stage0-to-stage1-migration.nix`

```nix
{ pkgs, lib, formatter, ... }:

let
  # Migriere Modul von Stufe 0 → Stufe 1
  migrateModule = moduleName: systemConfigFile: ''
    # 1. Lese system-config.nix
    # 2. Extrahiere MODULE.* Config (z.B. desktop.*)
    # 3. Erstelle user-configs/MODULE-config.nix
    # 4. Erstelle options.nix mit Version 1.0
    # 5. Kopiere Modul-Code
    # 6. Komplett ersetzen
  '';
in {
  inherit migrateModule;
}
```

### 2.2 Integration in system-update

- Prüfe ob Modul `options.nix` hat (SOURCE)
- Wenn NEIN: Stufe 0 → 1 Migration ausführen
- Lese `system-config.nix` für Config-Extraktion

---

## 📋 Phase 3: Selektives Kopieren implementieren

### 3.1 Modul-Code aktualisieren (ohne user-configs/)

**Ersetze:**
```bash
sudo rm -rf "$NIXOS_DIR/core"
sudo cp -r "$SOURCE_DIR/core" "$NIXOS_DIR/"
```

**Durch:**
```bash
# Für jedes Modul einzeln:
for module in "$SOURCE_DIR/core"/*; do
  MODULE_NAME=$(basename "$module")
  TARGET_MODULE="$NIXOS_DIR/core/$MODULE_NAME"
  
  if [ -d "$module/user-configs" ]; then
    # Modul hat user-configs/ → Kopiere nur Code
    rsync -av --exclude='user-configs' "$module/" "$TARGET_MODULE/"
  else
    # Modul ohne user-configs/ → Kopiere komplett
    cp -r "$module" "$TARGET_MODULE"
  fi
done
```

### 3.2 Version-basierte Entscheidung

```bash
# Prüfe Versionen
SOURCE_VERSION=$(get_source_version "$module")
TARGET_VERSION=$(get_target_version "$TARGET_MODULE")

if [ "$SOURCE_VERSION" != "$TARGET_VERSION" ] || [ "$FORCE_MIGRATION" = "true" ]; then
  # Migration nötig
  migrate_module "$MODULE_NAME" "$SOURCE_VERSION" "$TARGET_VERSION"
else
  # Nur Code aktualisieren (user-configs/ unberührt)
  update_module_code "$module" "$TARGET_MODULE"
fi
```

---

## 📋 Phase 4: User-Configs komplett schützen

### 4.1 createDefaultConfig verbessern

**Datei**: `nixos/core/system-manager/lib/config-helpers.nix`

**Aktuell:**
```bash
if [ ! -f "${toString userConfigFile}" ]; then
  # Erstelle Default
fi
```

**Verbessert:**
```bash
# Prüfe ob Symlink existiert und auf gültige Datei zeigt
if [ -L "$symlinkPath" ]; then
  REAL_FILE=$(readlink -f "$symlinkPath")
  if [ -f "$REAL_FILE" ]; then
    # Datei existiert, NICHT überschreiben
    return
  fi
fi

# Nur wenn Datei wirklich nicht existiert
if [ ! -f "${toString userConfigFile}" ]; then
  # Erstelle Default
fi
```

### 4.2 update_module_code implementieren

```bash
update_module_code() {
  local source_module="$1"
  local target_module="$2"
  
  # Kopiere alles AUSSER user-configs/
  rsync -av --exclude='user-configs' "$source_module/" "$target_module/"
  
  # user-configs/ bleibt komplett unberührt
}
```

---

## 📋 Phase 5: Migration forcieren implementieren

### 5.1 --force-migration Flag

**Datei**: `nixos/core/system-manager/handlers/system-update.nix`

```bash
# Parse arguments
FORCE_MIGRATION=false
for arg in "$@"; do
  case "$arg" in
    --force-migration)
      FORCE_MIGRATION=true
      ;;
  esac
done
```

### 5.2 In Version-Prüfung integrieren

```bash
if [ "$SOURCE_VERSION" != "$TARGET_VERSION" ] || [ "$FORCE_MIGRATION" = "true" ]; then
  # Migration ausführen
  # ABER: user-configs/ bleiben unberührt
fi
```

---

## 📋 Phase 6: RAM-Check korrigieren

### 6.1 Symlink auflösen

**Datei**: `nixos/features/system-checks/prebuild/checks/hardware/memory.nix`

```bash
# Symlink auflösen
REAL_FILE=$(readlink -f "${hardwareConfigPath}" 2>/dev/null || echo "${hardwareConfigPath}")

# Prüfe in echter Datei
CONFIGURED_GB=$(grep -A2 'ram = {' "$REAL_FILE" | grep 'sizeGB' | grep -oE '[0-9]+' | head -1)
```

### 6.2 Flexibleres Pattern

```bash
# Statt: grep -A2 'ram = {' | grep 'sizeGB' | grep -o '[0-9]\+'
# Besser:
CONFIGURED_GB=$(grep -E 'sizeGB\s*=' "$REAL_FILE" | grep -oE '[0-9]+' | head -1)
```

---

## 📋 Implementierungs-Reihenfolge

### Schritt 1: Helper-Funktionen (Phase 1.1)
- [ ] `version-helpers.nix` erstellen
- [ ] Version-Extraktion implementieren
- [ ] Version-Vergleich implementieren

### Schritt 2: User-Configs schützen (Phase 4)
- [ ] `createDefaultConfig` verbessern (Symlink-Prüfung)
- [ ] `update_module_code` Funktion erstellen
- [ ] Testen: User-Configs bleiben erhalten

### Schritt 3: Selektives Kopieren (Phase 3)
- [ ] `rm -rf` entfernen
- [ ] Modul-für-Modul Kopieren implementieren
- [ ] `user-configs/` ausschließen
- [ ] Testen: Nur Code wird aktualisiert

### Schritt 4: Version-Prüfung (Phase 1.2)
- [ ] Version-Prüfung in system-update integrieren
- [ ] Entscheidungs-Logik: Migration? Skip?
- [ ] Testen: Module mit gleicher Version werden übersprungen

### Schritt 5: Stufe 0 → 1 Migration (Phase 2)
- [ ] `stage0-to-stage1-migration.nix` erstellen
- [ ] system-config.nix lesen und extrahieren
- [ ] user-configs/ erstellen
- [ ] options.nix erstellen
- [ ] Testen: Stufe 0 → 1 Migration funktioniert

### Schritt 6: Migration forcieren (Phase 5)
- [ ] `--force-migration` Flag implementieren
- [ ] In Version-Prüfung integrieren
- [ ] Testen: Forcierte Migration funktioniert, User-Configs bleiben erhalten

### Schritt 7: RAM-Check korrigieren (Phase 6)
- [ ] Symlink auflösen
- [ ] Flexibleres Pattern
- [ ] Testen: RAM wird korrekt erkannt

---

## 🔧 Detaillierte Implementierung

### Helper-Funktionen (version-helpers.nix)

```nix
{ pkgs, lib, ... }:

rec {
  # Prüfe ob Modul versioniert ist
  hasVersion = modulePath: builtins.pathExists "${modulePath}/options.nix";
  
  # Extrahiere Version aus options.nix
  getSourceVersion = modulePath:
    let
      optionsFile = "${modulePath}/options.nix";
    in
      if builtins.pathExists optionsFile then
        # Grep: moduleVersion = "X.Y"
        pkgs.runCommand "get-version" {} ''
          VERSION=$(grep -m 1 'moduleVersion =' "${optionsFile}" | sed 's/.*moduleVersion = "\([^"]*\)".*/\1/' || echo "unknown")
          echo -n "$VERSION" > $out
        ''
      else
        "unknown";
  
  # Extrahiere Version aus user-configs/*-config.nix
  getTargetVersion = modulePath: configName:
    let
      configFile = "${modulePath}/user-configs/${configName}-config.nix";
    in
      if builtins.pathExists configFile then
        # Grep: _version = "X.Y"
        pkgs.runCommand "get-target-version" {} ''
          VERSION=$(grep -m 1 '_version =' "${configFile}" | sed 's/.*_version = "\([^"]*\)".*/\1/' || echo "unknown")
          echo -n "$VERSION" > $out
        ''
      else
        "unknown";
  
  # Vergleiche Versionen (true wenn v1 < v2)
  versionOlder = v1: v2:
    lib.versionOlder v1 v2;
}
```

### Selektives Kopieren

```bash
# Statt komplettes Löschen und Kopieren:
# Für jedes Modul einzeln prüfen und kopieren

update_core_modules() {
  local source_dir="$SOURCE_DIR/core"
  local target_dir="$NIXOS_DIR/core"
  
  # Erstelle target_dir falls nicht vorhanden
  mkdir -p "$target_dir"
  
  # Für jedes Modul in SOURCE
  for module in "$source_dir"/*; do
    if [ ! -d "$module" ]; then
      continue
    fi
    
    MODULE_NAME=$(basename "$module")
    TARGET_MODULE="$target_dir/$MODULE_NAME"
    
    # Prüfe ob Modul versioniert ist
    if [ -f "$module/options.nix" ]; then
      # Modul hat Version (Stufe 1+)
      handle_versioned_module "$module" "$TARGET_MODULE" "$MODULE_NAME"
    else
      # Modul hat keine Version (Stufe 0)
      handle_stage0_module "$module" "$TARGET_MODULE" "$MODULE_NAME"
    fi
  done
}

handle_versioned_module() {
  local source_module="$1"
  local target_module="$2"
  local module_name="$3"
  
  # Prüfe Versionen
  SOURCE_VERSION=$(get_source_version "$source_module")
  
  if [ -f "$target_module/user-configs/${module_name}-config.nix" ]; then
    TARGET_VERSION=$(get_target_version "$target_module" "$module_name")
    
    if [ "$SOURCE_VERSION" != "$TARGET_VERSION" ] || [ "$FORCE_MIGRATION" = "true" ]; then
      # Migration nötig
      migrate_module "$module_name" "$SOURCE_VERSION" "$TARGET_VERSION"
    else
      # Nur Code aktualisieren
      update_module_code "$source_module" "$target_module"
    fi
  else
    # TARGET hat keine user-configs/ → erstelle aus Default
    create_user_configs "$source_module" "$target_module" "$module_name"
  fi
}

handle_stage0_module() {
  local source_module="$1"
  local target_module="$2"
  local module_name="$3"
  
  if [ -d "$target_module" ]; then
    # Modul existiert in TARGET → Stufe 0 → 1 Migration
    migrate_stage0_to_stage1 "$module_name" "$SYSTEM_CONFIG_FILE"
  else
    # Neues Modul → kopiere komplett
    cp -r "$source_module" "$target_module"
  fi
}

update_module_code() {
  local source_module="$1"
  local target_module="$2"
  
  # Erstelle target_module falls nicht vorhanden
  mkdir -p "$target_module"
  
  # Kopiere alles AUSSER user-configs/
  if [ -d "$target_module/user-configs" ]; then
    # user-configs/ existiert → schützen
    rsync -av --exclude='user-configs' "$source_module/" "$target_module/"
  else
    # user-configs/ existiert nicht → kopiere komplett
    cp -r "$source_module"/* "$target_module/"
  fi
}
```

### Stufe 0 → 1 Migration

```bash
migrate_stage0_to_stage1() {
  local module_name="$1"
  local system_config_file="$2"
  
  # 1. Lese system-config.nix
  if [ ! -f "$system_config_file" ]; then
    ${ui.messages.error "system-config.nix not found for Stufe 0 → 1 Migration"}
    return 1
  fi
  
  # 2. Extrahiere MODULE.* Config
  MODULE_CONFIG=$(extract_module_config "$system_config_file" "$module_name")
  
  # 3. Erstelle user-configs/MODULE-config.nix
  USER_CONFIGS_DIR="$NIXOS_DIR/core/$module_name/user-configs"
  mkdir -p "$USER_CONFIGS_DIR"
  
  echo "$MODULE_CONFIG" > "$USER_CONFIGS_DIR/${module_name}-config.nix"
  
  # 4. Erstelle options.nix mit Version 1.0
  # (wird aus SOURCE kopiert, sollte bereits existieren)
  
  # 5. Kopiere Modul-Code
  cp -r "$SOURCE_DIR/core/$module_name"/* "$NIXOS_DIR/core/$module_name/"
  
  # 6. user-configs/ wiederherstellen (aus extrahierter Config)
  # (wurde in Schritt 3 erstellt)
}
```

---

## 🧪 Test-Plan

### Test 1: Version-Prüfung
- [ ] Modul mit Version 1.0 (SOURCE) vs. 1.0 (TARGET) → Skip
- [ ] Modul mit Version 1.0 (SOURCE) vs. 2.0 (TARGET) → Migration
- [ ] Modul mit Version 2.0 (SOURCE) vs. 1.0 (TARGET) → Migration

### Test 2: User-Configs schützen
- [ ] User-Config existiert → bleibt erhalten
- [ ] User-Config existiert nicht → wird erstellt (Default)
- [ ] Forcierte Migration → User-Config bleibt erhalten

### Test 3: Stufe 0 → 1 Migration
- [ ] Modul ohne Version → liest system-config.nix
- [ ] Extrahiert Config korrekt
- [ ] Erstellt user-configs/ korrekt
- [ ] Erstellt options.nix korrekt

### Test 4: Selektives Kopieren
- [ ] Nur Code wird aktualisiert
- [ ] user-configs/ bleibt unberührt
- [ ] Neue Dateien werden hinzugefügt

### Test 5: RAM-Check
- [ ] Symlink wird aufgelöst
- [ ] RAM wird korrekt erkannt
- [ ] Update funktioniert

---

## ⚠️ Kritische Regeln

1. **User-Configs NIEMALS überschreiben** (auch bei forcierter Migration)
2. **User-Configs NIEMALS löschen**
3. **Nur Modul-Code aktualisieren**, nicht User-Configs
4. **Version-Prüfung vor jeder Änderung**
5. **Backup vor jeder Migration**

---

**Erstellt**: 2025-12-07
**Status**: Implementierungsplan - Bereit für Umsetzung

