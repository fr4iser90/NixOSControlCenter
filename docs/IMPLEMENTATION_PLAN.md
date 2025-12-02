# Implementation Plan: Package Structure Redesign

## Übersicht

Migration von der alten verschachtelten Modul-Struktur zur neuen flachen Feature-basierten Struktur.

**Von:**
```
modules/
├── gaming/
│   ├── streaming.nix
│   └── emulation.nix
├── development/
│   └── web.nix
└── server/
    └── docker.nix
```

**Zu:**
```
features/
├── streaming.nix
├── emulation.nix
├── web-dev.nix
└── docker.nix
```

---

## Phase 1: Neue Struktur erstellen

### 1.1 Neue Verzeichnisse anlegen

**Neue Verzeichnisse:**
- `nixos/packages/features/` - Alle Features (flach)
- `nixos/packages/presets/` - Vordefinierte Presets
- `nixos/packages/metadata.nix` - Feature-Metadaten

**Betroffene Dateien:**
- Keine (nur neue Verzeichnisse)

---

## Phase 2: Metadaten-System

### 2.1 Erstelle `metadata.nix`

**Neue Datei:**
- `nixos/packages/metadata.nix`

**Inhalt:**
- Feature-Definitionen mit `systemTypes`, `group`, `description`, `dependencies`, `conflicts`

**Beispiel:**
```nix
{
  features = {
    streaming = {
      systemTypes = [ "desktop" "homelab" ];
      group = "gaming";
      description = "Gaming streaming tools";
    };
    docker = {
      systemTypes = [ "server" "homelab" ];
      group = "virtualization";
      conflicts = [ "docker-rootless" ];
    };
    # ... weitere Features
  };
}
```

---

## Phase 3: Feature-Migration

### 3.1 Gaming Features migrieren

**Alte Dateien (werden gelöscht):**
- `nixos/packages/modules/gaming/default.nix`
- `nixos/packages/modules/gaming/streaming.nix`
- `nixos/packages/modules/gaming/emulation.nix`

**Neue Dateien:**
- `nixos/packages/features/streaming.nix` (aus `gaming/streaming.nix`)
- `nixos/packages/features/emulation.nix` (aus `gaming/emulation.nix`)

**Aktionen:**
1. Inhalt von `gaming/streaming.nix` → `features/streaming.nix` kopieren
2. Inhalt von `gaming/emulation.nix` → `features/emulation.nix` kopieren
3. Alte Dateien löschen

---

### 3.2 Development Features migrieren

**Alte Dateien (werden gelöscht):**
- `nixos/packages/modules/development/default.nix`
- `nixos/packages/modules/development/game.nix`
- `nixos/packages/modules/development/web.nix`
- `nixos/packages/modules/development/python.nix`
- `nixos/packages/modules/development/system.nix`
- `nixos/packages/modules/development/virtualization.nix`

**Neue Dateien:**
- `nixos/packages/features/game-dev.nix` (aus `development/game.nix`)
- `nixos/packages/features/web-dev.nix` (aus `development/web.nix`)
- `nixos/packages/features/python-dev.nix` (aus `development/python.nix`)
- `nixos/packages/features/system-dev.nix` (aus `development/system.nix` - Build Tools)
- `nixos/packages/features/qemu-vm.nix` (aus `development/virtualization.nix` - QEMU Teil)
- `nixos/packages/features/virt-manager.nix` (aus `development/virtualization.nix` - GUI Teil)

**Aktionen:**
1. Inhalt migrieren und umbenennen
2. `development/virtualization.nix` aufteilen in:
   - `qemu-vm.nix` (QEMU/KVM)
   - `virt-manager.nix` (GUI)
3. `development/system.nix` prüfen:
   - Falls vorhanden: → `features/system-dev.nix` (oder anderer Name)
   - Falls leer/unnötig: Löschen
4. Alte Dateien löschen

---

### 3.3 Server Features migrieren

**Alte Dateien (werden gelöscht):**
- `nixos/packages/modules/server/default.nix`
- `nixos/packages/modules/server/docker.nix`
- `nixos/packages/modules/server/docker-rootless.nix`
- `nixos/packages/modules/server/database.nix`
- `nixos/packages/modules/server/mail.nix`
- `nixos/packages/modules/server/virtualization.nix`
- `nixos/packages/modules/server/web.nix`

**Neue Dateien:**
- `nixos/packages/features/docker.nix` (aus `server/docker.nix`)
- `nixos/packages/features/docker-rootless.nix` (aus `server/docker-rootless.nix`)
- `nixos/packages/features/database.nix` (aus `server/database.nix`)
- `nixos/packages/features/mail-server.nix` (aus `server/mail.nix`)
- `nixos/packages/features/web-server.nix` (aus `server/web.nix`)

**Aktionen:**
1. Dateien verschieben und umbenennen
2. Alte Dateien löschen

---

## Phase 4: Neue `default.nix` implementieren

### 4.1 `nixos/packages/default.nix` komplett neu schreiben

**Betroffene Datei:**
- `nixos/packages/default.nix` (komplett neu)

**Neue Logik:**
1. Lade `metadata.nix`
2. Lade Preset wenn gesetzt
3. Kombiniere Preset-Features + zusätzliche Features
4. Filtere Features nach `systemType`
5. Prüfe Conflicts
6. Lade Feature-Module

**Alte Logik entfernen:**
- `activeModules` (alte verschachtelte Logik)
- `baseModule` Loading (alte Logik)
- `subModules` Loading (alte Logik)

**Neue Logik hinzufügen:**
- Preset-Loading
- Feature-Liste kombinieren
- systemType-Filterung
- Conflict-Prüfung
- Feature-Module Loading

---

## Phase 5: Preset-System

### 5.1 Preset-Definitionen erstellen

**Neue Dateien:**
- `nixos/packages/presets/gaming-desktop.nix`
- `nixos/packages/presets/dev-workstation.nix`
- `nixos/packages/presets/homelab-server.nix`
- `nixos/packages/presets/gaming-server.nix` (optional, Hybrid-Beispiel)

**Inhalt Beispiel:**
```nix
# presets/gaming-desktop.nix
{
  description = "Gaming Desktop mit Streaming und Emulation";
  systemTypes = [ "desktop" ];
  features = [
    "streaming"
    "emulation"
    "game-dev"
  ];
}
```

---

## Phase 6: Shell Scripts - Setup Scripts

### 6.1 Desktop Setup Script

**Betroffene Datei:**
- `shell/scripts/setup/modes/desktop/setup.sh`

**Änderungen:**
- `reset_module_states()`: Alte sed-Befehle für `gaming = {}` und `development = {}` entfernen
- Neue Funktion: `reset_feature_states()`: Setze alle Features auf `false`
- `enable_desktop_module()`: 
  - Alte Cases (`Gaming-Streaming`, `Development-Web`) entfernen
  - Neue Cases für Features (`streaming`, `emulation`, `web-dev`, `game-dev`)
  - Neue sed-Befehle für `features = []` Struktur

**Alte sed-Befehle entfernen:**
```bash
'/gaming = {/,/};/s/streaming = .*;/streaming = false;/'
'/development = {/,/};/s/web = .*;/web = false;/'
```

**Neue sed-Befehle:**
```bash
# Features aus Liste entfernen/hinzufügen
# Beispiel: features = [ "streaming" "emulation" ];
```

---

### 6.2 Server Setup Script

**Betroffene Datei:**
- `shell/scripts/setup/modes/server/setup.sh`

**Änderungen:**
- `reset_module_states()`: Alte sed-Befehle für `server = {}` entfernen
- Neue Funktion: `reset_feature_states()`: Setze alle Features auf `false`
- `enable_server_module()`:
  - Alte Cases (`Docker`, `Database`) entfernen
  - Neue Cases für Features (`docker`, `docker-rootless`, `database`, `web-server`)
  - Neue sed-Befehle für `features = []` Struktur

**Alte sed-Befehle entfernen:**
```bash
'/server = {/,/};/s/docker = .*;/docker = false;/'
'/server = {/,/};/s/database = .*;/database = false;/'
```

---

### 6.3 Server Module Scripts

**Betroffene Dateien:**
- `shell/scripts/setup/modes/server/modules/docker.sh`
- `shell/scripts/setup/modes/server/modules/database.sh`

**Änderungen:**
- `enable_docker()`: Alte sed-Befehle für `server.docker` entfernen
- Neue sed-Befehle: Feature zu `features = []` hinzufügen
- Gleiches für `database.sh`

**Alter Code:**
```bash
sed -i '/server = {/,/};/s/docker = .*;/docker = true;/' "$SYSTEM_CONFIG_FILE"
```

**Neuer Code:**
```bash
# Feature zu features-Liste hinzufügen
# Prüfe ob features-Liste existiert, füge "docker" hinzu
```

---

### 6.4 Server Test Modules Script

**Betroffene Datei:**
- `shell/scripts/setup/modes/server/test_modules.sh`

**Änderungen:**
- Kann bleiben (lädt Module dynamisch)
- Eventuell anpassen wenn Module-Struktur sich ändert

---

## Phase 7: UI/Prompts Scripts

**Übersicht:**
Alle UI/Prompts Scripts müssen angepasst werden, um die neue Feature-Struktur zu unterstützen.

### 7.1 Setup Options

**Betroffene Datei:**
- `shell/scripts/ui/prompts/setup-options.sh`

**Änderungen:**
- `SUB_OPTIONS` Array komplett neu:
  - Alte: `["Desktop"]="None|Gaming-Streaming|Gaming-Emulation|Development-Web|Development-Game"`
  - Neue: `["Desktop"]="None|streaming|emulation|web-dev|game-dev|python-dev"`
  - Alte: `["Server"]="None|Docker|Database"`
  - Neue: `["Server"]="None|docker|docker-rootless|database|web-server|mail-server"`

**Optionen erweitern:**
- Preset-Optionen hinzufügen
- Feature-Gruppierung für UI (optional)

---

### 7.2 Setup Mode Script

**Betroffene Datei:**
- `shell/scripts/ui/prompts/setup-mode.sh`

**Änderungen:**
- Preset-Auswahl hinzufügen (neue Option)
- Feature-Auswahl anpassen (neue Struktur)
- Multi-Select für Features (statt verschachtelte Auswahl)

**Neue Logik:**
1. User wählt: Preset ODER Custom Setup
2. Wenn Preset: Preset laden, fertig
3. Wenn Custom: Base wählen (Desktop/Server), dann Features auswählen

---

### 7.3 Setup Descriptions

**Betroffene Datei:**
- `shell/scripts/ui/prompts/descriptions/setup-descriptions.sh`

**Änderungen:**
- Alte Beschreibungen entfernen:
  - `gaming-streaming`, `gaming-emulation`
  - `development-web`, `development-game`
  - `server-docker`, `server-database`
- Neue Beschreibungen hinzufügen:
  - `streaming`, `emulation`
  - `web-dev`, `game-dev`, `python-dev`
  - `docker`, `docker-rootless`, `database`, `web-server`
- Preset-Beschreibungen hinzufügen

**Neue Einträge:**
```bash
["streaming"]="Gaming streaming tools (OBS, etc.)"
["docker"]="Docker containerization (root)"
["docker-rootless"]="Docker containerization (rootless, safer)"
["gaming-desktop"]="Gaming Desktop preset with streaming and emulation"
```

---

### 7.4 Setup Rules Script

**Betroffene Datei:**
- `shell/scripts/ui/prompts/setup-rules.sh`

**Änderungen:**
- `REQUIRES` Array komplett neu:
  - Alte: `["Gaming-Streaming"]="Gaming"`, `["Development-Web"]="Development"`
  - Neue: Feature-basierte Dependencies (z.B. `["virt-manager"]="qemu-vm"`)
- `activate_dependencies()`: Anpassen für neue Feature-Struktur
- `check_conflicts()`: Anpassen für Feature-Conflicts (z.B. docker vs docker-rootless)

**Alter Code:**
```bash
declare -A REQUIRES=(
    ["Gaming-Streaming"]="Gaming"
    ["Development-Web"]="Development"
)
```

**Neuer Code:**
```bash
declare -A REQUIRES=(
    ["virt-manager"]="qemu-vm"  # virt-manager benötigt qemu-vm
    # Weitere Feature-Dependencies aus metadata.nix
)
```

---

### 7.5 Setup Tree Script

**Betroffene Datei:**
- `shell/scripts/ui/prompts/formatting/setup-tree.sh`

**Änderungen:**
- `add_desktop_branch()`: Alte Gaming/Development Struktur entfernen
- Neue Tree-Struktur für Features:
  - Features gruppiert nach Kategorien (aus metadata.nix)
  - Oder flache Feature-Liste

**Alter Code:**
```bash
tree_ref+=("$TREE_INDENT$TREE_BRANCH Gaming")
tree_ref+=("$TREE_INDENT$TREE_VERTICAL  $TREE_BRANCH Gaming-Streaming")
```

**Neuer Code:**
```bash
# Features gruppiert nach metadata.group
tree_ref+=("$TREE_INDENT$TREE_BRANCH Gaming Features")
tree_ref+=("$TREE_INDENT$TREE_VERTICAL  $TREE_BRANCH streaming")
tree_ref+=("$TREE_INDENT$TREE_VERTICAL  $TREE_LAST emulation")
```

---

### 7.6 Validate Mode Script

**Betroffene Datei:**
- `shell/scripts/ui/prompts/validate-mode.sh`

**Änderungen:**
- Alte Konflikt-Prüfung entfernen:
  - `"Gaming"` und `"Server"` Konflikt (nicht mehr relevant)
- Neue Feature-Conflict-Prüfung:
  - `docker` vs `docker-rootless`
  - Andere Conflicts aus metadata.nix

**Alter Code:**
```bash
if [[ " ${selections[@]} " =~ " Gaming " && " ${selections[@]} " =~ " Server " ]]; then
    echo "Error: 'Gaming' and 'Server' cannot be selected together."
```

**Neuer Code:**
```bash
# Prüfe Feature-Conflicts aus metadata.nix
if [[ " ${selections[@]} " =~ " docker " && " ${selections[@]} " =~ " docker-rootless " ]]; then
    echo "Error: 'docker' and 'docker-rootless' cannot be selected together."
```

---

## Phase 8: Config Template & Data Collection

### 8.1 System Config Template

**Betroffene Datei:**
- `shell/scripts/setup/config/system-config.template.nix`

**Änderungen:**
- Alte Struktur entfernen:
```nix
packageModules = {
  gaming = {
    streaming = @GAMING_STREAMING@;
    emulation = @GAMING_EMULATION@;
  };
  development = {
    game = @DEV_GAME@;
    web = @DEV_WEB@;
  };
  server = {
    docker = @SERVER_DOCKER@;
    web = @SERVER_WEB@;
  };
};
```

- Neue Struktur:
```nix
# Option 1: Features direkt
features = [ @FEATURES@ ];

# Option 2: Preset
preset = "@PRESET@";
additionalFeatures = [ @ADDITIONAL_FEATURES@ ];
```

**Platzhalter ändern:**
- Alte: `@GAMING_STREAMING@`, `@DEV_WEB@`, etc.
- Neue: `@FEATURES@` (Liste) oder `@PRESET@` + `@ADDITIONAL_FEATURES@`

---

### 8.2 Collect System Data Script

**Betroffene Datei:**
- `shell/scripts/setup/config/data-collection/collect-system-data.sh`

**Änderungen:**
- `init_profile_modules()`: Komplett neu schreiben
  - Alte: Setze einzelne Module auf `false`
  - Neue: Setze `features = []` oder `preset = null`

**Alter Code:**
```bash
init_profile_modules() {
    sed -i \
        -e "s|@GAMING_STREAMING@|false|" \
        -e "s|@GAMING_EMULATION@|false|" \
        -e "s|@DEV_GAME@|false|" \
        -e "s|@DEV_WEB@|false|" \
        -e "s|@SERVER_DOCKER@|false|" \
        -e "s|@SERVER_WEB@|false|" \
        "$temp_config"
}
```

**Neuer Code:**
```bash
init_profile_modules() {
    sed -i \
        -e "s|@FEATURES@||" \
        -e "s|@PRESET@|null|" \
        "$temp_config"
}
```

---

## Phase 9: Profile Migration

### 9.1 Profile Files konvertieren

**Betroffene Dateien:**
- `shell/scripts/setup/modes/profiles/fr4iser-home`
- `shell/scripts/setup/modes/profiles/fr4iser-jetson`
- `shell/scripts/setup/modes/profiles/gira-home`

**Änderungen:**
- Alte `packageModules` Struktur entfernen
- Neue `features` oder `preset` Struktur hinzufügen

**Beispiel Migration:**

**Vorher:**
```nix
packageModules = {
  gaming = {
    streaming = true;
    emulation = true;
  };
  development = {
    game = true;
    web = true;
  };
  server = {
    docker = false;
    web = false;
  };
};
```

**Nachher:**
```nix
# Option 1: Features direkt
features = [ "streaming" "emulation" "game-dev" "web-dev" ];

# Option 2: Preset verwenden
preset = "gaming-desktop";
additionalFeatures = [ "web-dev" ];
```

---

## Phase 10: Dokumentation

### 10.1 Dokumentation aktualisieren

**Betroffene Dateien:**
- `docs/PACKAGE_STRUCTURE_REDESIGN.md` (bereits erstellt)
- `docs/PROJECT_STRUCTURE.md` (Update)
- README Dateien (falls vorhanden)

**Inhalt:**
- Neue Struktur dokumentieren
- Migration-Guide
- Feature-Liste
- Preset-Liste

---

## Phase 11: Testing & Cleanup

### 11.1 Alte Dateien löschen

**Zu löschende Verzeichnisse:**
- `nixos/packages/modules/` (komplett)

**Zu löschende Dateien:**
- Alle Dateien in `modules/gaming/`
- Alle Dateien in `modules/development/`
- Alle Dateien in `modules/server/`

---

### 11.2 Testing

**Automatische Validierung:**
- `scripts/validate-migration.sh` ausführen
- Prüft alle Phasen automatisch
- Siehe auch: `docs/VALIDATION_CHECKLIST.md`

**Zu testen:**
1. Desktop Setup mit Features
2. Server Setup mit Features
3. Preset-Loading
4. Profile-Loading
5. Feature-Combinations
6. Conflict-Prüfung
7. systemType-Filterung

**Validierungs-Script ausführen:**
```bash
./scripts/validate-migration.sh
```

---

## Zusammenfassung: Betroffene Dateien

### NixOS Package Files (nixos/packages/)

**Neue Dateien:**
- `nixos/packages/metadata.nix` ✨
- `nixos/packages/features/streaming.nix` ✨
- `nixos/packages/features/emulation.nix` ✨
- `nixos/packages/features/game-dev.nix` ✨
- `nixos/packages/features/web-dev.nix` ✨
- `nixos/packages/features/python-dev.nix` ✨
- `nixos/packages/features/docker.nix` ✨
- `nixos/packages/features/docker-rootless.nix` ✨
- `nixos/packages/features/database.nix` ✨
- `nixos/packages/features/web-server.nix` ✨
- `nixos/packages/features/mail-server.nix` ✨
- `nixos/packages/features/qemu-vm.nix` ✨
- `nixos/packages/features/virt-manager.nix` ✨
- `nixos/packages/presets/gaming-desktop.nix` ✨
- `nixos/packages/presets/dev-workstation.nix` ✨
- `nixos/packages/presets/homelab-server.nix` ✨

**Geänderte Dateien:**
- `nixos/packages/default.nix` 🔄 (komplett neu)

**Gelöschte Dateien:**
- `nixos/packages/modules/gaming/default.nix` ❌
- `nixos/packages/modules/gaming/streaming.nix` ❌
- `nixos/packages/modules/gaming/emulation.nix` ❌
- `nixos/packages/modules/development/default.nix` ❌
- `nixos/packages/modules/development/game.nix` ❌
- `nixos/packages/modules/development/web.nix` ❌
- `nixos/packages/modules/development/python.nix` ❌
- `nixos/packages/modules/development/system.nix` ❌ (wird zu `features/system-dev.nix`)
- `nixos/packages/modules/development/virtualization.nix` ❌
- `nixos/packages/modules/server/default.nix` ❌
- `nixos/packages/modules/server/docker.nix` ❌
- `nixos/packages/modules/server/docker-rootless.nix` ❌
- `nixos/packages/modules/server/database.nix` ❌
- `nixos/packages/modules/server/mail.nix` ❌
- `nixos/packages/modules/server/virtualization.nix` ❌
- `nixos/packages/modules/server/web.nix` ❌

---

### Shell Scripts (shell/scripts/)

**Geänderte Dateien:**
- `shell/scripts/setup/modes/desktop/setup.sh` 🔄
- `shell/scripts/setup/modes/server/setup.sh` 🔄
- `shell/scripts/setup/modes/server/modules/docker.sh` 🔄
- `shell/scripts/setup/modes/server/modules/database.sh` 🔄
- `shell/scripts/ui/prompts/setup-options.sh` 🔄
- `shell/scripts/ui/prompts/setup-mode.sh` 🔄
- `shell/scripts/ui/prompts/descriptions/setup-descriptions.sh` 🔄
- `shell/scripts/ui/prompts/setup-rules.sh` 🔄 (NEU HINZUGEFÜGT)
- `shell/scripts/ui/prompts/formatting/setup-tree.sh` 🔄 (NEU HINZUGEFÜGT)
- `shell/scripts/ui/prompts/validate-mode.sh` 🔄 (NEU HINZUGEFÜGT)
- `shell/scripts/setup/config/system-config.template.nix` 🔄
- `shell/scripts/setup/config/data-collection/collect-system-data.sh` 🔄

**Unveränderte Dateien (können bleiben):**
- `shell/scripts/setup/modes/server/test_modules.sh` ✅
- `shell/scripts/core/init.sh` ✅
- `shell/scripts/core/imports.sh` ✅

---

### Profile Files

**Geänderte Dateien:**
- `shell/scripts/setup/modes/profiles/fr4iser-home` 🔄
- `shell/scripts/setup/modes/profiles/fr4iser-jetson` 🔄
- `shell/scripts/setup/modes/profiles/gira-home` 🔄

---

### Dokumentation

**Neue Dateien:**
- `docs/PACKAGE_STRUCTURE_REDESIGN.md` ✨ (bereits erstellt)
- `docs/IMPLEMENTATION_PLAN.md` ✨ (diese Datei)

**Geänderte Dateien:**
- `docs/PROJECT_STRUCTURE.md` 🔄

---

## Implementierungsreihenfolge

1. ✅ **Phase 1**: Neue Verzeichnisse anlegen
2. ✅ **Phase 2**: `metadata.nix` erstellen
3. ✅ **Phase 3**: Features migrieren (Gaming → Development → Server)
4. ✅ **Phase 4**: Neue `default.nix` implementieren
5. ✅ **Phase 5**: Presets erstellen
6. ✅ **Phase 6**: Shell Scripts anpassen
7. ✅ **Phase 7**: UI/Prompts anpassen
8. ✅ **Phase 8**: Config Template anpassen
9. ✅ **Phase 9**: Profile migrieren
10. ✅ **Phase 10**: Dokumentation
11. ✅ **Phase 11**: Testing & Cleanup

---

## Wichtige Hinweise

⚠️ **Backward Compatibility:**
- Alte Profile müssen migriert werden
- Keine automatische Migration (manuell nötig)

⚠️ **Testing:**
- Jede Phase einzeln testen
- Feature-Kombinationen testen
- Preset-Loading testen

⚠️ **Rollback:**
- Git-Branch für Migration
- Backup vor Migration

---

## Geschätzte Komplexität

- **NixOS Files**: Mittel (Struktur-Änderung)
- **Shell Scripts**: Hoch (viele sed-Befehle ändern)
- **UI/Prompts**: Mittel (Optionen anpassen)
- **Profiles**: Niedrig (nur Konfiguration)

**Gesamt**: Mittel-Hoch

---

## Offene Fragen

1. Sollen alte Profile automatisch migriert werden?
2. Wie mit Custom Features umgehen (User-definiert)?
3. Soll Gruppierung in UI angezeigt werden?
4. Preset-Vererbung implementieren?

