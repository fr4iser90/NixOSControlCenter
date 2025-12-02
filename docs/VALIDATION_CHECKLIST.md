# Migration Validation Checklist

## Automatische Validierung

### Script: `scripts/validate-migration.sh`

Dieses Script prüft:
1. ✅ Alle Features wurden migriert
2. ✅ Keine alten Module-Referenzen mehr
3. ✅ Neue Struktur ist korrekt
4. ✅ Profile sind migriert
5. ✅ Scripts sind angepasst
6. ✅ Metadaten sind vollständig

---

## Manuelle Validierung

### Phase 1-2: Struktur & Metadaten

- [ ] `nixos/packages/features/` Verzeichnis existiert
- [ ] `nixos/packages/presets/` Verzeichnis existiert
- [ ] `nixos/packages/metadata.nix` existiert
- [ ] Alle Features in `metadata.nix` definiert
- [ ] Jedes Feature hat `systemTypes` definiert
- [ ] Conflicts sind korrekt definiert

### Phase 3: Feature-Migration

**Gaming:**
- [ ] `features/streaming.nix` existiert (aus `modules/gaming/streaming.nix`)
- [ ] `features/emulation.nix` existiert (aus `modules/gaming/emulation.nix`)
- [ ] Alte `modules/gaming/` Dateien gelöscht

**Development:**
- [ ] `features/game-dev.nix` existiert
- [ ] `features/web-dev.nix` existiert
- [ ] `features/python-dev.nix` existiert
- [ ] `features/system-dev.nix` existiert
- [ ] `features/qemu-vm.nix` existiert
- [ ] `features/virt-manager.nix` existiert
- [ ] Alte `modules/development/` Dateien gelöscht

**Server:**
- [ ] `features/docker.nix` existiert
- [ ] `features/docker-rootless.nix` existiert
- [ ] `features/database.nix` existiert
- [ ] `features/web-server.nix` existiert
- [ ] `features/mail-server.nix` existiert
- [ ] Alte `modules/server/` Dateien gelöscht

### Phase 4: default.nix

- [ ] `nixos/packages/default.nix` verwendet neue Struktur
- [ ] Lädt `metadata.nix`
- [ ] Unterstützt Preset-Loading
- [ ] Filtert Features nach `systemType`
- [ ] Prüft Conflicts
- [ ] Alte `activeModules` Logik entfernt

### Phase 5: Presets

- [ ] `presets/gaming-desktop.nix` existiert
- [ ] `presets/dev-workstation.nix` existiert
- [ ] `presets/homelab-server.nix` existiert
- [ ] Presets haben korrekte `features` Liste
- [ ] Presets haben korrekte `systemTypes`

### Phase 6-7: Scripts

**Desktop Setup:**
- [ ] `reset_module_states()` entfernt/alte sed-Befehle entfernt
- [ ] `reset_feature_states()` implementiert
- [ ] `enable_desktop_module()` verwendet neue Feature-Namen
- [ ] Keine alten `gaming = {}` sed-Befehle mehr

**Server Setup:**
- [ ] `reset_module_states()` entfernt/alte sed-Befehle entfernt
- [ ] `reset_feature_states()` implementiert
- [ ] `enable_server_module()` verwendet neue Feature-Namen
- [ ] Keine alten `server = {}` sed-Befehle mehr

**Module Scripts:**
- [ ] `server/modules/docker.sh` verwendet neue Struktur
- [ ] `server/modules/database.sh` verwendet neue Struktur

**UI/Prompts:**
- [ ] `setup-options.sh`: `SUB_OPTIONS` aktualisiert
- [ ] `setup-mode.sh`: Preset-Auswahl implementiert
- [ ] `setup-descriptions.sh`: Neue Feature-Beschreibungen
- [ ] `setup-rules.sh`: `REQUIRES` aktualisiert
- [ ] `setup-tree.sh`: Neue Tree-Struktur
- [ ] `validate-mode.sh`: Feature-Conflicts prüft

### Phase 8: Config Template

- [ ] `system-config.template.nix`: Alte `packageModules` entfernt
- [ ] Neue `features = []` oder `preset =` Struktur
- [ ] Platzhalter aktualisiert (`@FEATURES@`, `@PRESET@`)
- [ ] `collect-system-data.sh`: `init_profile_modules()` aktualisiert

### Phase 9: Profile Migration

- [ ] `fr4iser-home`: `packageModules` → `features` oder `preset`
- [ ] `fr4iser-jetson`: `packageModules` → `features` oder `preset`
- [ ] `gira-home`: `packageModules` → `features` oder `preset`
- [ ] Keine redundanten `server.* = false` mehr

### Phase 10-11: Dokumentation & Cleanup

- [ ] `docs/PROJECT_STRUCTURE.md` aktualisiert
- [ ] `README.md` aktualisiert (`modules/` → `features/`)
- [ ] Alte `modules/` Verzeichnisse gelöscht
- [ ] Alle Tests bestanden

---

## Test-Szenarien

### Test 1: Desktop mit Features
```nix
{
  systemType = "desktop";
  features = [ "streaming" "emulation" "web-dev" ];
}
```
**Erwartet:** Nur Desktop-Features geladen, keine Server-Features

### Test 2: Server mit Features
```nix
{
  systemType = "server";
  features = [ "docker-rootless" "database" "web-server" ];
}
```
**Erwartet:** Nur Server-Features geladen, keine Desktop-Features

### Test 3: Preset Loading
```nix
{
  systemType = "desktop";
  preset = "gaming-desktop";
}
```
**Erwartet:** Preset-Features geladen (streaming, emulation, game-dev)

### Test 4: Feature Conflicts
```nix
{
  systemType = "server";
  features = [ "docker" "docker-rootless" ];
}
```
**Erwartet:** Error/Conflict-Detection

### Test 5: Hybrid System
```nix
{
  systemType = "desktop";
  features = [ "streaming" "docker-rootless" ];
}
```
**Erwartet:** Beide Features geladen (Desktop + Server Feature)

### Test 6: systemType Filterung
```nix
{
  systemType = "desktop";
  features = [ "streaming" "database" ];  # database ist server-only
}
```
**Erwartet:** Nur `streaming` geladen, `database` ignoriert

---

## Validierungs-Script

Siehe: `scripts/validate-migration.sh`

